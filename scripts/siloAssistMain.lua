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
siloAssistState.wheelSlipDetected = false
siloAssistState.stuckRaiseTimer = 0
siloAssistState.stuckHeightAdd = 0
siloAssistState.stuckReleaseTimer = 0

siloAssist.SCRIPT_FILES = {
    "scripts/core/siloAssistEquipmentConfig.lua",
    "scripts/core/siloAssistConfig.lua",
    "scripts/core/siloAssistDebug.lua",
    "scripts/core/siloAssistVehicleState.lua",
    "scripts/core/siloAssistToolDetection.lua",
    "scripts/core/siloAssistTopoMap.lua",
    "scripts/core/siloAssistSiloDetector.lua",
    "scripts/controller/siloAssistTiltController.lua",
    "scripts/controller/siloAssistCompactorController.lua",
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

    siloAssistEquipmentConfig.loadFromModDesc()

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
    siloAssistEquipmentConfig.reset()

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
        siloAssistState.stuckReleaseTimer = 0
        siloAssistState.isStuck = false
        siloAssistState.wheelSlipDetected = false
        return false
    end

    local speed = vehicle:getLastSpeed()
    local shouldRaiseBlade = (siloAssistToolDetection.isFrontAttached == siloAssistState.isReversing)

    -- WheelSlip detection: count wheels with slipRatio > 0.5
    local slipCount = 0
    local totalWheels = 0
    local specWheels = vehicle.spec_wheels
    if specWheels ~= nil and specWheels.wheels ~= nil then
        for _, wheel in ipairs(specWheels.wheels) do
            totalWheels = totalWheels + 1
            if wheel.slipRatio ~= nil and math.abs(wheel.slipRatio) > siloAssistConfig.STUCK_WHEELSLIP_RATIO then
                slipCount = slipCount + 1
            end
        end
    end
    siloAssistState.wheelSlipDetected = slipCount >= siloAssistConfig.STUCK_MIN_WHEELS

    -- Stuck condition: speed < 3 km/h AND >= MIN_WHEELS wheels slipping for 0.3s while pushing
    local isSlow = speed < siloAssistConfig.STUCK_SPEED_THRESHOLD
    if isSlow and siloAssistState.wheelSlipDetected and not shouldRaiseBlade then
        siloAssistState.stuckTimer = siloAssistState.stuckTimer + dt
        siloAssistState.stuckReleaseTimer = 0
        if siloAssistState.stuckTimer >= siloAssistConfig.STUCK_TIME_THRESHOLD * 1000 then
            if not siloAssistState.isStuck then
                siloAssistDebug.log("Stuck", string.format(
                    "STUCK detected: %d/%d wheels slipping timer=%.0fms",
                    slipCount, totalWheels, siloAssistState.stuckTimer))
            end
            siloAssistState.isStuck = true
            return true
        end
    else
        siloAssistState.stuckTimer = 0
        if siloAssistState.isStuck then
            siloAssistState.stuckReleaseTimer = siloAssistState.stuckReleaseTimer + dt
            if siloAssistState.stuckReleaseTimer >= siloAssistConfig.STUCK_RELEASE_MS then
                siloAssistDebug.log("Stuck", "Unstuck: wheelSlip cleared")
                siloAssistState.isStuck = false
                siloAssistState.stuckReleaseTimer = 0
            end
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
            siloAssistState.stuckRaiseTimer = 0
            siloAssistState.stuckHeightAdd = 0
            siloAssistState.stuckReleaseTimer = 0
            siloAssistState.isReversing = false
            siloAssistState.wasReversing = false
            siloAssistState.wasInSilo = false
            siloAssistSiloDetector.reset()
            siloAssistToolDetection.reset()
            siloAssistHeightController.reset()
            siloAssistTiltController.reset()
            siloAssistCompactorController.reset()
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

    -- Push mode: trigger full silo rescan on direction change (rev>3km/h -> fwd>3km/h)
    if siloAssistVehicleState.getSiloMode() == "push" and justStoppedReversing then
        local speed = vehicle:getLastSpeed()
        if speed > 3.0 then
            siloAssistHeightController.pushNeedRescan = true
            siloAssistDebug.log("Main", "push: rescan triggered (rev->fwd, speed=" .. string.format("%.1f", speed) .. ")")
        end
    end

    siloAssist.checkStuck(vehicle, dt)

    siloAssistDebug.logThrottled("Main", "state", string.format(
        "state=%s rev=%s stuck=%s slip=%s speed=%.1f raiseTimer=%d",
        state,
        tostring(siloAssistState.isReversing),
        tostring(siloAssistState.isStuck),
        tostring(siloAssistState.wheelSlipDetected),
        vehicle:getLastSpeed(),
        siloAssistState.stuckRaiseTimer
    ))

    siloAssistSiloDetector.update(vehicle, dt)

    -- Long-range sampling (always, no speed check)
    siloAssistHeightController.sampleLongRange(vehicle)

    -- Exit sensor: detects when blade approaches silo exit
    siloAssistHeightController.sampleExitSensor(vehicle)

    -- Silo end sensor: checks if point ahead is still inside silo area (walls)
    siloAssistHeightController.sampleSiloEndSensor(vehicle)

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
                opts.wedgeHeight = siloAssistConfig.WEDGE_MIN_END_HEIGHT
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

    local inSilo = siloAssistSiloDetector.isInSilo
    local fillAhead = siloAssistHeightController.longRangeFillDetected
    local exitRampActive = siloAssistHeightController.exitRampActive
    local exitFillDetected = siloAssistHeightController.exitSensorFillDetected
    local siloEndInside = siloAssistHeightController.siloEndInside
    local mode = siloAssistVehicleState.getSiloMode()
    local config = siloAssistConfig

    -- Exit ramp trigger: start when silo end sensor detects point outside silo area
    -- All modes use the silo wall sensor (not fill level) for reliable exit detection
    local exitTrigger = not siloEndInside

    -- Exit ramp: stepped height offset + tilt increase.
    -- Steps at 0m (+10cm, 10° tilt), 2m (+20cm, 20° tilt), 4m (+30cm, 30° tilt).
    -- Wedge mode uses base tilt (5°) instead of stepped tilt.
    -- Normal height controller runs throughout — only offset is added.
    if exitRampActive or (inSilo and exitTrigger) then
        if not exitRampActive then
            local hc = siloAssistHeightController
            hc.exitRampActive = true
            hc.exitRampProgress = 0
            siloAssistDebug.log("Main", string.format(
                "Exit ramp START: exitFill=%s siloEnd=%s mode=%s",
                tostring(exitFillDetected), tostring(siloEndInside), mode))
        end
        local hc = siloAssistHeightController
        local speedMs = math.max(vehicle:getLastSpeed() / 3.6, 0.1)
        hc.exitRampProgress = hc.exitRampProgress + speedMs * dt / 1000

        -- Determine current step based on distance traveled
        local steps = config.EXIT_RAMP_STEPS
        local heightAdd = 0
        local tiltDeg = siloAssistTiltController.getBaseTiltDeg()
        for i = #steps, 1, -1 do
            if hc.exitRampProgress >= steps[i].dist then
                heightAdd = steps[i].heightAdd
                tiltDeg = steps[i].tiltDeg
                break
            end
        end
        hc.exitRampHeightAdd = heightAdd
        siloAssistTiltController.forceTilt(vehicle, tiltDeg)

        siloAssistDebug.logThrottled("Main", "exitRamp", string.format(
            "prog=%.2fm heightAdd=+%.2fm tilt=%.0f° mode=%s ctrl=%s",
            hc.exitRampProgress, heightAdd, tiltDeg,
            mode, tostring(siloAssistToolDetection.controlType)))
    elseif not inSilo and fillAhead then
        siloAssistTiltController.forceTilt(vehicle, 0)
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampHeightAdd = 0
        end
    else
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampHeightAdd = 0
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

    -- Compactor controller runs BEFORE shouldRaiseBlade so it stays lowered
    -- inside the silo even when the blade raises on reverse.
    if siloAssistToolDetection.compactorTool ~= nil then
        siloAssistCompactorController.update(vehicle)
    end

    local shouldRaiseBlade = (siloAssistToolDetection.isFrontAttached == siloAssistState.isReversing)
    if shouldRaiseBlade and siloAssistToolDetection.toolType ~= "shovel" then
        if siloAssistHeightController.exitRampActive then
            siloAssistHeightController.exitRampActive = false
            siloAssistHeightController.exitRampProgress = 0
            siloAssistHeightController.exitRampHeightAdd = 0
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

    -- Compactor-only mode: skip height/tilt/surface/exit-ramp
    -- (when primary tool IS the compactor — backward compat for compactor-only vehicles)
    if siloAssistToolDetection.toolType == "compactor" then
        siloAssistHud:updateStatusText(dt)
        return
    end

    if state == siloAssistConfig.STATE_WAITING then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Entered silo -> ACTIVE")
        -- Push mode: initial full silo scan on entry
        if siloAssistVehicleState.getSiloMode() == "push" and silo ~= nil then
            siloAssistHeightController.scanFullSilo(silo, siloAssistSiloDetector.currentSiloArea)
        end
    end

    local silo = siloAssistSiloDetector.currentSilo
    local progress = siloAssistSiloDetector.progress
    local entryProgress = siloAssistSiloDetector.entryProgress

    if siloAssistToolDetection.toolType == "shovel" and siloAssistState.isReversing then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_DUMPING)
        siloAssistDebug.logThrottled("Main", "dumping", "Shovel reversing -> DUMPING")
    elseif state == siloAssistConfig.STATE_DUMPING and not siloAssistState.isReversing then
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        siloAssistDebug.log("Main", "Dumping -> ACTIVE (forward)")
    end

    if siloAssistState.isStuck then
        if state ~= siloAssistConfig.STATE_RAISING then
            siloAssistVehicleState.setState(siloAssistConfig.STATE_RAISING)
            siloAssistState.stuckRaiseTimer = 0
            siloAssistState.stuckHeightAdd = config.STUCK_HEIGHT_ADD
            siloAssistDebug.log("Main", string.format("STUCK -> RAISING: stuckHeightAdd=%.2fm", config.STUCK_HEIGHT_ADD))
        end
        siloAssistTiltController.forceTilt(vehicle, siloAssistConfig.TILT_MAX)
    elseif state == siloAssistConfig.STATE_RAISING then
        siloAssistState.stuckRaiseTimer = siloAssistState.stuckRaiseTimer + dt
        local minRaiseTime = siloAssistConfig.STUCK_RAISE_MIN_MS
        if not siloAssistState.isStuck and siloAssistState.stuckRaiseTimer >= minRaiseTime then
            siloAssistState.stuckHeightAdd = 0
            siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
            siloAssistDebug.log("Main", string.format(
                "Unstuck -> ACTIVE (raiseTimer=%dms >= %dms, stuckHeightAdd=0)",
                siloAssistState.stuckRaiseTimer, minRaiseTime))
        end
    end

    local fillHeight = siloAssistSiloDetector.stagedFillHeight
    local speed = vehicle:getLastSpeed()

    siloAssistHeightController.sampleVehicleGroundHeights(vehicle)

    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local rampStart = math.min(siloAssistConfig.ENTRY_RAMP_METERS / siloLength, 0.5)
    local inEntryRamp = progress < rampStart

    if speed >= siloAssistConfig.MIN_SPEED_FOR_CONTROL or inEntryRamp then
        -- Push mode: perform rescan if flagged
        if siloAssistHeightController.pushNeedRescan and silo ~= nil then
            siloAssistHeightController.scanFullSilo(silo, siloAssistSiloDetector.currentSiloArea)
        end
        -- Height controller always runs now — exit ramp adds offset via exitRampHeightAdd
        siloAssistHeightController.update(vehicle, silo, progress, siloAssistSiloDetector.bladeEntryProgress, fillHeight, dt)
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
        "CL1=%s CM1=%s CR1=%s | CL3=%s CM3=%s CR3=%s | CL5=%s CM5=%s CR5=%s | CL8=%s CM8=%s CR8=%s | CL10=%s CM10=%s CR10=%s | Silo=%s | Med=%s Koll=%s | Vo=%s Hi=%s Nick=%s | Speed=%.1f",
        cf("leftFill",1), cf("midFill",1), cf("rightFill",1),
        cf("leftFill",2), cf("midFill",2), cf("rightFill",2),
        cf("leftFill",3), cf("midFill",3), cf("rightFill",3),
        cf("leftFill",4), cf("midFill",4), cf("rightFill",4),
        cf("leftFill",5), cf("midFill",5), cf("rightFill",5),
        n(hc.siloSensorFillHeight),
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
        siloAssistHud:drawPushScan()
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
                    opts.wedgeHeight = siloAssistConfig.WEDGE_MIN_END_HEIGHT
                end
                siloAssistTopoMap.computeTargetTopography(mode, opts)
                siloAssistDebug.log("Activate", "TopoMap initialized (already in silo)")
            end
        end
        siloAssistDebug.log("Activate", "In silo, entering ACTIVE")
        siloAssistVehicleState.setState(siloAssistConfig.STATE_ACTIVE)
        -- Push mode: initial full silo scan if already in silo at activation
        if siloAssistVehicleState.getSiloMode() == "push" then
            siloAssistHeightController.scanFullSilo(
                siloAssistSiloDetector.currentSilo, siloAssistSiloDetector.currentSiloArea)
        end
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
    if vehicle ~= nil and siloAssistToolDetection.compactorTool ~= nil then
        if siloAssistCompactorController._controlPath == nil and siloAssistToolDetection.compactorControlPath == nil then
            siloAssistCompactorController.detectControlPath(vehicle)
        end
        siloAssistCompactorController.raiseImplement(vehicle)
    end
    siloAssistVehicleState.setState(siloAssistConfig.STATE_OFF)
    siloAssistHeightController.reset()
    siloAssistTiltController.reset()
    siloAssistCompactorController.reset()
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
            opts.wedgeHeight = siloAssistConfig.WEDGE_MIN_END_HEIGHT
        end
        siloAssistTopoMap.computeTargetTopography(mode, opts)
    end

    -- If switching to push mode and in silo, trigger full silo scan
    if mode == "push" and siloAssistSiloDetector.isInSilo and siloAssistSiloDetector.currentSilo ~= nil then
        siloAssistHeightController.scanFullSilo(
            siloAssistSiloDetector.currentSilo, siloAssistSiloDetector.currentSiloArea)
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

    siloAssistEquipmentConfig.loadFromModDesc()

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