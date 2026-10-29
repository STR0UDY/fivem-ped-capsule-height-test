-- Test commands for SET_PED_CAPSULE_HEIGHT_OVERRIDE. Needs a FiveM client built from the PR branch.
--
--   cap <height>   override the capsule top (meters above the ped's position); default is ~0.82
--   cap 0          remove the override
--   crouchtest     toggle a crouch walk + capsule height 0.25 (the game's own crouched height)
--   capsync        toggle sharing your override with other players (through your player state bag),
--                  so their clients apply it to your ped too

local SET_PED_CAPSULE_HEIGHT_OVERRIDE = 0x62A2D8E3

local current = nil
local crouched = false
local sync = false
local lastMessage = ''

-- overrides applied to other players' peds, from their state bags: [ped] = height
local remoteApplied = {}

local function setPedCapsuleHeight(ped, height)
    return pcall(Citizen.InvokeNative, SET_PED_CAPSULE_HEIGHT_OVERRIDE, ped, height + 0.0)
end

local function publish()
    LocalPlayer.state:set('capsuleHeight', sync and current or nil, true)
end

local function setCapsuleHeight(height)
    local ok, err = setPedCapsuleHeight(PlayerPedId(), height)
    if not ok then
        lastMessage = ('error: %s'):format(err)
        print('[capsule] ' .. lastMessage)
        return false
    end
    current = height > 0 and height or nil
    lastMessage = current and ('override set to %.2f'):format(current) or 'override removed'
    print('[capsule] ' .. lastMessage)
    publish()
    return true
end

RegisterCommand('cap', function(_, args)
    local height = tonumber(args[1])
    if not height then
        lastMessage = 'usage: cap <height>  (0 removes)'
        return
    end
    setCapsuleHeight(height)
end, false)

RegisterCommand('crouchtest', function()
    local ped = PlayerPedId()
    crouched = not crouched

    if crouched then
        RequestAnimSet('move_ped_crouched')
        while not HasAnimSetLoaded('move_ped_crouched') do Wait(0) end
        SetPedMovementClipset(ped, 'move_ped_crouched', 0.25)
        setCapsuleHeight(0.25)
    else
        ResetPedMovementClipset(ped, 0.25)
        setCapsuleHeight(0)
    end
end, false)

RegisterCommand('capsync', function()
    sync = not sync
    publish()
    lastMessage = sync and 'sharing override with other players' or 'not sharing override'
    print('[capsule] ' .. lastMessage)
end, false)

-- apply other players' shared overrides to their peds on this client
CreateThread(function()
    while true do
        local seen = {}

        for _, player in ipairs(GetActivePlayers()) do
            if player ~= PlayerId() then
                local ped = GetPlayerPed(player)
                local height = Player(GetPlayerServerId(player)).state.capsuleHeight or 0.0
                seen[ped] = true

                if (remoteApplied[ped] or 0.0) ~= height then
                    setPedCapsuleHeight(ped, height)
                    remoteApplied[ped] = height > 0 and height or nil
                end
            end
        end

        for ped in pairs(remoteApplied) do
            if not seen[ped] then
                remoteApplied[ped] = nil
            end
        end

        Wait(250)
    end
end)

local function drawText(x, y, text)
    SetTextFont(4)
    SetTextScale(0.0, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawCapsuleTop(ped, height)
    local top = GetEntityCoords(ped) + vector3(0.0, 0.0, height)
    DrawMarker(28, top.x, top.y, top.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 255, 80, 80, 200, false, false, 2, false, nil, nil, false)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local remoteCount = 0

        for remotePed, height in pairs(remoteApplied) do
            remoteCount = remoteCount + 1
            drawCapsuleTop(remotePed, height)
        end

        DrawRect(0.12, 0.345, 0.21, 0.135, 0, 0, 0, 150)
        drawText(0.02, 0.28, ('capsule override: %s'):format(current and ('%.2f'):format(current) or 'none'))
        drawText(0.02, 0.305, ('crouchtest: %s   sync: %s   z: %.2f'):format(crouched and 'on' or 'off', sync and 'on' or 'off', coords.z))
        drawText(0.02, 0.33, ('applied to other players: %d'):format(remoteCount))
        drawText(0.02, 0.355, lastMessage)

        if current then
            drawCapsuleTop(ped, current)
        end

        Wait(0)
    end
end)

print('[capsule] ready: cap <height>, crouchtest, capsync')
