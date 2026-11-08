local MIN, MAX = vector3(-15.0, -470.0, 0.0), vector3(150.0, -310.0, 120.0)
local CENTRE = vector3(67.5, -390.0, 39.0)
local ENTER, LEAVE = 160.0, 190.0
local SITE_ZONE = 'az_los_santos_construction_site_01'
local CITY_ZONES = {
    'az_big_zones_ls_city_centre', 'az_big_zones_ls_01', 'az_big_zones_ls_03', 'az_los_santos_vinewood',
    'az_los_santos_centre_highway_01', 'AZ_DISTANT_VEHICLES_CITY_CENTRE', 'camCinematicMountedCamera__IsValid',
}
local SCENES = { 'FBI_HEIST_H5_MUTE_AMBIENCE_SCENE', 'GTAO_Mute_Traffic_Ambience_Scene' }
local near, nonCreation = false, false
local block, pop
local function quiet(on)
    for _, z in ipairs(CITY_ZONES) do
        if on then SetAmbientZoneState(z, false, true) else ClearAmbientZoneState(z, true) end
    end
    for _, s in ipairs(SCENES) do
        if on then StartAudioScene(s) else StopAudioScene(s) end
    end
end
local function inside(c)
    return c.x > MIN.x and c.x < MAX.x and c.y > MIN.y and c.y < MAX.y
end
local function occupiedByPlayer(veh)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end
local function remove(ent)
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
end
CreateThread(function()
    SetAmbientZoneState(SITE_ZONE, false, true)
    block = AddScenarioBlockingArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z, false, true, true, true)
    pop = AddPopMultiplierArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z, 0.0, 0.0, false, true)
    SetAllVehicleGeneratorsActiveInArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z, false, false)
    RemoveVehiclesFromGeneratorsInArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z, false)
    while true do
        local d = #(GetEntityCoords(PlayerPedId()).xy - CENTRE.xy)
        if not near and d < ENTER then
            near = true
            quiet(true)
            SetPedNonCreationArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z)
            nonCreation = true
        elseif near and d > LEAVE then
            near = false
            quiet(false)
            ClearPedNonCreationArea()
            nonCreation = false
        end
        if near then
            for _, ped in ipairs(GetGamePool('CPed')) do
                if not IsPedAPlayer(ped) and not IsEntityAMissionEntity(ped) and not IsPedInAnyVehicle(ped, true)
                    and inside(GetEntityCoords(ped)) and NetworkHasControlOfEntity(ped) then
                    remove(ped)
                end
            end
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if not IsEntityAMissionEntity(veh) and not occupiedByPlayer(veh) and inside(GetEntityCoords(veh))
                    and NetworkHasControlOfEntity(veh) then
                    local driver = GetPedInVehicleSeat(veh, -1)
                    if driver == 0 or not IsEntityOnScreen(veh) then
                        if driver ~= 0 then remove(driver) end
                        remove(veh)
                    end
                end
            end
        end
        Wait(near and 1000 or 3000)
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearAmbientZoneState(SITE_ZONE, true)
    if near then quiet(false) end
    if nonCreation then ClearPedNonCreationArea() end
    if block then RemoveScenarioBlockingArea(block, false) end
    if pop then RemovePopMultiplierArea(pop, false) end
    SetAllVehicleGeneratorsActiveInArea(MIN.x, MIN.y, MIN.z, MAX.x, MAX.y, MAX.z, true, false)
end)
local FOUNTAIN = vector3(45.464, -366.828, 42.402)
local fountain
CreateThread(function()
    RequestNamedPtfxAsset('core')
    while true do
        local d = #(GetEntityCoords(PlayerPedId()) - FOUNTAIN)
        if d < 120.0 and not fountain and HasNamedPtfxAssetLoaded('core') then
            UseParticleFxAssetNextCall('core')
            fountain = StartParticleFxLoopedAtCoord('ent_amb_fountain_double', FOUNTAIN.x, FOUNTAIN.y, FOUNTAIN.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
        elseif d > 140.0 and fountain then
            StopParticleFxLooped(fountain, false)
            fountain = nil
        end
        Wait(1000)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if fountain then StopParticleFxLooped(fountain, false) end
end)
local GATE_A, GATE_B, GATE_Z = vector2(133.382, -415.768), vector2(137.579, -404.524), 40.315
local GATE_C = vector3((133.382 + 137.579) / 2, (-415.768 + -404.524) / 2, GATE_Z)
local GATE_DIR, GATE_TRAVEL, GATE_MODEL = (GATE_B - GATE_A) / 12.000, 5.970, `ac_egate`
local leafA, leafB, gateOpen = nil, nil, 0.0
local GATE_HDG, GATE_SHUT = math.deg(math.atan2(GATE_DIR.y, GATE_DIR.x)), 0.02
local function placeGate()
    local a, b = GATE_A - GATE_DIR * (gateOpen - GATE_SHUT), GATE_B + GATE_DIR * (gateOpen - GATE_SHUT)
    SetEntityCoordsNoOffset(leafA, a.x, a.y, GATE_Z, false, false, false)
    SetEntityCoordsNoOffset(leafB, b.x, b.y, GATE_Z, false, false, false)
end
CreateThread(function()
    while true do
        local wait = 500
        local d = #(GetEntityCoords(PlayerPedId()) - GATE_C)
        if d < 150.0 and not leafA then
            RequestModel(GATE_MODEL)
            while not HasModelLoaded(GATE_MODEL) do Wait(50) end
            leafA = CreateObjectNoOffset(GATE_MODEL, GATE_A.x, GATE_A.y, GATE_Z, false, false, false)
            leafB = CreateObjectNoOffset(GATE_MODEL, GATE_B.x, GATE_B.y, GATE_Z, false, false, false)
            SetEntityHeading(leafA, GATE_HDG)
            SetEntityHeading(leafB, GATE_HDG + 180.0)
            FreezeEntityPosition(leafA, true)
            FreezeEntityPosition(leafB, true)
            SetModelAsNoLongerNeeded(GATE_MODEL)
            placeGate()
        elseif d > 180.0 and leafA then
            DeleteEntity(leafA)
            DeleteEntity(leafB)
            leafA, leafB = nil, nil
        end
        if leafA then
            local open = false
            for _, id in ipairs(GetActivePlayers()) do
                if #(GetEntityCoords(GetPlayerPed(id)) - GATE_C) < 22.0 then open = true break end
            end
            local want = open and GATE_TRAVEL or 0.0
            if gateOpen ~= want then
                local step = 1.6 * GetFrameTime()
                gateOpen = want > gateOpen and math.min(gateOpen + step, want) or math.max(gateOpen - step, want)
                placeGate()
                wait = 0
            end
        end
        Wait(wait)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if leafA then DeleteEntity(leafA) DeleteEntity(leafB) end
end)
local MAIN_A, MAIN_Z = vector2(5.415, -403.463), 38.416
local MAIN_DIR = vector2(0.24865, 0.96859)
local MAIN_C = vector3(6.289, -400.059, MAIN_Z)
local MAIN_TRAVEL, MAIN_MODEL = 7.029, `ac_mgate`
local mainLeaf, mainOpen = nil, 0.0
local function placeMain()
    local p = MAIN_A + MAIN_DIR * mainOpen
    SetEntityCoordsNoOffset(mainLeaf, p.x, p.y, MAIN_Z, false, false, false)
end
CreateThread(function()
    while true do
        local wait = 500
        local d = #(GetEntityCoords(PlayerPedId()) - MAIN_C)
        if d < 150.0 and not mainLeaf then
            RequestModel(MAIN_MODEL)
            while not HasModelLoaded(MAIN_MODEL) do Wait(50) end
            mainLeaf = CreateObjectNoOffset(MAIN_MODEL, MAIN_A.x, MAIN_A.y, MAIN_Z, false, false, false)
            SetEntityHeading(mainLeaf, 75.60)
            FreezeEntityPosition(mainLeaf, true)
            SetModelAsNoLongerNeeded(MAIN_MODEL)
            placeMain()
        elseif d > 180.0 and mainLeaf then
            DeleteEntity(mainLeaf)
            mainLeaf = nil
        end
        if mainLeaf then
            local open = false
            for _, id in ipairs(GetActivePlayers()) do
                if #(GetEntityCoords(GetPlayerPed(id)) - MAIN_C) < 16.0 then open = true break end
            end
            local want = open and MAIN_TRAVEL or 0.0
            if mainOpen ~= want then
                local step = 2.2 * GetFrameTime()
                mainOpen = want > mainOpen and math.min(mainOpen + step, want) or math.max(mainOpen - step, want)
                placeMain()
                wait = 0
            end
        end
        Wait(wait)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and mainLeaf then DeleteEntity(mainLeaf) end
end)
local ROLL_MODEL, ROLL_YAW, ROLL_Z = `ac_rollleaf`, -19.6, 40.55
local ROLLS = {}
for _, v in ipairs({ -13.0, 13.0 }) do
    local c, s = math.cos(math.rad(ROLL_YAW)), math.sin(math.rad(ROLL_YAW))
    local function at(u) return vector2(121.0 + u * c - v * s, -405.0 + u * s + v * c) end
    ROLLS[#ROLLS + 1] = { low = at(8.40), high = at(8.29), c = vector3(at(8.5).x, at(8.5).y, ROLL_Z), open = 0.0 }
end
local ROLL_TRAVEL = 3.56
local function placeRoll(r)
    SetEntityCoordsNoOffset(r.a, r.low.x, r.low.y, ROLL_Z + r.open, false, false, false)
    SetEntityCoordsNoOffset(r.b, r.high.x, r.high.y, ROLL_Z + 1.72 + r.open * .5, false, false, false)
end
CreateThread(function()
    while true do
        local wait = 500
        for _, r in ipairs(ROLLS) do
            local d = #(GetEntityCoords(PlayerPedId()) - r.c)
            if d < 150.0 and not r.a then
                RequestModel(ROLL_MODEL)
                while not HasModelLoaded(ROLL_MODEL) do Wait(50) end
                r.a = CreateObjectNoOffset(ROLL_MODEL, r.low.x, r.low.y, ROLL_Z, false, false, false)
                r.b = CreateObjectNoOffset(ROLL_MODEL, r.high.x, r.high.y, ROLL_Z + 1.72, false, false, false)
                SetEntityHeading(r.a, ROLL_YAW)
                SetEntityHeading(r.b, ROLL_YAW)
                FreezeEntityPosition(r.a, true)
                FreezeEntityPosition(r.b, true)
                placeRoll(r)
            elseif d > 180.0 and r.a then
                DeleteEntity(r.a)
                DeleteEntity(r.b)
                r.a, r.b = nil, nil
            end
            if r.a then
                local open = false
                for _, id in ipairs(GetActivePlayers()) do
                    if #(GetEntityCoords(GetPlayerPed(id)) - r.c) < 9.0 then open = true break end
                end
                local want = open and ROLL_TRAVEL or 0.0
                if r.open ~= want then
                    local step = 1.1 * GetFrameTime()
                    r.open = want > r.open and math.min(r.open + step, want) or math.max(r.open - step, want)
                    placeRoll(r)
                    wait = 0
                end
            end
        end
        Wait(wait)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, r in ipairs(ROLLS) do
        if r.a then DeleteEntity(r.a) DeleteEntity(r.b) end
    end
end)
