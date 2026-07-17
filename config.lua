Config = {}

Config.Framework = 'esx' -- qbcore | esx

Config.ActionTime = 5000

Config.AdminCommand = 'service'
Config.ReleaseCommand = 'servicerelease'
Config.AcePermission = 'communityService'
Config.AdminGroups = {
    admin = true,
    superadmin = true,
    mod = true
}

Config.MinActions = 1
Config.MaxActions = 500
Config.MaxReasonLength = 180

Config.ActionDistance = 6.0
Config.ActionGraceMs = 750
Config.MarkerDrawDistance = 35.0

Config.ShowServiceHud = true
Config.ServiceBlips = {
    enabled = true,
    showAll = true,
    routeCurrent = false,
    sprite = 1,
    color = 0,
    currentColor = 0,
    scale = 0.72,
    name = 'Community Service'
}

Config.checkForUpdates = false

Config.InteractionType = 'points' -- Either ox_target or points (Qtarget maybe soon?)

Config.EnableWebhook = false
Config.WebhookURL = ''
Config.Logs = {
    Categories = {
        assign = 'community_service_assign',
        release = 'community_service_release',
        complete = 'community_service_complete',
        escape = 'community_service_escape',
        security = 'community_service_security'
    }
}

-- # By how many services a player's community service gets extended if he tries to escape
Config.ServiceExtensionOnEscape = 5


-- # Don't change this unless you know what you are doing.
Config.StartLocation = vector4(1747.6442, 2514.1655, 45.5650, 25.9943)

-- # Don't change this unless you know what you are doing.
Config.ReleaseLocation = vector4(426.8537, -978.7916, 30.71013, 86.49715)

-- # Don't change this unless you know what you are doing.
Config.ServiceLocations = {
    { type = 'sweep', coords = vector4(1747.372, 2523.060, 44.5655, 341.1838) },
    { type = 'sweep', coords = vector4(1727.649, 2513.149, 44.5655, 150.7881) },
    { type = 'sweep', coords = vector4(1710.751, 2515.919, 44.5655, 86.5793) },
    { type = 'sweep', coords = vector4(1707.867, 2497.938, 44.5655, 126.8782) },
    { type = 'sweep', coords = vector4(1758.617, 2532.452, 44.5655, 337.4827) },
    { type = 'sweep', coords = vector4(1765.933, 2546.144, 44.5655, 344.3669) },
    { type = 'sweep', coords = vector4(1739.214, 2502.716, 44.5655, 262.4420) },
    { type = 'sweep', coords = vector4(1721.938, 2497.148, 44.5655, 91.2588) },
    { type = 'sweep', coords = vector4(1714.606, 2531.864, 44.5655, 41.8477) },
    { type = 'sweep', coords = vector4(1735.102, 2537.552, 44.5655, 314.9115) },
    { type = 'sweep', coords = vector4(1750.486, 2542.441, 44.5655, 210.6248) },
    { type = 'sweep', coords = vector4(1768.284, 2535.186, 44.5655, 25.7765) },
    { type = 'sweep', coords = vector4(1769.415, 2519.720, 44.5655, 108.4330) },
    { type = 'sweep', coords = vector4(1758.902, 2504.881, 44.5655, 191.5604) },
    { type = 'sweep', coords = vector4(1744.216, 2494.718, 44.5655, 76.0474) },
    { type = 'sweep', coords = vector4(1728.944, 2490.384, 44.5655, 152.9081) },
    { type = 'sweep', coords = vector4(1713.614, 2491.640, 44.5655, 294.2887) },
    { type = 'sweep', coords = vector4(1702.182, 2503.772, 44.5655, 16.8160) },
    { type = 'sweep', coords = vector4(1701.764, 2520.416, 44.5655, 243.9286) },
    { type = 'sweep', coords = vector4(1710.832, 2537.140, 44.5655, 328.7354) },
    { type = 'sweep', coords = vector4(1724.688, 2546.119, 44.5655, 99.1641) },
    { type = 'sweep', coords = vector4(1741.420, 2550.244, 44.5655, 281.4069) },
    { type = 'sweep', coords = vector4(1756.721, 2550.887, 44.5655, 5.2395) },
    { type = 'sweep', coords = vector4(1772.031, 2540.114, 44.5655, 132.6479) },
    { type = 'sweep', coords = vector4(1774.803, 2522.636, 44.5655, 224.0540) },
    { type = 'sweep', coords = vector4(1767.912, 2507.314, 44.5655, 71.7023) },
    { type = 'sweep', coords = vector4(1751.612, 2498.196, 44.5655, 344.3098) },
    { type = 'sweep', coords = vector4(1734.077, 2496.226, 44.5655, 164.2832) },
    { type = 'sweep', coords = vector4(1718.110, 2500.614, 44.5655, 254.3377) },
    { type = 'sweep', coords = vector4(1711.396, 2509.284, 44.5655, 35.2831) },
    { type = 'sweep', coords = vector4(1715.548, 2524.780, 44.5655, 117.0173) },
    { type = 'sweep', coords = vector4(1727.806, 2529.918, 44.5655, 302.7420) },
    { type = 'sweep', coords = vector4(1742.436, 2530.878, 44.5655, 193.3124) },
    { type = 'sweep', coords = vector4(1755.718, 2520.966, 44.5655, 18.8731) },
    { type = 'sweep', coords = vector4(1746.024, 2510.402, 44.5655, 270.1184) },
    { type = 'sweep', coords = vector4(1730.994, 2508.040, 44.5655, 91.5839) },
    { type = 'sweep', coords = vector4(1708.144, 2544.916, 44.5655, 148.4244) },
    { type = 'sweep', coords = vector4(1728.012, 2554.302, 44.5655, 236.4017) },
    { type = 'sweep', coords = vector4(1750.204, 2555.120, 44.5655, 326.5529) },
    { type = 'sweep', coords = vector4(1768.916, 2548.276, 44.5655, 53.6613) }
}

Config.PoliceJob = 'police'

Config.Clothes = {
    male = {
        components = {
            { ['component_id'] = 0,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 1,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 3,  ['texture'] = 0, ['drawable'] = 63 },
            { ['component_id'] = 4,  ['texture'] = 0, ['drawable'] = 163 },
            { ['component_id'] = 5,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 6,  ['texture'] = 0, ['drawable'] = 60 },
            { ['component_id'] = 7,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 8,  ['texture'] = 0, ['drawable'] = 15 },
            { ['component_id'] = 9,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 10, ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 11, ['texture'] = 0, ['drawable'] = 56 }
        }
    },
    female = {
        components = {
            { ['component_id'] = 0,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 1,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 3,  ['texture'] = 0, ['drawable'] = 76 },
            { ['component_id'] = 4,  ['texture'] = 0, ['drawable'] = 35 },
            { ['component_id'] = 5,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 6,  ['texture'] = 0, ['drawable'] = 49 },
            { ['component_id'] = 7,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 8,  ['texture'] = 0, ['drawable'] = 14 },
            { ['component_id'] = 9,  ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 10, ['texture'] = 0, ['drawable'] = 0 },
            { ['component_id'] = 11, ['texture'] = 0, ['drawable'] = 118 }
        }
    }
}
