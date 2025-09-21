-- timer_teleport.lua
-- Online script for CSP: countdown + teleport + start message

-- We assume certain API functions exist:
-- ac.onUpdate(dt): called every frame / tick
-- ac.onDraw(): to draw UI / overlays
-- ac.isButtonPressed( ... ): or some UI callback for buttons
-- ac.msg(...) : to display chat / message
-- ac.teleportTo( destinationName ) : teleport to a teleport destination
-- ac.sleep(s) or local time accumulation

local countdown = nil     -- seconds remaining; nil means "not started"
local timer_active = false
local teleport_done = false
local show_start_message = false
local start_message_timer = 0

-- You may want server parameters:
local param_teleport_dest = script_params and script_params.PARAM_TELEPORT_DEST or "HC_Start0"

-- UI: define a button
function ac.onDraw()
    -- Draw a simple button. Coordinates / UI style depend on your version of CSP.
    -- Pseudocode:
    local x, y, w, h = 50, 50, 150, 40
    ac.drawButton(x, y, w, h, "Start Timer", function() 
        onStartTimerClicked()
    end)

    -- If timer is running, draw the countdown
    if timer_active and countdown then
        ac.drawText(x, y + 50, string.format("Time: %d", math.ceil(countdown)), 1.0, 1.0, 1.0, 1.0, 24)
    end

    -- If show_start_message, draw "START" in big font
    if show_start_message then
        ac.drawTextCentered(0.5, 0.5, "START", 1.0, 1.0, 0.0, 1.0, 64)  -- yellow, large
    end
end

function onStartTimerClicked()
    if not timer_active then
        timer_active = true
        teleport_done = false
        countdown = 60
        show_start_message = false
        start_message_timer = 0
    end
end

function ac.onUpdate(dt)
    if timer_active and countdown then
        countdown = countdown - dt
        -- teleport at 30 seconds
        if (not teleport_done) and countdown <= 30 then
            teleport_done = true
            -- perform teleport
            -- depending on API, might be: ac.teleportTo( param_teleport_dest )
            -- or ac.teleportToDestination( param_teleport_dest )
            if ac.teleportTo then
                ac.teleportTo(param_teleport_dest)
            elseif ac.teleportToDestination then
                ac.teleportToDestination(param_teleport_dest)
            else
                ac.log("Teleport API not found!")
            end
        end

        -- when timer ends
        if countdown <= 0 then
            timer_active = false
            show_start_message = true
            start_message_timer = 2.0  -- 2 seconds to show
        end
    end

    if show_start_message then
        start_message_timer = start_message_timer - dt
        if start_message_timer <= 0 then
            show_start_message = false
        end
    end
end

-- Optionally: handle session start / reset
function ac.onSessionStart()
    -- Reset everything
    timer_active = false
    teleport_done = false
    countdown = nil
    show_start_message = false
    start_message_timer = 0
end

-- If you want to display chat message when teleport happens or when timer starts:
-- you can add:
-- ac.msg("Teleporting to " .. tostring(param_teleport_dest) .. " at 30 seconds!")
-- ac.msg("Timer started (60s)!")
