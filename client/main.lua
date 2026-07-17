local RESOURCE = 'mafin_communityservice'

local inService = false
local actionRunning = false
local drawMarker = false
local markerLocations = {}
local currentPoints = {}
local currentTargets = {}
local currentObjects = {}
local existingActions = 0
local textUiShown = false
local currentReason = ''
local serviceBlips = {}

local Framework = nil

SetNuiFocus(false, false)
SendNUIMessage({ action = 'close' })
SendNUIMessage({ action = 'serviceStatus', visible = false })

local function notify(message, notifyType)
	if Config.Framework == 'qbcore' and Framework then
		Framework.Functions.Notify(message, notifyType or 'success', 5000)
	elseif Config.Framework == 'esx' and Framework then
		Framework.ShowNotification(message)
	else
		lib.notify({ title = 'Mafin Community Service', description = message, type = notifyType or 'inform' })
	end
end

local function hideText()
	if textUiShown then
		lib.hideTextUI()
		textUiShown = false
	end
end

local function showText(message)
	if not textUiShown then
		lib.showTextUI(message)
		textUiShown = true
	end
end

local function sendServiceHud(visible)
	SendNUIMessage({
		action = 'serviceStatus',
		visible = Config.ShowServiceHud ~= false and visible or false,
		reason = currentReason ~= '' and currentReason or 'No reason provided',
		actions = existingActions
	})
end

local function clearServiceBlips()
	for _, blip in pairs(serviceBlips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end

	serviceBlips = {}
end

local function createServiceBlips(cleared)
	clearServiceBlips()

	if not Config.ServiceBlips or not Config.ServiceBlips.enabled then return end
	cleared = cleared or {}

	local function addServiceBlip(index)
		local location = Config.ServiceLocations[index]
		if not location then return end

		local coords = location.coords.xyz
		local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

		SetBlipSprite(blip, Config.ServiceBlips.sprite or 318)
		SetBlipColour(blip, Config.ServiceBlips.color or 0)
		SetBlipScale(blip, Config.ServiceBlips.scale or 0.72)
		SetBlipAsShortRange(blip, false)

		if Config.ServiceBlips.routeCurrent then
			SetBlipRoute(blip, true)
			SetBlipRouteColour(blip, Config.ServiceBlips.currentColor or 5)
		end

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString(Config.ServiceBlips.name or 'Community Service')
		EndTextCommandSetBlipName(blip)

		serviceBlips[index] = blip
	end

	for index in ipairs(Config.ServiceLocations) do
		if not cleared[index] then
			addServiceBlip(index)
		end
	end
end

local function buildClearedSet(clearedLocations)
	local cleared = {}

	for _, index in ipairs(clearedLocations or {}) do
		cleared[tonumber(index)] = true
	end

	return cleared
end

if Config.Framework == 'qbcore' then
	Framework = GetResourceState('qb-core') == 'started' and exports['qb-core']:GetCoreObject()

	RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
		Wait(2000)
		TriggerServerEvent(RESOURCE .. ':requestCurrentService')
	end)
elseif Config.Framework == 'esx' then
	Framework = GetResourceState('es_extended') == 'started' and exports.es_extended:getSharedObject()

	RegisterNetEvent('esx:playerLoaded', function()
		Wait(2000)
		TriggerServerEvent(RESOURCE .. ':requestCurrentService')
	end)
end

CreateThread(function()
	Wait(2500)
	TriggerServerEvent(RESOURCE .. ':requestCurrentService')
end)

CreateThread(function()
	while true do
		local sleep = 1000

		if drawMarker then
			local playerCoords = GetEntityCoords(PlayerPedId())
			local hasCloseMarker = false

			for _, coords in pairs(markerLocations) do
				if #(playerCoords - coords) <= Config.MarkerDrawDistance then
					hasCloseMarker = true
					DrawMarker(20, coords.x, coords.y, coords.z + 1.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.4, 0.4, 0.4, 235, 64, 52, 100, true, false, 2, true, false, false, false)
				end
			end

			sleep = hasCloseMarker and 0 or 750
		end

		Wait(sleep)
	end
end)

local function tpToZone()
	SetEntityCoords(PlayerPedId(), Config.StartLocation.xyz)
	SetEntityHeading(PlayerPedId(), Config.StartLocation.w)
end

local function returnClothing()
	if Config.Framework == 'qbcore' then
		TriggerServerEvent('qb-clothes:loadPlayerSkin')
		TriggerServerEvent('qb-clothing:loadPlayerSkin')
	elseif Framework then
		Framework.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
			TriggerEvent('skinchanger:loadSkin', skin)
		end)
	end
end

local function releaseZone()
	returnClothing()
	hideText()
	SetEntityCoords(PlayerPedId(), Config.ReleaseLocation.xyz)
	SetEntityHeading(PlayerPedId(), Config.ReleaseLocation.w)
end

local function removeInteracts()
	for index, target in pairs(currentTargets) do
		exports.ox_target:removeZone(target)
		currentTargets[index] = nil
	end

	for index, point in pairs(currentPoints) do
		point:remove()
		currentPoints[index] = nil
	end

	for index, object in pairs(currentObjects) do
		if DoesEntityExist(object) then
			DeleteObject(object)
		end

		currentObjects[index] = nil
	end

	drawMarker = false
	markerLocations = {}
	hideText()
end

local function changeClothing()
	local ped = PlayerPedId()
	local model = GetEntityModel(ped)
	local clothes = model == `mp_m_freemode_01` and Config.Clothes.male.components or Config.Clothes.female.components

	for _, item in pairs(clothes) do
		SetPedComponentVariation(ped, item.component_id, item.drawable, item.texture, 0)
	end
end

local function spawnWorkObject(locationIndex, coords)
	local modelHash = `v_ind_rc_rubbishppr`

	if not HasModelLoaded(modelHash) then
		RequestModel(modelHash)
		while not HasModelLoaded(modelHash) do
			Wait(25)
		end
	end

	currentObjects[locationIndex] = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
	PlaceObjectOnGroundProperly(currentObjects[locationIndex])
	SetModelAsNoLongerNeeded(modelHash)
end

local function startSweep(locationIndex)
	if actionRunning or not inService or not Config.ServiceLocations[locationIndex] then return end

	actionRunning = true
	hideText()

	local completed = lib.progressBar({
		duration = Config.ActionTime,
		label = 'Cleaning community service area...',
		useWhileDead = false,
		allowRagdoll = false,
		allowCuffed = false,
		allowFalling = false,
		canCancel = false,
		anim = { dict = 'amb@world_human_janitor@male@idle_a', clip = 'idle_a' },
		prop = { model = `prop_tool_broom`, bone = 28422, pos = { x = -0.005, y = 0.0, z = 0.0 }, rot = { x = 360.0, y = 360.0, z = 0.0 } },
		disable = { move = true, combat = true, car = true }
	})

	actionRunning = false

	if completed then
		TriggerServerEvent(RESOURCE .. ':actionComplete', locationIndex)
	end
end

local function setupActions(clearedLocations)
	removeInteracts()

	local cleared = buildClearedSet(clearedLocations)

	drawMarker = true

	for index, location in ipairs(Config.ServiceLocations) do
		local locationIndex = index
		local coords = location.coords.xyz

		if not cleared[locationIndex] then
			markerLocations[locationIndex] = coords
			spawnWorkObject(locationIndex, coords)

			if Config.InteractionType == 'ox_target' then
				currentTargets[locationIndex] = exports.ox_target:addSphereZone({
					coords = coords,
					radius = 1.2,
					options = {
						{
							name = RESOURCE .. ':sweep:' .. locationIndex,
							onSelect = function()
								startSweep(locationIndex)
							end,
							icon = 'fa-solid fa-broom',
							label = 'Clean area',
							canInteract = function()
								return inService and not actionRunning and not lib.progressActive()
							end
						}
					}
				})
			else
				currentPoints[locationIndex] = lib.points.new(coords, 2.0, {})

				currentPoints[locationIndex].onExit = function()
					hideText()
				end

				currentPoints[locationIndex].nearby = function()
					if actionRunning then return end

					showText('[E] - Clean area')
					if IsControlJustReleased(0, 38) then
						startSweep(locationIndex)
					end
				end
			end
		end
	end

	createServiceBlips(cleared)
end

local function beginService(data)
	if not data or not data.actions_remaining or data.actions_remaining < 1 then return end

	existingActions = data.actions_remaining
	currentReason = data.reason or 'No reason provided'
	inService = true

	tpToZone()
	changeClothing()
	setupActions(data.cleared_locations)
	sendServiceHud(true)

	if data.reason and data.reason ~= '' then
		notify(('Community service started. Reason: %s'):format(data.reason), 'inform')
	else
		notify('Community service started.', 'inform')
	end
end

local function syncService(data)
	if not data or not data.actions_remaining or data.actions_remaining < 1 then
		inService = false
		existingActions = 0
		currentReason = ''
		removeInteracts()
		clearServiceBlips()
		sendServiceHud(false)
		releaseZone()
		notify('You have completed your community service.', 'success')
		return
	end

	inService = true
	existingActions = data.actions_remaining
	currentReason = data.reason or currentReason or 'No reason provided'
	setupActions(data.cleared_locations)
	sendServiceHud(true)
	notify(('Remaining actions: %s'):format(existingActions), 'inform')
end

local function onExit()
	if inService then
		TriggerServerEvent(RESOURCE .. ':escapeAttempt')
		tpToZone()
	end
end

lib.zones.poly({
	points = {
		vector3(1534.469116211, 2382.7924804688, 55.381984710692),
		vector3(1506.1889648438, 2788.0544433594, 55.381984710692),
		vector3(1776.034790039, 2809.7036132812, 55.381984710692),
		vector3(2004.7530517578, 2453.2854003906, 55.381984710692),
	},
	thickness = 16.0,
	debug = false,
	onExit = onExit
})

RegisterNetEvent(RESOURCE .. ':beginService', beginService)
RegisterNetEvent(RESOURCE .. ':syncService', syncService)

RegisterNetEvent(RESOURCE .. ':releaseService', function()
	inService = false
	existingActions = 0
	currentReason = ''
	removeInteracts()
	clearServiceBlips()
	sendServiceHud(false)
	releaseZone()
	notify('You were released from community service.', 'success')
end)

RegisterNetEvent(RESOURCE .. ':openAdminMenu', function(mode)
	SetNuiFocus(true, true)
	SendNUIMessage({
		action = 'open',
		mode = mode or 'assign',
		maxActions = Config.MaxActions,
		maxReasonLength = Config.MaxReasonLength
	})
end)

RegisterNUICallback('close', function(_, cb)
	SetNuiFocus(false, false)
	cb({ ok = true })
end)

RegisterNUICallback('assignService', function(data, cb)
	SetNuiFocus(false, false)
	TriggerServerEvent(RESOURCE .. ':assignFromUi', tonumber(data.target), tonumber(data.actions), tostring(data.reason or ''))
	cb({ ok = true })
end)

RegisterNUICallback('releaseService', function(data, cb)
	SetNuiFocus(false, false)
	TriggerServerEvent(RESOURCE .. ':releaseFromUi', tonumber(data.target), tostring(data.reason or ''))
	cb({ ok = true })
end)

RegisterNUICallback('getLogs', function(_, cb)
	local logs = lib.callback.await(RESOURCE .. ':getLogs', false) or {}
	cb({ logs = logs })
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end

	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	SendNUIMessage({ action = 'serviceStatus', visible = false })
	clearServiceBlips()
end)
