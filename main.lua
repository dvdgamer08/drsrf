-- must start with loading the ac_common etc implicitly
-- this script will run on client via CSP

function script.draw()
    -- draw something simple on screen
    ac.debugOverlay("mpis pe mm", 10, 10)
end

function script.update(dt)
    -- maybe respond to some state
    local speed = ac.getCarState(0).speedKmh -- example
    -- store or draw etc
end
