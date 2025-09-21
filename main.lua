-- helloworld.lua

-- Get config parameters passed via server
local params = script_params or {}  -- depending on exact API naming
local foo = params.PARAM_FOO or "default foo"
local bar = params.PARAM_BAR or "default bar"

-- Example: when session starts, display a chat message
function ac.onSessionStart()
    ac.msg("Hello from online script! foo=" .. tostring(foo) .. ", bar=" .. tostring(bar))
end

-- Optionally do something per frame
function ac.onUpdate(dt)
    -- nothing for now
end
