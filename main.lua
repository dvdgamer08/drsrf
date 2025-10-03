-- DRS_Start.lua - USING COMFY MAP'S EXACT APPROACH
-- This uses the same teleportation system that works in Comfy Map

local STATE_IDLE = 0
local STATE_COUNTDOWN = 1
local STATE_STARTMSG = 2
local state = STATE_COUNTDOWN

local COUNTDOWN_SECONDS = 30
local STARTMSG_SECONDS = 3
local TELEPORT_NAME = "HC_Start0"

local timer = COUNTDOWN_SECONDS
local startmsgTimer = 0

-- Teleportation system (EXACT COPY from Comfy Map)
local teleports = {}
local targetTeleportIndex = nil
local teleportsLoaded = false

-- Enhanced debug system
local logs = {}
local function debug(msg)
    local line = string.format("[%.2f] %s", os.clock(), msg)
    table.insert(logs, 1, line)
    if #logs > 10 then table.remove(logs) end
    print("DRS_DEBUG: " .. msg) -- Also print to console
end

-- EXACT COPY of Comfy Map's loadTeleports function (this definitely works!)
local function loadTeleports(ini, online)
  debug("Loading teleports using Comfy Map method...")
  local teleports, sorted_teleports = {}, {}

  for a, b in ini:iterateValues('TELEPORT_DESTINATIONS', 'POINT') do
    local n = tonumber(a:match('%d+')) + 1

    if teleports[n] == nil then
      for i = #teleports, n do
        if teleports[i] == nil then teleports[i] = {} end
      end
    end

    local suffix = a:match('_(%a+)$')
    if suffix==nil then teleports[n]['POINT'] = b
    elseif suffix == 'POS' then teleports[n]['POS'] = ini:get('TELEPORT_DESTINATIONS', a, vec3())
    elseif suffix == 'HEADING' then teleports[n]['HEADING'] = ini:get('TELEPORT_DESTINATIONS', a, 0)
    elseif suffix == 'GROUP' then teleports[n]['GROUP'] = ini:get('TELEPORT_DESTINATIONS', a, 'group')
    end
    teleports[n]["N"] = n
    teleports[n]['INDEX'] = 0
    teleports[n]['LOADED'] = true
    teleports[n]['ONLINE'] = online
  end

  for i = 1, #teleports do
    if teleports[i]["POINT"] ~= nil then
      teleports[i]['INDEX'] = #sorted_teleports
      if teleports[i].HEADING == nil then teleports[i]['HEADING'] = 0 end
      if teleports[i].POS == nil then teleports[i]['POS'] = vec3() end
      table.insert(sorted_teleports,teleports[i])
    end
  end
  
  debug(string.format("Comfy Map loader found %d teleport points", #sorted_teleports))
  return sorted_teleports
end

-- Load teleports using Comfy Map's proven method
local function loadTeleportDestinations()
    debug("Starting teleport destination loading...")
    
    if not ac.INIConfig.onlineExtras then
        debug("ERROR: onlineExtras config not available")
        debug("This means the script is not running in proper online mode")
        return
    end
    
    debug("onlineExtras config is available - proceeding...")
    local serverConfig = ac.INIConfig.onlineExtras()
    
    -- Use the EXACT same function that works in Comfy Map
    teleports = loadTeleports(serverConfig, true)
    
    -- Find our target teleport
    for index, teleport in ipairs(teleports) do
        if teleport.POINT == TELEPORT_NAME then
            targetTeleportIndex = teleport.INDEX
            debug(string.format("SUCCESS: Found target teleport '%s' at index %d", TELEPORT_NAME, targetTeleportIndex))
            debug(string.format("Teleport position: %.1f, %.1f, %.1f", teleport.POS.x, teleport.POS.y, teleport.POS.z))
            break
        end
    end
    
    if not targetTeleportIndex then
        debug("WARNING: Target teleport '" .. TELEPORT_NAME .. "' not found!")
        debug("Available teleports:")
        for _, t in ipairs(teleports) do
            debug(string.format("  - %s (index: %d)", t.POINT, t.INDEX))
        end
    else
        debug("Teleport system ready - target index: " .. targetTeleportIndex)
    end
    
    teleportsLoaded = true
end

-- Check what teleport functions are actually available
local function checkTeleportAPI()
    debug("=== TELEPORT API CHECK ===")
    
    -- Check all potentially relevant functions
    local apiFunctions = {
        'teleportToServerPoint',
        'canTeleportToServerPoint', 
        'teleportToDestination',
        'tryToTeleportToPits'
    }
    
    local availableFunctions = {}
    for _, funcName in ipairs(apiFunctions) do
        if ac[funcName] then
            table.insert(availableFunctions, funcName)
            debug("FOUND: ac." .. funcName)
        else
            debug("MISSING: ac." .. funcName)
        end
    end
    
    debug("Available teleport functions: " .. table.concat(availableFunctions, ", "))
    debug("=== END API CHECK ===")
    
    return #availableFunctions > 0
end

-- Attempt teleport using Comfy Map's direct approach
local function attemptTeleport()
    if not teleportsLoaded then
        debug("ERROR: Teleports not loaded yet")
        return false
    end
    
    if targetTeleportIndex == nil then
        debug("ERROR: No target teleport index available")
        return false
    end
    
    debug(string.format("Attempting teleport to '%s' (index: %d)", TELEPORT_NAME, targetTeleportIndex))
    
    -- Use the EXACT same approach Comfy Map uses
    if ac.teleportToServerPoint then
        debug("ac.teleportToServerPoint IS AVAILABLE - calling function...")
        
        -- Optional: Check if teleport is available (like Comfy Map does)
        if ac.canTeleportToServerPoint then
            if ac.canTeleportToServerPoint(targetTeleportIndex) then
                debug("Teleport point is available - proceeding...")
            else
                debug("WARNING: Teleport point is blocked or unavailable")
                -- Comfy Map still attempts teleport even if blocked
            end
        end
        
        -- THIS IS THE EXACT CALL COMFY MAP MAKES
        ac.teleportToServerPoint(targetTeleportIndex)
        debug("Teleport command executed successfully")
        return true
    else
        debug("CRITICAL ERROR: ac.teleportToServerPoint is NOT available")
        debug("This suggests the script environment is different from Comfy Map")
        return false
    end
end

-- Check if teleport point is occupied (like Comfy Map does)
local function checkTeleportAvailability()
    if targetTeleportIndex == nil then 
        debug("Cannot check availability - no target index")
        return nil 
    end
    
    for i = 0, ac.getSim().carsCount - 1 do
        local car = ac.getCar(i)
        if car and car.isConnected then
            for _, teleport in ipairs(teleports) do
                if teleport.INDEX == targetTeleportIndex then
                    if car.position:distance(teleport.POS) < 6 then
                        debug(string.format("Teleport blocked by: %s", ac.getDriverName(i)))
                        return ac.getDriverName(i)
                    end
                    break
                end
            end
        end
    end
    return nil
end

function script.drawUI()
    ui.beginTransparentWindow("DRS_StartWindow", vec2(30, 100), vec2(350, 280))
    
    -- State display
    ui.pushFont(ui.Font.Main)
    if state == STATE_COUNTDOWN then
        ui.textColored("Countdown: " .. math.ceil(timer) .. "s", rgbm(1, 1, 0, 1))
    elseif state == STATE_STARTMSG then
        ui.textColored("START!", rgbm(0, 1, 0, 1))
    else
        ui.text("Idle (finished)")
    end
    ui.popFont()
    
    ui.separator()
    
    -- Teleport status
    ui.text("Teleport Target: " .. TELEPORT_NAME)
    
    if targetTeleportIndex ~= nil then
        ui.textColored("✓ Server Index: " .. targetTeleportIndex, rgbm(0, 1, 0, 1))
        
        local occupiedBy = checkTeleportAvailability()
        if occupiedBy then
            ui.textColored("✗ BLOCKED by: " .. occupiedBy, rgbm(1, 0, 0, 1))
        else
            ui.textColored("✓ Position Available", rgbm(0, 1, 0, 1))
        end
        
        -- API status
        if ac.teleportToServerPoint then
            ui.textColored("✓ ac.teleportToServerPoint: AVAILABLE", rgbm(0, 1, 0, 1))
            if ac.canTeleportToServerPoint then
                if ac.canTeleportToServerPoint(targetTeleportIndex) then
                    ui.textColored("✓ Teleport Point: ACCESSIBLE", rgbm(0, 1, 0, 1))
                else
                    ui.textColored("✗ Teleport Point: BLOCKED", rgbm(1, 1, 0, 1))
                end
            end
        else
            ui.textColored("✗ ac.teleportToServerPoint: MISSING", rgbm(1, 0, 0, 1))
        end
    else
        ui.textColored("✗ Teleport: NOT FOUND", rgbm(1, 0, 0, 1))
    end
    
    ui.separator()
    
    -- Manual teleport button
    if ui.button("Manual Teleport Now", vec2(ui.windowWidth() - 20, 25)) then
        debug("Manual teleport triggered via button")
        attemptTeleport()
    end
    
    ui.separator()
    ui.text("Debug Log (newest first):")
    ui.beginChild("LogScroll", vec2(ui.windowWidth() - 20, 100), true)
    for i = 1, #logs do
        ui.text(logs[i])
    end
    ui.endChild()

    ui.endTransparentWindow()
end

function script.update(dt)
    -- Initialize on first update
    if not teleportsLoaded then
        debug("DRS Start script initializing...")
        debug("Script version: Comfy Map Method")
        debug("CSP Version: " .. (ac.getPatchVersionCode() or "Unknown"))
        
        -- Check what API functions are available
        checkTeleportAPI()
        
        -- Load teleports using Comfy Map's method
        if ac.INIConfig.onlineExtras then
            loadTeleportDestinations()
        else
            debug("CRITICAL: onlineExtras not available - script may not be running in online mode")
        end
    end
    
    -- Countdown logic
    if state == STATE_COUNTDOWN then
        timer = timer - dt
        
        -- Apply brakes during countdown
        if timer > 10 then
            pcall(function()
                physics.forceUserBrakesFor(0.05, 1.0)
                physics.forceUserThrottleFor(0.05, 0.0)
            end)
        end
        
        -- Teleport at 10 seconds
        if timer <= 10 and timer + dt > 10 then
            debug("=== COUNTDOWN REACHED 10s ===")
            debug("Attempting automatic teleport...")
            local success = attemptTeleport()
            if success then
                ac.setMessage("✓ Teleported to start position!")
                debug("Teleport successful!")
            else
                ac.setMessage("✗ Teleport failed - check debug log")
                debug("Teleport failed - see logs above")
            end
        end
        
        if timer <= 0 then
            state = STATE_STARTMSG
            startmsgTimer = STARTMSG_SECONDS
            ac.setMessage("START!")
            debug("=== COUNTDOWN COMPLETE - START! ===")
        end
    
    elseif state == STATE_STARTMSG then
        startmsgTimer = startmsgTimer - dt
        if startmsgTimer <= 0 then
            state = STATE_IDLE
            debug("Reset to idle state")
        end
    end
end

-- Chat command support
function script.chat(message)
    if message == "!start" or message == "!teleport" then
        debug("Chat command received: " .. message)
        attemptTeleport()
        return true
    elseif message == "!drsdebug" then
        debug("Manual debug trigger via chat")
        checkTeleportAPI()
        loadTeleportDestinations()
        return true
    end
    return false
end

-- Initialization
debug("=== DRS START SCRIPT LOADED ===")
debug("Using Comfy Map's proven teleportation system")