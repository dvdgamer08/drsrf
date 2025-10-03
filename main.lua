-- DRS_Start.lua - USING PITS TELEPORT + MANUAL POSITIONING
-- Workaround for missing teleport API

local STATE_IDLE = 0
local STATE_COUNTDOWN = 1
local STATE_STARTMSG = 2
local state = STATE_COUNTDOWN

local COUNTDOWN_SECONDS = 30
local STARTMSG_SECONDS = 3
local TELEPORT_NAME = "HC_Start0"

local timer = COUNTDOWN_SECONDS
local startmsgTimer = 0

-- Teleportation system
local teleports = {}
local targetTeleport = nil
local teleportsLoaded = false
local teleportPending = false
local teleportStage = 0 -- 0=idle, 1=to pits, 2=to destination

-- Enhanced debug system
local logs = {}
local function debug(msg)
    local line = string.format("[%.2f] %s", os.clock(), msg)
    table.insert(logs, 1, line)
    if #logs > 10 then table.remove(logs) end
    print("DRS_DEBUG: " .. msg)
end

-- EXACT COPY of Comfy Map's loadTeleports function
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
        return
    end
    
    debug("onlineExtras config is available - proceeding...")
    local serverConfig = ac.INIConfig.onlineExtras()
    
    -- Use the EXACT same function that works in Comfy Map
    teleports = loadTeleports(serverConfig, true)
    
    -- Find our target teleport
    for index, teleport in ipairs(teleports) do
        if teleport.POINT == TELEPORT_NAME then
            targetTeleport = teleport
            debug(string.format("SUCCESS: Found target teleport '%s'", TELEPORT_NAME))
            debug(string.format("Position: %.1f, %.1f, %.1f", teleport.POS.x, teleport.POS.y, teleport.POS.z))
            debug(string.format("Heading: %.1f°", teleport.HEADING))
            break
        end
    end
    
    if not targetTeleport then
        debug("WARNING: Target teleport '" .. TELEPORT_NAME .. "' not found!")
        debug("Available teleports:")
        for _, t in ipairs(teleports) do
            debug(string.format("  - %s (pos: %.1f, %.1f, %.1f)", t.POINT, t.POS.x, t.POS.y, t.POS.z))
        end
    else
        debug("Teleport system ready - target coordinates loaded")
    end
    
    teleportsLoaded = true
end

-- Check what teleport functions are actually available
local function checkTeleportAPI()
    debug("=== TELEPORT API CHECK ===")
    
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

-- Calculate direction vector from heading
local function headingToDirection(heading)
    local rad = math.rad(heading)
    return vec3(math.sin(rad), 0, math.cos(rad))
end

-- Two-stage teleport: first to pits, then to destination
local function attemptTeleport()
    if not teleportsLoaded then
        debug("ERROR: Teleports not loaded yet")
        return false
    end
    
    if targetTeleport == nil then
        debug("ERROR: No target teleport data available")
        return false
    end
    
    debug("Starting two-stage teleport process...")
    debug(string.format("Target: %s at (%.1f, %.1f, %.1f) heading %.1f°", 
        TELEPORT_NAME, targetTeleport.POS.x, targetTeleport.POS.y, targetTeleport.POS.z, targetTeleport.HEADING))
    
    -- Stage 1: Teleport to pits using available function
    if ac.tryToTeleportToPits then
        debug("Stage 1: Teleporting to pits...")
        ac.tryToTeleportToPits()
        teleportPending = true
        teleportStage = 1
        debug("Pits teleport initiated - waiting for completion...")
        return true
    else
        debug("CRITICAL: ac.tryToTeleportToPits not available")
        return false
    end
end

-- Manual position setting (fallback method)
local function setCarPositionManual()
    if not targetTeleport then
        debug("ERROR: No target teleport for manual positioning")
        return false
    end
    
    debug("Attempting manual position set...")
    
    -- Get current car
    local car = ac.getCar(0)
    if not car then
        debug("ERROR: Could not get car reference")
        return false
    end
    
    -- Set position and orientation
    debug(string.format("Setting position to: %.1f, %.1f, %.1f", 
        targetTeleport.POS.x, targetTeleport.POS.y, targetTeleport.POS.z))
    
    -- Use physics to set car position
    if physics.setCarPosition then
        local direction = headingToDirection(targetTeleport.HEADING)
        physics.setCarPosition(0, targetTeleport.POS, direction)
        debug("Manual position set via physics.setCarPosition")
        return true
    else
        debug("WARNING: physics.setCarPosition not available")
        
        -- Last resort: try direct property assignment (may not work in online)
        car.position = targetTeleport.POS
        debug("Position set via direct assignment (may not work online)")
        return true
    end
end

-- Check if teleport point is occupied
local function checkTeleportAvailability()
    if targetTeleport == nil then 
        debug("Cannot check availability - no target data")
        return nil 
    end
    
    for i = 0, ac.getSim().carsCount - 1 do
        local car = ac.getCar(i)
        if car and car.isConnected then
            if car.position:distance(targetTeleport.POS) < 6 then
                debug(string.format("Teleport blocked by: %s", ac.getDriverName(i)))
                return ac.getDriverName(i)
            end
        end
    end
    return nil
end

function script.drawUI()
    ui.beginTransparentWindow("DRS_StartWindow", vec2(30, 100), vec2(350, 300))
    
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
    
    if targetTeleport ~= nil then
        ui.textColored("✓ Coordinates Loaded", rgbm(0, 1, 0, 1))
        ui.text(string.format("Position: %.1f, %.1f, %.1f", 
            targetTeleport.POS.x, targetTeleport.POS.y, targetTeleport.POS.z))
        ui.text(string.format("Heading: %.1f°", targetTeleport.HEADING))
        
        local occupiedBy = checkTeleportAvailability()
        if occupiedBy then
            ui.textColored("✗ BLOCKED by: " .. occupiedBy, rgbm(1, 0, 0, 1))
        else
            ui.textColored("✓ Position Available", rgbm(0, 1, 0, 1))
        end
        
        -- Teleport method status
        ui.separator()
        ui.text("Teleport Method:")
        if ac.tryToTeleportToPits then
            ui.textColored("✓ Pits Teleport Available", rgbm(0, 1, 0, 1))
            ui.text("Method: Pits → Destination")
        else
            ui.textColored("✗ No Teleport Methods", rgbm(1, 0, 0, 1))
        end
        
        if teleportPending then
            ui.textColored("Teleport in progress... Stage: " .. teleportStage, rgbm(1, 1, 0, 1))
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
    
    -- Manual position set button (fallback)
    if ui.button("Set Position Only (Fallback)", vec2(ui.windowWidth() - 20, 25)) then
        debug("Manual position set triggered")
        setCarPositionManual()
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
        debug("Script version: Pits Teleport Workaround")
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
    
    -- Handle pending teleport
    if teleportPending then
        if teleportStage == 1 then
            -- Wait a bit for pits teleport to complete, then move to destination
            debug("Waiting for pits teleport to complete...")
            teleportStage = 2
        elseif teleportStage == 2 then
            -- Now set the actual position
            debug("Pits teleport should be complete, setting final position...")
            setCarPositionManual()
            teleportPending = false
            teleportStage = 0
            debug("Two-stage teleport completed!")
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
            debug("Attempting two-stage teleport...")
            local success = attemptTeleport()
            if success then
                ac.setMessage("✓ Teleporting to start position...")
                debug("Teleport initiated successfully!")
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
    elseif message == "!setpos" then
        debug("Manual position set via chat")
        setCarPositionManual()
        return true
    end
    return false
end

-- Initialization
debug("=== DRS START SCRIPT LOADED ===")
debug("Using Pits Teleport + Manual Positioning Workaround")