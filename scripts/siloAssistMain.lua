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
siloAssistState.isReversing = false
siloAssistState.wasReversing = false
siloAssistState.wasInSilo = false

siloAssist.SCRIPT_FILES = {
    "scripts/core/siloAssistConfig.lua",
    "scripts/core/siloAssistDebug.lua",
    "scripts/core/siloAssistVehicleState.lua",
    "scripts/core/siloAssistToolDetection.lua",
    "scripts/core/siloAssistTopoMap.lua",
    "scripts/core/siloAssistSiloDetector.lua",
    "scripts/controller/siloAssistTiltController.lua",
    "scripts/hooks/siloAssistHeightController.lua",
    "scripts/hooks/siloAssistDumpController.lua",
    "scripts/hud/siloAssistDrawing.lua",
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
    if siloAssistDrawing and siloAssistDrawing.load then
        siloAssistDrawing.load()
    end
    addConsoleCommand("reloadSiloAssist", "Reload SiloAssist scripts", "consoleReloadScripts", siloAssist)
    addConsoleCommand("siloAssistDebug", "Toggle SiloAssist debug logging", "consoleToggleDebug", siloAssist)

    siloAssistVehicleState.loadFromXML()

    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, siloAssist.onSaveGame)

    print("[SiloAssist] loadMap: calling siloAssistModPanel.register()")
    siloAssistModPanel.register()
end

function siloAssist:deleteMap()
    siloAssistVehicleState.saveToXML()

    if siloAssistDrawing and siloAssistDrawing.unload then
        siloAssistDrawing.unload()
    end
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
    if vehicle == nil or not vehicle:getIsMotorStarted() then
        siloAssistState.stuckTimer = 0
        siloAssistState.isStuck = false
        return false
    end

    local speed = vehicle:getLastSpeed()
    local shouldRaiseBlade = (siloAssistToolDetection.isFrontAttached == siloAssistState.isReversing)

    if speed < siloAssistConfig.STUCK_SPEED_THRESHOLD and not shouldRaiseBlade then
        siloAssistState.stuckTimer = siloAssistState.stuckTimer + dt
        if siloAssistState.stuckTimer >= siloAssistConfig.STUCK_TIME_THRESHOLD * 1000 then
            if not siloAssistState.isStuck then
                siloAssistDebug.log("Stuck", string.format("STUCK detected: speed=%.1f timer=%dms", speed, siloAssistState.stuckTimer))
            end
            siloAssistState.isStuck = true
            return true
        end
    else
        if siloAssistState.isStuck then
            siloAssistDebug.log("Stuck", string.format("Unstuck: speed=%.1f", speed))
        end
        siloAssistState.stuckTimer = 0
        siloAssistState.isStuck = false
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
            siloAssistState.isReversing = false
            siloAssistState.wasReversing = false
            siloAssistState.wasInSilo = false
            siloAssistSiloDetector.reset()
            siloAssistToolDetection.reset()
            siloAssistHeightController.reset()
            siloAssistTiltController.reset()
            siloAssistDumpController.reset()
            siloAssistTopoMap.reset()
            siloAssist._topoRetriggerTimer = nil
            siloAssist._topoLastCoverage = nil
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
    local justStoppedReversing = not siloAssistState.isReversing and siloAssistState.wasReversing
    siloAssistState.wasReversing = siloAssistState.isReversing

    siloAssist.checkStuck(vehicle, dt)

    siloAssistDebug.logThrottled("Main", "state", string.format(
        "state=%s rev=%s stuck=%s speed=%.1f",
        state,
        tostring(siloAssistState.isReversing),
        tostring(siloAssistState.isStuck),
        vehicle:getLastSpeed()
    ))

    siloAssistSiloDetector.update(vehicle, dt)

    -- Long-range sampling (always, no speed check)
    siloAssistHeightController.sampleLongRange(vehicle)

    -- Surface sampling (always, before early-return blocks like exit ramp)
    siloAssistHeightController.sampleSurfaceAhead(vehicle)

    -- TopoMap: feed surface samples into persistent grid (Phase 1: logging only)
    siloAssistTopoMap.updateFromSamples(
        siloAssistHeightController.surfaceSamples,
        siloAssistHeightController.surfaceSampleHeights,
        siloAssistHeightController.collisionSamples,
        siloAssistHeightController.collisionSampleHeights
    )
    if siloAssistTopoMap.rows > 0 then
        siloAssistTopoMap.computeStats()
        siloAssistTopoMap.updateDoneState(dt)

        -- Periodically recompute target topography as more cells get filled.
        -- Throttled: only when coverage increased by >= 5% or every 2s.
        siloAssist._topoRetriggerTimer = (siloAssist._topoRetriggerTimer or 0) + dt
        local coverage = siloAssistTopoMap.lastStats.coveragePct or 0
        local coverageIncreased = coverage - (siloAssist._topoLastCoverage or 0) >= 5
        local timeout = siloAssist._topoRetriggerTimer >= 2000
        if coverageIncreased or timeout then
            local mode = siloAssistVehicleState.getSiloMode()
            local offset = siloAssistVehicleState.getHeightOffset()
            local opts = { offset = offset }
            if mode == "wedge" then
                opts.wedgeHeight = siloAssistConfig.WEDGE_HEIGHT_M
            end
            siloAssistTopoMap.computeTargetTopography(mode, opts)
            siloAssist._topoLastCoverage = coverage
            siloAssist._topoRetriggerTimer = 0
        end
    end

    -- Blade ground distance for profile line (always, before early returns)
    local bladeGroundDist = siloAssistHeightController.getDistanceFromGround(
        vehicle, siloAssistToolDetection.toolObject, siloAssistToolDetection.bladeNode)
    if bladeGroundDist ~= nil then
        siloAssistHeightController.lastRaycastGroundDistance = bladeGroundDist
    end

    -- Entry/exit tilt control (before normal tilt update)
    local inSilo = siloAssistSiloDetector.isInSilo
    local fillAhead = siloAssistHeightController.longRangeFillDetected
    local exitRampActive = siloAssistHeightController.exitRampActive

    local siloProgress = siloAssistSiloDetector.progress or 0
    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local config = siloAssistConfig
    local rampEnd = math.max(1 - math.min(config.EXIT_RAMP_METERS / siloLength, 0.5), 0.5)

    -- Exit ramp length (meters), capped to EXIT_RAMP_METERS_MAX as safety
    local exitRampMeters = math.min(
        config.EXIT_RAMP_METERS,
        config.EXIT_RAMP_METERS_MAX or config.EXIT_RAMP_METERS)

    if exitRampActive or (inSilo and not fillAhead and siloProgress > rampEnd) then
        if not exitRampActive then
            local hc = siloAssistHeightController
            -- Snapshot: freeze blade height at start of ramp.
            -- Prefer last computed target, fall back to measured blade distance.
            local startH = hc.lastTargetHeightAboveGround
            if startH == nil then
                startH = hc.lastRaycastGroundDistance or 0
            end
            hc.exitRampActive = true
            hc.exitRampProgress = 0
            hc.exitRampStartHeight = startH
            hc.exitRampEffectiveMeters = exitRampMeters
            siloAssistDebug.log("Main", string.format(
                "Exit ramp START: prog=%.3f frozenHeight=%.3fm rampLen=%.1fm",
                siloProgress, startH, exitRampMeters))
        end
        local hc = siloAssistHeightController
        local speedMs = math.max(vehicle:getLastSpeed() / 3.6, 0.1)
        hc.exitRampProgress = hc.exitRampProgress + speedMs * dt / 1000
        local rampLen = hc.exitRampEffectiveMeters or exitRampMeters
        local rampProg = math.min(hc.exitRampProgress / rampLen, 1)
        local exitTiltDeg = config.SHIELD_TILT_DEG + (config.EXIT_RAMP_TILT_MAX_DEG - config.SHIELD_TILT_DEG) * rampProg
        siloAssistTiltController.forceTilt(vehicle, exitTiltDeg)
        siloAssistDebug.logThrottled("Main", "exitRampTilt", string.format(
            "prog=%.3f tilt=%.1f° frozenH=%.3f", rampProg, exitTiltDeg,
            hc.exitRampStartHeight or -1))
    elseif not inSilo and fillAhead then
        siloAssistTiltController.forceTilt(vehicle, 0)
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampStartHeight = nil
            siloAssistHeightController.exitRampEffectiveMeters = nil
        end
    else
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampStartHeight = nil
            siloAssistHeightController.exitRampEffectiveMeters = nil
        end
        if siloAssistTiltController.forceTiltActive then
            siloAssistTiltController.clearForceTilt()
        end
    end

    -- Tilt control: always active when assist is on and tool detected.
    if siloAssistToolDetection.controlType ~= nil then
        local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
        local zx, zy, zz = localToWorld(vehicle.rootNode, 0, 0, 1)
        local vehiclePitch, _ = MathUtil.directionToPitchYaw(zx - vx, zy - vy, zz - vz)
        siloAssistHeightController.vehiclePitchDeg = math.deg(vehiclePitch)
        siloAssistTiltController.update(vehicle, dt)
    end

    local justLeftSilo = siloAssistState.wasInSilo and not siloAssistSiloDetector.isInSilo

    local shouldRaiseBlade = (siloAssistToolDetection.isFrontAttached == siloAssistState.isReversing)
    if shouldRaiseBlade and siloAssistToolDetection.toolType ~= "shovel" then
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampStartHeight = nil
            siloAssistHeightController.exitRampEffectiveMeters = nil
        end
        if siloAssistTiltController.forceTiltActive then
            siloAssistTiltController.clearForceTilt()
        end
        local justShouldRaise = siloAssistToolDetection.isFrontAttached and justStartedReversing or justStoppedReversing
        if justShouldRaise then
            siloAssistDebug.log("Main", "shouldRaiseBlade -> raiseBlade (isFront=" .. tostring(siloAssistToolDetection.isFrontAttached) .. " rev=" .. tostring(siloAssistState.isReversing) .. ")")
            siloAssistHeightController.raiseBlade(vehicle)
        end
        siloAssistHeightController.lastTargetHeightAboveGround = nil
        siloAssistHud:updateStatusText(dt)
        siloAssistState.wasInSilo = false
        return
    end

    -- ENTRY: not in silo, fill ahead -> blade to ground early
    if not siloAssistSiloDetector.isInSilo and siloAssistHeightController.longRangeFillDetected then
        local entryExitH = math.max(siloAssistVehicleState.getHeightOffset(), 0)
        siloAssistHeightController.applyEntryExitHeight(vehicle, entryExitH)
        siloAssistHeightController.lastTargetHeightAboveGround = entryExitH
        local lrPos = siloAssistHeightController.longRangeWorldPos
        if lrPos ~= nil and siloAssistSiloDetector.currentSilo == nil then
            siloAssistSiloDetector.prefetchSiloData(lrPos[1], lrPos[2], lrPos[3])
        end
        if siloAssistVehicleState.getState() ~= siloAssistConfig.STATE_OFF then
            siloAssistVehicleState.setState(siloAssistConfig.STATE_WAITING)
        end
        siloAssistState.wasInSilo = false
        siloAssistHud:updateStatusText(dt)
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
            siloAssistHeightController.applyPreEntry(vehicle, distToEdge)
        end

        -- Fully outside + no LR fill: blade up
        if not fillAhead and not isNear and siloAssistToolDetection.controlType ~= nil then
            siloAssistHeightController.raiseBlade(vehicle)
        end

        siloAssistHeightController.lastTargetHeightAboveGround = nil

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
        if siloAssistToolDetection.controlType == "attacherJointControl" then
            local spec = siloAssistToolDetection.toolObject.spec_attacherJointControl
            if spec ~= nil and spec.jointDesc ~= nil then
                spec.heightTargetAlpha = spec.jointDesc.upperAlpha
                spec.heightController.moveAlphaLastManual = spec.jointDesc.upperAlpha
            end
        elseif siloAssistToolDetection.controlType == "cylindered" then
            Cylindered.actionEventInput(
                siloAssistToolDetection.cylinderedVehicle or vehicle, "",
                -1.0, siloAssistToolDetection.armToolIndex, true)
        end
        siloAssistTiltController.fullRetractTilt()
    elseif state == siloAssistConfig.STATE_RAISING and not siloAssistState.isStuck then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Unstuck -> ACTIVE")
    end

    local fillHeight = siloAssistSiloDetector.stagedFillHeight
    local speed = vehicle:getLastSpeed()

    siloAssistHeightController.sampleVehicleGroundHeights(vehicle)

    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local rampStart = math.min(siloAssistConfig.ENTRY_RAMP_METERS / siloLength, 0.5)
    local inEntryRamp = progress < rampStart

    if speed >= siloAssistConfig.MIN_SPEED_FOR_CONTROL or inEntryRamp then
        siloAssistHeightController.update(vehicle, silo, progress, fillHeight, dt)
    elseif siloAssistDebug.showDebug then
        siloAssistDebug.logThrottled("Main", "slow", string.format(
            "Speed %.1f < MIN_SPEED %.1f: skipping height control",
            speed, siloAssistConfig.MIN_SPEED_FOR_CONTROL
        ))
    end

    if siloAssistToolDetection.toolType == "shovel" then
        siloAssistDumpController.update(vehicle, silo, progress, dt)
    end

    siloAssistHud:updateStatusText(dt)

    -- Throttled debug dump (~1x per 200ms when debug on)
    local hc = siloAssistHeightController
    local sd = siloAssistSiloDetector
    local st = siloAssistState
    local function n(v, fallback) return (v ~= nil and type(v) == "number") and string.format("%.2f", v) or (fallback or "nn") end
    local ch = hc.collisionSampleHeights
    local function cf(side, i)
        if ch and ch[i] and ch[i][side] ~= nil then return string.format("%.2f", ch[i][side]) end
        return "nn"
    end
    siloAssistDebug.logThrottled("Main", "debugHud", string.format(
        "CL1=%s CL2=%s CL3=%s CL4=%s CL5=%s | CR1=%s CR2=%s CR3=%s CR4=%s CR5=%s | Med=%s Koll=%s | Vo=%s Hi=%s Nick=%s | Speed=%.1f",
        cf("leftFill",1), cf("leftFill",2), cf("leftFill",3), cf("leftFill",4), cf("leftFill",5),
        cf("rightFill",1), cf("rightFill",2), cf("rightFill",3), cf("rightFill",4), cf("rightFill",5),
        n(hc.lastSurfaceTarget),
        n(hc.lastRaycastGroundDistance),
        n(hc.vehicleFrontGroundHeight), n(hc.vehicleRearGroundHeight),
        n(hc.vehiclePitchDeg, "0.0"),
        sd.vehicleSpeed or 0
    ))

    siloAssistModPanel.update()
end

---------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------
function siloAssist:draw()
    if siloAssistDrawing and siloAssistDrawing.reset then
        siloAssistDrawing.reset()
    end

    if siloAssistDebug.showLines then
        siloAssistHud:drawSurfaceSamples()
        siloAssistHud:drawTopoMap()
    end

    if siloAssistDrawing and siloAssistDrawing.draw then
        siloAssistDrawing.draw()
    end

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

    -- Wenn bereits im Silo: TopoMap sofort initialisieren (falls noch nicht geschehen)
    if siloAssistSiloDetector.isInSilo and siloAssistSiloDetector.currentSilo ~= nil then
        if siloAssistTopoMap.siloRef ~= siloAssistSiloDetector.currentSilo then
            local area = siloAssistSiloDetector.currentSiloArea
            if area ~= nil then
                siloAssistTopoMap.init(siloAssistSiloDetector.currentSilo, area, siloAssistConfig.TOPO_MAP_CELL_SIZE)
                siloAssistTopoMap.sampleCoarseGrid(siloAssistConfig.TOPO_MAP_COARSE_STEP)
                siloAssistTopoMap.computeStats()
                local mode = siloAssistVehicleState.getSiloMode()
                local offset = siloAssistVehicleState.getHeightOffset()
                local opts = { offset = offset }
                if mode == "wedge" then
                    opts.wedgeHeight = siloAssistConfig.WEDGE_HEIGHT_M
                end
                siloAssistTopoMap.computeTargetTopography(mode, opts)
                siloAssistDebug.log("Activate", "TopoMap initialized (already in silo)")
            end
        end
        siloAssistDebug.log("Activate", "In silo, entering ACTIVE")
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
    else
        -- Nicht im Silo: prüfen ob nah dran, sonst WAITING (LR-Punkt wird in update loop erfasst)
        local isNear, _ = siloAssistSiloDetector.isNearSilo(vehicle, siloAssistConfig.PRE_ENTRY_DISTANCE)
        if not isNear then
            siloAssistDebug.log("Activate", "Not near silo, entering WAITING")
            siloAssistHud.showStatusText(g_i18n:getText("sa_notInSilo"))
            siloAssistVehicleState.setState(siloAssistConfig.STATE_WAITING)
            return
        end
        siloAssistDebug.log("Activate", "Near silo, entering WAITING (LR detection will trigger)")
        siloAssistVehicleState.setState(siloAssistConfig.STATE_WAITING)
        return
    end

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
    siloAssistTopoMap.reset()
    siloAssist._topoRetriggerTimer = nil
    siloAssist._topoLastCoverage = nil
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

    -- Recompute target topography with new mode
    if siloAssistTopoMap.rows > 0 then
        local mode = siloAssistVehicleState.getSiloMode()
        local offset = siloAssistVehicleState.getHeightOffset()
        local opts = { offset = offset }
        if mode == "wedge" then
            opts.wedgeHeight = siloAssistConfig.WEDGE_HEIGHT_M
        end
        siloAssistTopoMap.computeTargetTopography(mode, opts)
    end
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
    if siloAssistDrawing and siloAssistDrawing.unload then
        siloAssistDrawing.unload()
    end

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
    if siloAssistDrawing and siloAssistDrawing.load then
        siloAssistDrawing.load()
    end
    print("[SiloAssist] Reload complete. Activate again with Ctrl+L.")
end

function siloAssist:consoleToggleDebug()
    siloAssistDebug.toggleLog()
end

addModEventListener(siloAssist)