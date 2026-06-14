--====================================================================
-- SiloAssist - Main Controller
-- Responsibility: state machine, update loop, event handling,
-- stuck detection, coordination between subsystems.
-- Per-vehicle state: hudVisible, siloMode, heightOffset, state
--====================================================================

siloAssist = {}
siloAssist.modDirectory = g_currentModDirectory
siloAssist.modName = g_currentModName
siloAssist.vehicle = nil
siloAssist.lastToggleTime = 0
siloAssist.COOLDOWN_MS = 300

siloAssistState = {}
siloAssistState.isStuck = false
siloAssistState.stuckTimer = 0
siloAssistState.wheelSlipDetected = false
siloAssistState.throttleActive = false
siloAssistState.isReversing = false
siloAssistState.wasReversing = false
siloAssistState.wasInSilo = false

siloAssist.SCRIPT_FILES = {
    "scripts/core/siloAssistConfig.lua",
    "scripts/core/siloAssistDebug.lua",
    "scripts/core/siloAssistVehicleState.lua",
    "scripts/core/siloAssistToolDetection.lua",
    "scripts/core/siloAssistSiloDetector.lua",
    "scripts/controller/siloAssistTiltController.lua",
    "scripts/hooks/siloAssistHeightController.lua",
    "scripts/hooks/siloAssistDumpController.lua",
    "scripts/hud/siloAssistHud.lua",
    "scripts/hud/siloAssistModPanel.lua",
}

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
function siloAssist:loadMap()
    siloAssistVehicleState.resetAll()
    siloAssist.lastToggleTime = 0

    siloAssist:installPlayerInputHook()
    siloAssistHeightController.installHooks()
    siloAssistDebug.init()
    addConsoleCommand("reloadSiloAssist", "Reload SiloAssist scripts", "consoleReloadScripts", siloAssist)
    addConsoleCommand("siloAssistDebug", "Toggle SiloAssist debug logging", "consoleToggleDebug", siloAssist)

    siloAssistVehicleState.loadFromXML()

    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, siloAssist.onSaveGame)

    print("[SiloAssist] loadMap: calling siloAssistModPanel.register()")
    siloAssistModPanel.register()
end

function siloAssist:deleteMap()
    siloAssistVehicleState.saveToXML()

    siloAssistHeightController.uninstallHooks()
    siloAssist:uninstallPlayerInputHook()
    removeConsoleCommand("reloadSiloAssist")
    removeConsoleCommand("siloAssistDebug")
    siloAssistVehicleState.resetAll()

    siloAssistModPanel.deleteMap()
end

---------------------------------------------------------------------
-- Save hook (called when game saves)
---------------------------------------------------------------------
function siloAssist.onSaveGame()
    if g_server ~= nil then
        siloAssistVehicleState.saveToXML()
    end
end

---------------------------------------------------------------------
-- Stuck detection
---------------------------------------------------------------------
function siloAssist.checkStuck(vehicle, dt)
    local config = siloAssistConfig

    if vehicle == nil or not vehicle:getIsMotorStarted() then
        siloAssistState.stuckTimer = 0
        siloAssistState.isStuck = false
        siloAssistState.wheelSlipDetected = false
        siloAssistState.throttleActive = false
        return false
    end

    local speed = vehicle:getLastSpeed()
    siloAssistState.wheelSlipDetected = siloAssist.checkWheelSlip(vehicle)
    siloAssistState.throttleActive = siloAssist.checkThrottleActive(vehicle)

    if speed < config.STUCK_SPEED_THRESHOLD and siloAssistState.wheelSlipDetected then
        siloAssistState.stuckTimer = siloAssistState.stuckTimer + dt
        if siloAssistState.stuckTimer >= config.STUCK_TIME_THRESHOLD * 1000 then
            siloAssistState.isStuck = true
            siloAssistDebug.log("Stuck", string.format("STUCK detected: speed=%.1f slip=%s timer=%dms", speed, tostring(siloAssistState.wheelSlipDetected), siloAssistState.stuckTimer))
            return true
        end
    else
        if siloAssistState.isStuck then
            siloAssistDebug.log("Stuck", string.format("Unstuck: speed=%.1f slip=%s", speed, tostring(siloAssistState.wheelSlipDetected)))
        end
        siloAssistState.stuckTimer = 0
        siloAssistState.isStuck = false
    end

    return false
end

function siloAssist.checkWheelSlip(vehicle)
    if vehicle == nil or vehicle.spec_wheels == nil then
        return false
    end

    local wheels = vehicle.spec_wheels.wheels
    if wheels == nil or #wheels == 0 then
        return false
    end

    local slipCount = 0
    for _, wheel in ipairs(wheels) do
        if wheel.slip ~= nil and wheel.slip > 0.3 then
            slipCount = slipCount + 1
        end
    end

    local totalWheels = #wheels
    if totalWheels == 0 then
        return false
    end

    return slipCount / totalWheels > 0.25
end

function siloAssist.checkThrottleActive(vehicle)
    if vehicle == nil then
        return false
    end

    local spec = vehicle.spec_drivable
    if spec ~= nil and spec.inputThrottle ~= nil then
        return math.abs(spec.inputThrottle) > 0.1
    end

    local specMotor = vehicle.spec_motorized
    if specMotor ~= nil then
        local cruiseControl = vehicle.spec_cruiseControl
        if cruiseControl ~= nil and cruiseControl.isEnabled then
            return true
        end
    end

    return false
end

---------------------------------------------------------------------
-- Update: main loop
---------------------------------------------------------------------
function siloAssist:update(dt)
    local currentVehicle = nil
    if g_localPlayer ~= nil then
        currentVehicle = g_localPlayer:getCurrentVehicle()
    end

    local vehicleChanged = siloAssistVehicleState.switchVehicle(currentVehicle)
    if vehicleChanged then
        siloAssistDebug.log("Main", "Vehicle changed, restoring per-vehicle state")
        if siloAssistVehicleState.currentState ~= nil then
            siloAssistState.isStuck = false
            siloAssistState.stuckTimer = 0
            siloAssistState.wheelSlipDetected = false
            siloAssistState.throttleActive = false
            siloAssistState.isReversing = false
            siloAssistState.wasReversing = false
            siloAssistState.wasInSilo = false
            siloAssistSiloDetector.reset()
            siloAssistToolDetection.reset()
            siloAssistHeightController.reset()
            siloAssistTiltController.reset()
            siloAssistDumpController.reset()
            siloAssistVehicleState.setState(siloAssistConfig.STATE_OFF)
        end
    end

    siloAssist.vehicle = currentVehicle
    local vehicle = siloAssist.vehicle
    local state = siloAssistVehicleState.getState()

    if state == siloAssistConfig.STATE_OFF then
        if vehicle ~= nil then
            siloAssistSiloDetector.update(vehicle, dt)
        end
        if siloAssistVehicleState.isHudVisible() and vehicle ~= nil then
            siloAssistHud:updateStatusText(dt)
        end
        return
    end

    if vehicle == nil then
        siloAssistDebug.log("Main", "deactivate: vehicle=nil")
        siloAssist:deactivate()
        return
    end

    if siloAssistToolDetection.toolType == nil then
        siloAssistDebug.log("Main", "deactivate: toolType=nil")
        siloAssist:deactivate()
        return
    end

    siloAssistState.isReversing = siloAssistToolDetection.isReversing(vehicle)

    local justStartedReversing = siloAssistState.isReversing and not siloAssistState.wasReversing
    siloAssistState.wasReversing = siloAssistState.isReversing

    siloAssist.checkStuck(vehicle, dt)

    siloAssistDebug.logThrottled("Main", "state", string.format(
        "state=%s rev=%s stuck=%s slip=%s throttle=%s speed=%.1f",
        state,
        tostring(siloAssistState.isReversing),
        tostring(siloAssistState.isStuck),
        tostring(siloAssistState.wheelSlipDetected),
        tostring(siloAssistState.throttleActive),
        vehicle:getLastSpeed()
    ))

    siloAssistSiloDetector.update(vehicle, dt)

    local justLeftSilo = siloAssistState.wasInSilo and not siloAssistSiloDetector.isInSilo

    if siloAssistState.isReversing and siloAssistToolDetection.toolType ~= "shovel" then
        if justStartedReversing then
            siloAssistDebug.log("Main", "Started reversing -> raiseBlade")
            siloAssistHeightController.raiseBlade(vehicle)
        end
        siloAssistHud:updateStatusText(dt)
        siloAssistState.wasInSilo = false
        return
    end

    if not siloAssistSiloDetector.isInSilo or siloAssistSiloDetector.currentSilo == nil then
        if justLeftSilo then
            siloAssistDebug.log("Main", "Left silo -> raiseBlade")
            if siloAssistToolDetection.controlType ~= nil then
                siloAssistHeightController.raiseBlade(vehicle)
            end
        end

        -- Pre-positioning: near silo but not yet in it
        local isNear, _, distToEdge = siloAssistSiloDetector.isNearSilo(vehicle, siloAssistConfig.PRE_ENTRY_DISTANCE)
        if isNear and siloAssistToolDetection.controlType ~= nil then
            local speed = vehicle:getLastSpeed()
            if speed >= siloAssistConfig.MIN_SPEED_FOR_CONTROL then
                siloAssistHeightController.applyPreEntry(vehicle, distToEdge)
                siloAssistTiltController.update(vehicle)
            end
        end

        if state == siloAssistConfig.STATE_WAITING then
            siloAssistHud:updateStatusText(dt)
            siloAssistState.wasInSilo = false
            return
        end

        if state ~= siloAssistConfig.STATE_OFF then
            siloAssistVehicleState.setState(siloAssistConfig.STATE_WAITING)
        end
        siloAssistDebug.logThrottled("Main", "notInSilo", "Not in silo, waiting...")
        siloAssistHud:updateStatusText(dt)
        siloAssistState.wasInSilo = false
        return
    end

    siloAssistState.wasInSilo = true

    if state == siloAssistConfig.STATE_WAITING then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Entered silo -> ACTIVE")
    end

    local silo = siloAssistSiloDetector.currentSilo
    local progress = siloAssistSiloDetector.progress

    if siloAssistToolDetection.toolType == "shovel" and siloAssistState.isReversing then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_DUMPING)
        siloAssistDebug.logThrottled("Main", "dumping", "Shovel reversing -> DUMPING")
    elseif state == siloAssistConfig.STATE_DUMPING and not siloAssistState.isReversing then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Dumping -> ACTIVE (forward)")
    end

    if siloAssistState.isStuck then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_RAISING)
        siloAssistDebug.logThrottled("Main", "stuck", "Stuck detected -> RAISING")
    elseif state == siloAssistConfig.STATE_RAISING and not siloAssistState.isStuck then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Unstuck -> ACTIVE")
    end

    local fillHeight = siloAssistSiloDetector.stagedFillHeight
    local speed = vehicle:getLastSpeed()

    if speed >= siloAssistConfig.MIN_SPEED_FOR_CONTROL then
        siloAssistHeightController.update(vehicle, silo, progress, fillHeight, dt)
        siloAssistTiltController.update(vehicle)
    else
        siloAssistDebug.logThrottled("Main", "slow", string.format(
            "Speed %.1f < MIN_SPEED %.1f: skipping height+tilt control",
            speed, siloAssistConfig.MIN_SPEED_FOR_CONTROL
        ))
    end

    if siloAssistToolDetection.toolType == "shovel" then
        siloAssistDumpController.update(vehicle, silo, progress, dt)
    end

    siloAssistHud:updateStatusText(dt)

    siloAssistModPanel.update()
end

---------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------
function siloAssist:draw()
    new2DLayer()
    siloAssistHud:draw()
end

---------------------------------------------------------------------
-- Mouse events
---------------------------------------------------------------------
function siloAssist:mouseEvent(posX, posY, isDown, isUp, button)
    if siloAssistHud:mouseEvent(posX, posY, isDown, isUp, button) then
        return
    end
end

---------------------------------------------------------------------
-- Activate / deactivate
---------------------------------------------------------------------
function siloAssist:activate()
    local vehicle = siloAssist.vehicle
    if vehicle == nil then
        siloAssistDebug.log("Activate", "vehicle=nil, aborting")
        return
    end

    local success = siloAssistToolDetection.initTool(vehicle)
    if not success then
        siloAssistDebug.log("Activate", "initTool failed, no tool found")
        siloAssistHud.showStatusText(g_i18n:getText("sa_noTool"))
        return
    end

    siloAssistDebug.log("Activate", "toolType=" .. tostring(siloAssistToolDetection.toolType) .. " controlType=" .. tostring(siloAssistToolDetection.controlType))

    siloAssistSiloDetector.update(vehicle, 0)

    if not siloAssistSiloDetector.isInSilo then
        local isNear, _ = siloAssistSiloDetector.isNearSilo(vehicle, siloAssistConfig.PRE_ENTRY_DISTANCE + 5)
        if not isNear then
            siloAssistDebug.log("Activate", "Not near silo, entering WAITING")
            siloAssistHud.showStatusText(g_i18n:getText("sa_notInSilo"))
            siloAssistVehicleState.setState(siloAssistConfig.STATE_WAITING)
            return
        end
        siloAssistDebug.log("Activate", "Near silo, entering WAITING")
    else
        siloAssistDebug.log("Activate", "In silo, entering ACTIVE")
    end

    siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
    siloAssistDumpController.reset()
    siloAssistHud.showStatusText(g_i18n:getText("sa_statusActive"))
end

function siloAssist:deactivate()
    local vehicle = g_localPlayer:getCurrentVehicle()
    if vehicle ~= nil and siloAssistToolDetection.controlType ~= nil then
        siloAssistHeightController.raiseBlade(vehicle)
        siloAssistTiltController.fullRetractTilt()
    end
    siloAssistVehicleState.setState(siloAssistConfig.STATE_OFF)
    siloAssistHeightController.reset()
    siloAssistTiltController.reset()
    siloAssistToolDetection.reset()
    siloAssistDumpController.reset()
    siloAssistSiloDetector.reset()
    siloAssistVehicleState.resetRuntimeState()
end

---------------------------------------------------------------------
-- Toggle / cycle
---------------------------------------------------------------------
function siloAssist:toggleAssist()
    local currentTime = getTime() * 1000
    if currentTime - siloAssist.lastToggleTime < siloAssist.COOLDOWN_MS then
        return
    end
    siloAssist.lastToggleTime = currentTime

    local state = siloAssistVehicleState.getState()
    if state == siloAssistConfig.STATE_OFF then
        siloAssist:activate()
    else
        siloAssist:deactivate()
        siloAssistHud.showStatusText(g_i18n:getText("sa_statusOff"))
    end
end

function siloAssist:cycleSettings()
    local currentTime = getTime() * 1000
    if currentTime - siloAssist.lastToggleTime < siloAssist.COOLDOWN_MS then
        return
    end
    siloAssist.lastToggleTime = currentTime

    siloAssistConfig.cycleMode()
    local label = g_i18n:getText(siloAssistConfig.getModeLabel())
    siloAssistHud.showStatusText(label)
end

function siloAssist:toggleHud()
    siloAssistHud:toggle()
end

---------------------------------------------------------------------
-- Input hook
---------------------------------------------------------------------
function siloAssist:installPlayerInputHook()
    if self.playerInputHooked then
        return
    end
    if PlayerInputComponent == nil then
        return
    end

    local function registerSiloAssistActions(self, superFunc, ...)
        superFunc(self, ...)

        if InputAction.SA_TOGGLE ~= nil then
            local _, eventId = g_inputBinding:registerActionEvent(
                InputAction.SA_TOGGLE, siloAssist, siloAssist.onToggleAssist,
                false, true, false, true)
            if eventId ~= nil then
                g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_SA_TOGGLE"))
                g_inputBinding:setActionEventTextVisibility(eventId, true)
                g_inputBinding:setActionEventActive(eventId, true)
            end
        end

        if InputAction.SA_SETTINGS ~= nil then
            local _, eventId = g_inputBinding:registerActionEvent(
                InputAction.SA_SETTINGS, siloAssist, siloAssist.onCycleSettings,
                false, true, false, true)
            if eventId ~= nil then
                g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_SA_SETTINGS"))
                g_inputBinding:setActionEventTextVisibility(eventId, true)
                g_inputBinding:setActionEventActive(eventId, true)
            end
        end

        if InputAction.SA_HUD_TOGGLE ~= nil then
            local _, eventId = g_inputBinding:registerActionEvent(
                InputAction.SA_HUD_TOGGLE, siloAssist, siloAssist.onToggleHud,
                false, true, false, true)
            if eventId ~= nil then
                g_inputBinding:setActionEventText(eventId, g_i18n:getText("input_SA_HUD_TOGGLE"))
                g_inputBinding:setActionEventTextVisibility(eventId, true)
                g_inputBinding:setActionEventActive(eventId, true)
            end
        end
    end

    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents, registerSiloAssistActions)
    self.playerInputHooked = true
end

function siloAssist:uninstallPlayerInputHook()
    if not self.playerInputHooked then
        return
    end
    pcall(function()
        g_inputBinding:removeActionEventsByTarget(siloAssist)
    end)
    self.playerInputHooked = false
end

---------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------
function siloAssist.onToggleAssist()
    siloAssist:toggleAssist()
end

function siloAssist.onCycleSettings()
    siloAssist:cycleSettings()
end

function siloAssist.onToggleHud()
    siloAssist:toggleHud()
end

---------------------------------------------------------------------
-- Console reload
---------------------------------------------------------------------
function siloAssist:consoleReloadScripts()
    print("[SiloAssist] Reloading scripts...")
    siloAssist:deactivate()
    siloAssistHeightController.uninstallHooks()

    for _, scriptPath in ipairs(siloAssist.SCRIPT_FILES) do
        local fullPath = siloAssist.modDirectory .. scriptPath
        if fileExists(fullPath) then
            source(fullPath)
            print("[SiloAssist] Loaded: " .. scriptPath)
        else
            print("[SiloAssist] WARNING: Script not found: " .. fullPath)
        end
    end

    siloAssistHeightController.installHooks()
    print("[SiloAssist] Reload complete. Activate again with Ctrl+L.")
end

function siloAssist:consoleToggleDebug()
    siloAssistDebug.toggle()
end

addModEventListener(siloAssist)