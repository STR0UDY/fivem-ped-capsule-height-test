-- Test commands for SET_PED_CAPSULE_HEIGHT_OVERRIDE. Needs a FiveM client built from the PR branch.
--
--   cap <height>   override the capsule top (meters above the ped's position); default is ~0.82
--   cap 0          remove the override (CLEAR_PED_CAPSULE_HEIGHT_OVERRIDE)
--   crouchtest     toggle a crouch walk + capsule height 0.25 (the game's own crouched height)

local SET_PED_CAPSULE_HEIGHT_OVERRIDE = 0x62A2D8E3
local CLEAR_PED_CAPSULE_HEIGHT_OVERRIDE = 0x85A6FDA3

local current = nil
local crouched = false
local lastMessage = ''

local function setPedCapsuleHeight(ped, height)
    if height > 0 then
        return pcall(Citizen.InvokeNative, SET_PED_CAPSULE_HEIGHT_OVERRIDE, ped, height + 0.0)
    end
    return pcall(Citizen.InvokeNative, CLEAR_PED_CAPSULE_HEIGHT_OVERRIDE, ped)
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

local function drawText(x, y, text)
    SetTextFont(4)
    SetTextScale(0.0, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        DrawRect(0.12, 0.33, 0.21, 0.11, 0, 0, 0, 150)
        drawText(0.02, 0.28, ('capsule override: %s'):format(current and ('%.2f'):format(current) or 'none'))
        drawText(0.02, 0.305, ('crouchtest: %s   z: %.2f'):format(crouched and 'on' or 'off', coords.z))
        drawText(0.02, 0.33, lastMessage)

        if current then
            -- top of the overridden capsule, relative to the ped's position
            local top = coords + vector3(0.0, 0.0, current)
            DrawMarker(28, top.x, top.y, top.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 255, 80, 80, 200, false, false, 2, false, nil, nil, false)
        end

        Wait(0)
    end
end)

print('[capsule] ready: cap <height>, crouchtest')
