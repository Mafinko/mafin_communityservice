local RESOURCE = 'mafin_communityservice'
local activeServices = {}
local recentLogs = {}

local Framework = nil

if Config.Framework == 'qbcore' then
	Framework = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
	Framework = exports['es_extended']:getSharedObject()
end

CreateThread(function()
	MySQL.query.await([[
		CREATE TABLE IF NOT EXISTS `communityservice` (
			`identifier` varchar(100) NOT NULL,
			`actions_remaining` int(10) NOT NULL,
			`reason` varchar(255) NOT NULL DEFAULT 'No reason provided',
			`assigned_by` varchar(100) DEFAULT NULL,
			`updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
			PRIMARY KEY (`identifier`)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
	]])

	local function addColumnIfMissing(columnName, definition)
		local exists = MySQL.scalar.await([[
			SELECT COUNT(*)
			FROM information_schema.COLUMNS
			WHERE TABLE_SCHEMA = DATABASE()
				AND TABLE_NAME = 'communityservice'
				AND COLUMN_NAME = ?
		]], { columnName })

		if tonumber(exists) == 0 then
			MySQL.query.await(('ALTER TABLE `communityservice` ADD COLUMN `%s` %s'):format(columnName, definition))
		end
	end

	addColumnIfMissing('reason', "varchar(255) NOT NULL DEFAULT 'No reason provided'")
	addColumnIfMissing('assigned_by', 'varchar(100) DEFAULT NULL')
	addColumnIfMissing('updated_at', 'timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()')
end)

local function getPlayer(src)
	if not src then return nil end

	if Config.Framework == 'qbcore' then
		return Framework.Functions.GetPlayer(src)
	end

	return Framework.GetPlayerFromId(src)
end

local function getIdentifier(src)
	local player = getPlayer(src)
	if not player then return nil end

	if Config.Framework == 'qbcore' then
		return player.PlayerData.citizenid
	end

	return player.identifier
end

local function getPlayerName(src)
	local player = getPlayer(src)
	if not player then return ('ID %s'):format(src) end

	if Config.Framework == 'qbcore' then
		local charinfo = player.PlayerData.charinfo or player.PlayerData.charInfo or {}
		return ('%s %s'):format(charinfo.firstname or 'Unknown', charinfo.lastname or '')
	end

	return player.getName()
end

local function notify(src, message, notifyType)
	if src == 0 then
		print(message)
		return
	end

	if Config.Framework == 'qbcore' then
		TriggerClientEvent('QBCore:Notify', src, message, notifyType or 'success')
	else
		TriggerClientEvent('esx:showNotification', src, message)
	end
end

local function hasPermission(src)
	if src == 0 then return true end
	if Config.AcePermission and IsPlayerAceAllowed(src, Config.AcePermission) then return true end

	local player = getPlayer(src)
	if not player then return false end

	if Config.Framework == 'esx' and player.getGroup then
		return Config.AdminGroups[player.getGroup()] == true
	end

	if Config.Framework == 'qbcore' and Framework.Functions.HasPermission then
		for group in pairs(Config.AdminGroups) do
			if Framework.Functions.HasPermission(src, group) then
				return true
			end
		end
	end

	return false
end

local function clampReason(reason)
	reason = tostring(reason or ''):gsub('[\r\n]', ' ')
	reason = reason:gsub('^%s+', ''):gsub('%s+$', '')

	if reason == '' then
		return 'No reason provided'
	end

	if #reason > Config.MaxReasonLength then
		return reason:sub(1, Config.MaxReasonLength)
	end

	return reason
end

local function validateActions(actions)
	actions = tonumber(actions)
	if not actions then return nil end

	actions = math.floor(actions)
	if actions < Config.MinActions or actions > Config.MaxActions then
		return nil
	end

	return actions
end

local function clearedToList(service)
	local list = {}

	for index in pairs(service.cleared or {}) do
		list[#list + 1] = index
	end

	return list
end

local function rowToService(src, row)
	if not row then return nil end

	local service = {
		actions = tonumber(row.actions_remaining) or 0,
		reason = row.reason or 'No reason provided',
		cleared = {},
		clearedCount = 0,
		assignedAt = GetGameTimer(),
		lastActionAt = 0,
		lastEscapeAt = 0
	}

	if service.actions < 1 then return nil end

	activeServices[src] = service
	return service
end

local function getStoredService(src)
	local identifier = getIdentifier(src)
	if not identifier then return nil end

	local row = MySQL.single.await('SELECT actions_remaining, reason FROM communityservice WHERE identifier = ?', { identifier })
	return rowToService(src, row)
end

local function getService(src)
	local service = activeServices[src]
	if service and service.actions >= 1 then
		return service
	end

	return getStoredService(src)
end

local function saveService(src, actions, reason, assignedBy)
	local identifier = getIdentifier(src)
	if not identifier then return false end

	MySQL.update.await([[
		INSERT INTO communityservice (identifier, actions_remaining, reason, assigned_by)
		VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE actions_remaining = VALUES(actions_remaining), reason = VALUES(reason), assigned_by = COALESCE(VALUES(assigned_by), assigned_by)
	]], { identifier, actions, reason, assignedBy })

	return true
end

local function deleteService(src)
	local identifier = getIdentifier(src)
	if not identifier then return end

	MySQL.query.await('DELETE FROM communityservice WHERE identifier = ?', { identifier })
	activeServices[src] = nil
end

local function sendLog(categoryKey, title, color, fields)
	local category = Config.Logs
		and Config.Logs.Categories
		and Config.Logs.Categories[categoryKey]
		or categoryKey

	fields = fields or {}
	local storedFields = {}

	for index, field in ipairs(fields) do
		storedFields[index] = {
			name = tostring(field.name or ''),
			value = tostring(field.value or ''),
			inline = field.inline == true
		}
	end

	recentLogs[#recentLogs + 1] = {
		category = category,
		title = title,
		time = os.date('%H:%M:%S'),
		fields = storedFields
	}

	if #recentLogs > 50 then
		table.remove(recentLogs, 1)
	end

	if not Config.EnableWebhook or Config.WebhookURL == '' then return end
	if GetResourceState('hoax_logs') ~= 'started' then return end

	table.insert(fields, 1, { name = 'Category', value = category, inline = true })

	exports['hoax_logs']:DiscordLog(Config.WebhookURL, {
		category = category,
		color = color,
		title = title,
		fields = fields
	})
end

local function syncClient(src, service, begin)
	local payload = {
		actions_remaining = service.actions,
		reason = service.reason,
		cleared_locations = clearedToList(service)
	}

	TriggerClientEvent(RESOURCE .. (begin and ':beginService' or ':syncService'), src, payload)
end

local function assignService(target, actions, reason, admin)
	local targetPlayer = getPlayer(target)
	if not targetPlayer then
		notify(admin, 'Invalid player ID.', 'error')
		return
	end

	actions = validateActions(actions)
	if not actions then
		notify(admin, ('Actions must be between %s and %s.'):format(Config.MinActions, Config.MaxActions), 'error')
		return
	end

	reason = clampReason(reason)
	local adminIdentifier = admin ~= 0 and getIdentifier(admin) or 'console'

	if not saveService(target, actions, reason, adminIdentifier) then
		notify(admin, 'Could not save community service.', 'error')
		return
	end

	local service = {
		actions = actions,
		reason = reason,
		cleared = {},
		clearedCount = 0,
		assignedAt = GetGameTimer(),
		lastActionAt = 0,
		lastEscapeAt = 0
	}

	activeServices[target] = service
	syncClient(target, service, true)

	notify(admin, ('Assigned %s community service actions to %s.'):format(actions, getPlayerName(target)), 'success')
	notify(target, ('You received %s community service actions.'):format(actions), 'inform')

	sendLog('assign', 'Mafin Community Service assigned', 65280, {
		{ name = 'Player', value = getPlayerName(target), inline = true },
		{ name = 'Actions', value = tostring(actions), inline = true },
		{ name = 'Reason', value = reason, inline = false },
		{ name = 'Admin', value = admin == 0 and 'console' or getPlayerName(admin), inline = true },
		{ name = 'Identifier', value = getIdentifier(target) or 'unknown', inline = false }
	})
end

local function releaseService(target, reason, admin)
	local targetPlayer = getPlayer(target)
	if not targetPlayer then
		notify(admin, 'Invalid player ID.', 'error')
		return
	end

	reason = clampReason(reason)
	deleteService(target)
	TriggerClientEvent(RESOURCE .. ':releaseService', target)

	notify(admin, ('Released %s from community service.'):format(getPlayerName(target)), 'success')

	sendLog('release', 'Mafin Community Service released', 16711680, {
		{ name = 'Player', value = getPlayerName(target), inline = true },
		{ name = 'Reason', value = reason, inline = false },
		{ name = 'Admin', value = admin == 0 and 'console' or getPlayerName(admin), inline = true },
		{ name = 'Identifier', value = getIdentifier(target) or 'unknown', inline = false }
	})
end

RegisterNetEvent(RESOURCE .. ':requestCurrentService', function()
	local src = source
	local service = getService(src)

	if service then
		syncClient(src, service, true)
	end
end)

lib.callback.register(RESOURCE .. ':getLogs', function(source)
	if not hasPermission(source) then return {} end

	local logs = {}

	for index = #recentLogs, 1, -1 do
		logs[#logs + 1] = recentLogs[index]
	end

	return logs
end)

RegisterNetEvent(RESOURCE .. ':assignFromUi', function(target, actions, reason)
	local src = source
	if not hasPermission(src) then
		notify(src, 'You do not have permission to use this command.', 'error')
		return
	end

	assignService(tonumber(target), actions, reason, src)
end)

RegisterNetEvent(RESOURCE .. ':releaseFromUi', function(target, reason)
	local src = source
	if not hasPermission(src) then
		notify(src, 'You do not have permission to use this command.', 'error')
		return
	end

	releaseService(tonumber(target), reason, src)
end)

RegisterNetEvent(RESOURCE .. ':actionComplete', function(locationIndex)
	local src = source
	local service = getService(src)
	if not service then return end

	local now = GetGameTimer()
	if now - service.assignedAt < math.max(0, Config.ActionTime - Config.ActionGraceMs) then
		notify(src, 'Action rejected: completed too quickly.', 'error')
		sendLog('security', 'Community service action rejected', 16753920, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Reason', value = 'Completed too quickly', inline = true },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
		return
	end

	locationIndex = tonumber(locationIndex)
	local location = Config.ServiceLocations[locationIndex]

	if not location then
		notify(src, 'Action rejected: invalid service location.', 'error')
		sendLog('security', 'Community service action rejected', 16753920, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Reason', value = 'Invalid service location', inline = true },
			{ name = 'Location Index', value = tostring(locationIndex), inline = true },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
		return
	end

	service.cleared = service.cleared or {}
	service.clearedCount = service.clearedCount or 0

	if service.cleared[locationIndex] then
		notify(src, 'Action rejected: this spot is already clean.', 'error')
		sendLog('security', 'Community service action rejected', 16753920, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Reason', value = 'Repeated cleaned location', inline = true },
			{ name = 'Location Index', value = tostring(locationIndex), inline = true },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
		return
	end

	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local expectedCoords = location.coords.xyz

	if #(coords - expectedCoords) > Config.ActionDistance then
		notify(src, 'Action rejected: you are too far from the work area.', 'error')
		sendLog('security', 'Community service action rejected', 16753920, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Reason', value = 'Too far from work area', inline = true },
			{ name = 'Location Index', value = tostring(locationIndex), inline = true },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
		return
	end

	service.cleared[locationIndex] = true
	service.clearedCount = service.clearedCount + 1
	service.actions = service.actions - 1

	if service.actions <= 0 then
		deleteService(src)
		TriggerClientEvent(RESOURCE .. ':syncService', src, { actions_remaining = 0 })
		sendLog('complete', 'Mafin Community Service completed', 65280, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Reason', value = service.reason or 'No reason provided', inline = false },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
		return
	end

	if service.clearedCount >= #Config.ServiceLocations then
		service.cleared = {}
		service.clearedCount = 0
	end

	service.assignedAt = now
	service.lastActionAt = now
	saveService(src, service.actions, service.reason, nil)
	syncClient(src, service, false)
end)

RegisterNetEvent(RESOURCE .. ':escapeAttempt', function()
	local src = source
	local service = getService(src)
	if not service then return end

	local now = GetGameTimer()
	if now - service.lastEscapeAt < 15000 then return end

	service.lastEscapeAt = now

	if Config.ServiceExtensionOnEscape >= 1 then
		service.actions = service.actions + Config.ServiceExtensionOnEscape
		saveService(src, service.actions, service.reason, nil)
		notify(src, ('Escape attempt punished with %s extra actions.'):format(Config.ServiceExtensionOnEscape), 'error')
		syncClient(src, service, false)
		sendLog('escape', 'Community service escape attempt', 16711680, {
			{ name = 'Player', value = getPlayerName(src), inline = true },
			{ name = 'Extra Actions', value = tostring(Config.ServiceExtensionOnEscape), inline = true },
			{ name = 'Actions Remaining', value = tostring(service.actions), inline = true },
			{ name = 'Identifier', value = getIdentifier(src) or 'unknown', inline = false }
		})
	end
end)

local function handleAssignCommand(src, args)
	if not hasPermission(src) then
		notify(src, 'You do not have permission to use this command.', 'error')
		return
	end

	if src ~= 0 and #args == 0 then
		TriggerClientEvent(RESOURCE .. ':openAdminMenu', src, 'assign')
		return
	end

	local target = tonumber(args[1])
	local actions = tonumber(args[2])
	local reason = table.concat(args, ' ', 3)
	assignService(target, actions, reason, src)
end

local function handleReleaseCommand(src, args)
	if not hasPermission(src) then
		notify(src, 'You do not have permission to use this command.', 'error')
		return
	end

	if src ~= 0 and #args == 0 then
		TriggerClientEvent(RESOURCE .. ':openAdminMenu', src, 'release')
		return
	end

	local target = tonumber(args[1])
	local reason = table.concat(args, ' ', 2)
	releaseService(target, reason, src)
end

RegisterCommand(Config.AdminCommand, handleAssignCommand, false)
RegisterCommand('mafinservice', handleAssignCommand, false)

RegisterCommand(Config.ReleaseCommand, handleReleaseCommand, false)
RegisterCommand('mafinrelease', handleReleaseCommand, false)

AddEventHandler('playerDropped', function()
	activeServices[source] = nil
end)
