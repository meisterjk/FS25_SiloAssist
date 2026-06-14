--====================================================================
-- SiloAssist - Height Controller
-- Responsibility: calculate target height, measure actual height,
-- apply height corrections to AttacherJointControl or Cylindered.
-- Tilt control is in siloAssistTiltController.lua.
-- Tool detection is in siloAssistToolDetection.lua.
-- Stuck detection is in siloAssistMain.lua (siloAssistState).
--====================================================================

siloAssistHeightController = {}

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
siloAssistHeightController.wedgePassCount = 0
siloAssistHeightController.wasAtSiloEnd = false
siloAssistHeightController.lastProgress = 0

siloAssistHeightController.currentTargetAlpha = nil

siloAssistHeightController.hookInstalled = false
siloAssistHeightController.originalActionEventAttacherJointControl = nil
siloAssistHeightController.originalGetIsAttacherJointControlDampingAllowed = nil

-- Raycast
siloAssistHeightController.RAYCAST_MAX_DISTANCE = 10
siloAssistHeightController.RAYCAST_COLLISION_FLAGS = CollisionFlag.TERRAIN + CollisionFlag.STATIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT
siloAssistHeightController.lastRaycastGroundDistance = nil

-- Debug / HUD display values
siloAssistHeightController.lastPitchDeg = nil
siloAssistHeightController.lastTargetHeightAboveGround = nil
siloAssistHeightController.lastHeightDiff = 0
siloAssistHeightController.lastAlphaDirection = 0
siloAssistHeightController.vehiclePitchDeg = 0
siloAssistHeightController.lastEffectiveRampStart = 0
siloAssistHeightController.lastEffectiveRampEnd = 0

-- Surface sampling
siloAssistHeightController.surfaceSamples = {}  -- {x,y,z} world positions for debug viz
siloAssistHeightController.lastSurfaceTarget = nil

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistHeightController.reset()
    siloAssistHeightController.currentTargetAlpha = nil
    siloAssistHeightController.wedgePassCount = 0
    siloAssistHeightController.wasAtSiloEnd = false
    siloAssistHeightController.lastProgress = 0
    siloAssistHeightController.lastRaycastGroundDistance = nil
    siloAssistHeightController.lastPitchDeg = nil
    siloAssistHeightController.lastTargetHeightAboveGround = nil
    siloAssistHeightController.lastHeightDiff = 0
    siloAssistHeightController.lastAlphaDirection = 0
    siloAssistHeightController.vehiclePitchDeg = 0
    siloAssistHeightController.lastEffectiveRampStart = 0
    siloAssistHeightController.lastEffectiveRampEnd = 0
    siloAssistHeightController.surfaceSamples = {}
    siloAssistHeightController.lastSurfaceTarget = nil
end

---------------------------------------------------------------------
-- AttacherJointControl hook
---------------------------------------------------------------------
function siloAssistHeightController.installHooks()
    if siloAssistHeightController.hookInstalled then
        return
    end

    if AttacherJointControl ~= nil and AttacherJointControl.actionEventAttacherJointControl ~= nil then
        siloAssistHeightController.originalActionEventAttacherJointControl = AttacherJointControl.actionEventAttacherJointControl
        AttacherJointControl.actionEventAttacherJointControl = Utils.overwrittenFunction(
            AttacherJointControl.actionEventAttacherJointControl,
            siloAssistHeightController.actionEventAttacherJointControlHook)
    end

    if Leveler ~= nil and Leveler.getIsAttacherJointControlDampingAllowed ~= nil then
        siloAssistHeightController.originalGetIsAttacherJointControlDampingAllowed = Leveler.getIsAttacherJointControlDampingAllowed
        Leveler.getIsAttacherJointControlDampingAllowed = Utils.overwrittenFunction(
            Leveler.getIsAttacherJointControlDampingAllowed,
            siloAssistHeightController.getIsDampingAllowedHook)
    end

    siloAssistHeightController.hookInstalled = true
end

function siloAssistHeightController.uninstallHooks()
    if not siloAssistHeightController.hookInstalled then
        return
    end

    if siloAssistHeightController.originalActionEventAttacherJointControl ~= nil then
        AttacherJointControl.actionEventAttacherJointControl = siloAssistHeightController.originalActionEventAttacherJointControl
        siloAssistHeightController.originalActionEventAttacherJointControl = nil
    end

    if siloAssistHeightController.originalGetIsAttacherJointControlDampingAllowed ~= nil then
        Leveler.getIsAttacherJointControlDampingAllowed = siloAssistHeightController.originalGetIsAttacherJointControlDampingAllowed
        siloAssistHeightController.originalGetIsAttacherJointControlDampingAllowed = nil
    end

    siloAssistHeightController.hookInstalled = false
end

function siloAssistHeightController.actionEventAttacherJointControlHook(vehicle, superFunc, ...)
    if siloAssistHeightController.isAssistActive() then
        local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
        if rootVehicle == siloAssist.vehicle then
            return
        end
    end
    if type(superFunc) == "function" then
        superFunc(vehicle, ...)
    end
end

function siloAssistHeightController.isAssistActive()
    return siloAssistVehicleState.getState() == siloAssistConfig.STATE_ACTIVE
        or siloAssistVehicleState.getState() == siloAssistConfig.STATE_DUMPING
        or siloAssistVehicleState.getState() == siloAssistConfig.STATE_RAISING
end

function siloAssistHeightController.getIsDampingAllowedHook(self, superFunc)
    if siloAssistHeightController.isAssistActive() then
        local rootVehicle = self.getRootVehicle ~= nil and self:getRootVehicle() or self
        if rootVehicle == siloAssist.vehicle then
            return false
        end
    end
    if type(superFunc) == "function" then
        return superFunc(self)
    end
    return true
end

---------------------------------------------------------------------
-- Raycast: distance from blade to ground
---------------------------------------------------------------------
function siloAssistHeightController.raycastCallback(self, transformId, _, _, _, distance)
    if self.ignoreNodes ~= nil and self.ignoreNodes[transformId] then
        return true
    end
    self.groundDistance = distance
    return false
end

function siloAssistHeightController.getDistanceFromGround(vehicle, toolObject, bladeNode)
    local node = bladeNode
    if node == nil then
        if toolObject ~= nil and toolObject.rootNode ~= nil then
            node = toolObject.rootNode
        elseif vehicle ~= nil and vehicle.rootNode ~= nil then
            node = vehicle.rootNode
        else
            return nil
        end
    end

    local ignoreNodes = {}
    if vehicle ~= nil and vehicle.vehicleNodes ~= nil then
        for n, _ in pairs(vehicle.vehicleNodes) do
            ignoreNodes[n] = true
        end
    end
    if toolObject ~= nil and toolObject.vehicleNodes ~= nil then
        for n, _ in pairs(toolObject.vehicleNodes) do
            ignoreNodes[n] = true
        end
    end
    local cylVehicle = siloAssistToolDetection.cylinderedVehicle
    if cylVehicle ~= nil and cylVehicle ~= vehicle and cylVehicle.vehicleNodes ~= nil then
        for n, _ in pairs(cylVehicle.vehicleNodes) do
            ignoreNodes[n] = true
        end
    end

    local x, y, z = localToWorld(node, 0, 0, 0.5)

    local params = {
        groundDistance = nil,
        ignoreNodes = ignoreNodes,
        raycastCallback = siloAssistHeightController.raycastCallback
    }

    raycastAll(x, y, z, 0, -1, 0, siloAssistHeightController.RAYCAST_MAX_DISTANCE,
        "raycastCallback", params, siloAssistHeightController.RAYCAST_COLLISION_FLAGS)

    if params.groundDistance == nil then
        raycastAll(x, y, z, 0, 1, 0, siloAssistHeightController.RAYCAST_MAX_DISTANCE,
            "raycastCallback", params, siloAssistHeightController.RAYCAST_COLLISION_FLAGS)
        if params.groundDistance ~= nil then
        params.groundDistance = params.groundDistance * -1
    end
    end

    siloAssistDebug.logThrottled("Height", "raycast", string.format(
        "result=%s bladeNode=%s nodeY=%.3f",
        tostring(params.groundDistance),
        tostring(bladeNode ~= nil),
        y
    ))

    return params.groundDistance
end

---------------------------------------------------------------------
-- Tool pitch (for HUD display)
---------------------------------------------------------------------
function siloAssistHeightController.getToolPitchDegrees(bladeNode, toolObject)
    local node = bladeNode
    if node == nil then
        if toolObject ~= nil and toolObject.rootNode ~= nil then
            node = toolObject.rootNode
        else
            return nil
        end
    end

    local x, y, z = localToWorld(node, 0, 0, 0)
    local zx, zy, zz = localToWorld(node, 0, 0, 1)
    local pitch, _ = MathUtil.directionToPitchYaw(zx - x, zy - y, zz - z)
    return math.deg(pitch)
end

---------------------------------------------------------------------
-- Target height calculation
-- Returns height ABOVE GROUND in meters.
---------------------------------------------------------------------
function siloAssistHeightController.calculateTargetHeight(progress, fillHeight)
    local config = siloAssistConfig
    local siloMode = siloAssistVehicleState.getSiloMode()
    local heightOffset = siloAssistVehicleState.getHeightOffset()

    if siloMode == "driveThrough" then
        return siloAssistHeightController.calcDriveThroughTarget(progress, fillHeight)
    elseif siloMode == "wedge" then
        return siloAssistHeightController.calcWedgeTarget(progress, fillHeight)
    end

    return fillHeight + heightOffset
end

function siloAssistHeightController.calcDriveThroughTarget(progress, fillHeight)
    local config = siloAssistConfig
    local heightOffset = siloAssistVehicleState.getHeightOffset()
    local autoOffset = fillHeight * config.AUTO_FILL_OFFSET_FACTOR
    local effectiveOffset = heightOffset + autoOffset
    local middleHeight = fillHeight + effectiveOffset
    local groundOffset = effectiveOffset

    local fillRatio = math.clamp(fillHeight / config.SILO_MAX_HEIGHT_M, 0, 1)

    local exitPhase = math.clamp(fillRatio / 0.5, 0, 1)
    local rampEnd = config.RAMP_END_PCT + (config.RAMP_MAX_END_PCT - config.RAMP_END_PCT) * exitPhase

    local entryPhase = math.clamp((fillRatio - 0.5) / 0.5, 0, 1)
    local rampStart = config.RAMP_START_PCT + (config.RAMP_MIN_START_PCT - config.RAMP_START_PCT) * entryPhase

    siloAssistHeightController.lastEffectiveRampStart = rampStart
    siloAssistHeightController.lastEffectiveRampEnd = rampEnd

    if progress < rampStart then
        local rampProgress = progress / rampStart
        return groundOffset + (middleHeight - groundOffset) * rampProgress
    elseif progress > rampEnd then
        local rampDown = (progress - rampEnd) / (1.0 - rampEnd)
        return middleHeight + (groundOffset - middleHeight) * rampDown
    else
        return middleHeight
    end
end

function siloAssistHeightController.calcWedgeTarget(progress, fillHeight)
    local config = siloAssistConfig
    local heightOffset = siloAssistVehicleState.getHeightOffset()

    local currentWedgeHeight = math.min(
        config.WEDGE_MAX_HEIGHT,
        config.WEDGE_HEIGHT_M + siloAssistHeightController.wedgePassCount * config.WEDGE_INCREMENT
    )

    if progress >= 0.95 then
        local heightAboveGround = siloAssistHeightController.lastRaycastGroundDistance
        if heightAboveGround ~= nil and heightAboveGround >= config.WEDGE_MAX_HEIGHT then
            currentWedgeHeight = config.WEDGE_MAX_HEIGHT + (siloAssistHeightController.wedgePassCount * config.WEDGE_INCREMENT * 0.5)
            currentWedgeHeight = math.min(currentWedgeHeight, config.WEDGE_MAX_HEIGHT * 1.5)
        end
    end

    local targetHeight = fillHeight + (1.0 - progress) * currentWedgeHeight + heightOffset
    return targetHeight
end

function siloAssistHeightController.updateWedgePass(progress)
    local atEnd = progress >= 0.95
    local nowGoingBackward = progress < siloAssistHeightController.lastProgress

    if siloAssistHeightController.wasAtSiloEnd and nowGoingBackward then
        siloAssistHeightController.wedgePassCount = siloAssistHeightController.wedgePassCount + 1
        siloAssistHeightController.wasAtSiloEnd = false
    end

    if atEnd then
        siloAssistHeightController.wasAtSiloEnd = true
    end

    siloAssistHeightController.lastProgress = progress
end

---------------------------------------------------------------------
-- Surface-aware sampling: measure actual silage height ahead of blade
---------------------------------------------------------------------
function siloAssistHeightController.sampleSurfaceAhead(vehicle)
    local bladeNode = siloAssistToolDetection.bladeNode
    if bladeNode == nil or vehicle == nil then
        return nil
    end

    local bx, by, bz = getWorldTranslation(bladeNode)

    -- Vehicle forward direction (local Z in world space)
    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    local vzx, vzy, vzz = localToWorld(vehicle.rootNode, 0, 0, 1)
    local fdx = vzx - vx
    local fdy = vzy - vy
    local fdz = vzz - vz
    local fLen = MathUtil.vector3Length(fdx, fdy, fdz)
    if fLen < 0.001 then
        return nil
    end
    fdx = fdx / fLen
    fdy = fdy / fLen
    fdz = fdz / fLen

    local pushDir = siloAssistToolDetection.isFrontAttached and 1 or -1

    local distances = {0, 0.5, 1.0, 2.0, 5.0}
    local weights = {0.10, 0.25, 0.30, 0.20, 0.15}

    local totalHeight = 0
    local totalWeight = 0
    siloAssistHeightController.surfaceSamples = {}

    local area = siloAssistSiloDetector.currentSiloArea

    for i, d in ipairs(distances) do
        local sx = bx + fdx * pushDir * d
        local sz = bz + fdz * pushDir * d
        table.insert(siloAssistHeightController.surfaceSamples, {sx, by, sz})

        local fillH
        if area ~= nil and not MathUtil.isPointInParallelogram(sx, sz, area.sx, area.sz,
                area.dwx or (area.wx - area.sx), area.dwz or (area.wz - area.sz),
                area.dhx or (area.hx - area.sx), area.dhz or (area.hz - area.sz)) then
            fillH = siloAssistSiloDetector.stagedFillHeight
        else
            local terrH, densH = DensityMapHeightUtil.getHeightAtWorldPos(sx, by, sz)
            fillH = math.max((densH or terrH) - terrH, 0)
        end

        totalHeight = totalHeight + fillH * weights[i]
        totalWeight = totalWeight + weights[i]
    end

    if totalWeight <= 0 then
        return nil
    end
    local result = totalHeight / totalWeight
    siloAssistHeightController.lastSurfaceTarget = result
    return result
end

---------------------------------------------------------------------
-- Height application: AttacherJointControl (3-point)
---------------------------------------------------------------------
function siloAssistHeightController.applyAttacherJointControl(vehicle, toolObject, heightDiff, dt)
    if toolObject == nil or toolObject.spec_attacherJointControl == nil then
        return
    end

    local spec = toolObject.spec_attacherJointControl
    if spec.jointDesc == nil then
        return
    end

    local config = siloAssistConfig
    local currentAlpha = spec.heightController.moveAlpha
    siloAssistHeightController.lastHeightDiff = heightDiff

    if siloAssistState.isStuck then
        currentAlpha = currentAlpha - config.STUCK_RAISE_STEP
        currentAlpha = math.max(spec.jointDesc.upperAlpha, currentAlpha)
        spec.heightTargetAlpha = currentAlpha
        spec.heightController.moveAlphaLastManual = currentAlpha
        siloAssistHeightController.lastAlphaDirection = -1
        return
    end

    local proportionalStep = config.ALPHA_STEP * math.clamp(math.abs(heightDiff) * 5, 0.5, 3.0)
    local deadband = config.HEIGHT_DEADBAND
    local direction = 0

    if heightDiff > deadband then
        direction = -1
    elseif heightDiff < -deadband then
        direction = 1
    end

    if direction ~= 0 then
        local atUpperLimit = currentAlpha <= spec.jointDesc.upperAlpha + 0.001
        local atLowerLimit = currentAlpha >= spec.jointDesc.lowerAlpha - 0.001
        if direction == -1 and atUpperLimit then
            direction = 0
        elseif direction == 1 and atLowerLimit then
            direction = 0
        end
    end

    siloAssistHeightController.lastAlphaDirection = direction

    if direction == -1 then
        spec.heightTargetAlpha = currentAlpha - proportionalStep
    elseif direction == 1 then
        spec.heightTargetAlpha = currentAlpha + proportionalStep
    else
        spec.heightTargetAlpha = currentAlpha
    end

    spec.heightTargetAlpha = math.clamp(spec.heightTargetAlpha, spec.jointDesc.upperAlpha, spec.jointDesc.lowerAlpha)

    spec.heightController.moveAlphaLastManual = spec.heightController.moveAlpha

    siloAssistDebug.logThrottled("Height", "ajc", string.format(
        "hDiff=%.4f dir=%d alpha=%.4f->%.4f [%.3f..%.3f] stuck=%s",
        heightDiff, direction, currentAlpha, spec.heightTargetAlpha,
        spec.jointDesc.upperAlpha, spec.jointDesc.lowerAlpha,
        tostring(siloAssistState.isStuck)
    ))
end

---------------------------------------------------------------------
-- Height application: Cylindered (wheel loader / front loader)
---------------------------------------------------------------------
function siloAssistHeightController.applyCylinderedControl(vehicle, heightDiff, speed)
    if siloAssistToolDetection.armToolIndex == nil then
        return
    end

    local cylVehicle = siloAssistToolDetection.cylinderedVehicle or vehicle
    local config = siloAssistConfig
    siloAssistHeightController.lastHeightDiff = heightDiff

    local isStopped = speed < 1.0
    local threshold = config.HEIGHT_THRESHOLD
    if isStopped then
        threshold = threshold * 2.0
    end

    if siloAssistState.isStuck then
        siloAssistHeightController.lastAlphaDirection = -1
        Cylindered.actionEventInput(cylVehicle, "", -0.5, siloAssistToolDetection.armToolIndex, true)
        return
    end

    local direction = 0
    if heightDiff > threshold then
        direction = 1
    elseif heightDiff < -threshold then
        direction = -1
    end

    siloAssistHeightController.lastAlphaDirection = direction

    if direction ~= 0 then
        local analogValue = math.clamp(math.abs(heightDiff) * 2, 0.3, 1.0) * direction
        Cylindered.actionEventInput(cylVehicle, "", analogValue, siloAssistToolDetection.armToolIndex, true)
    else
        Cylindered.actionEventInput(cylVehicle, "", 0, siloAssistToolDetection.armToolIndex, true)
    end

    siloAssistDebug.logThrottled("Height", "cyl", string.format(
        "hDiff=%.4f dir=%d threshold=%.3f stuck=%s speed=%.1f armIx=%s",
        heightDiff, direction, threshold,
        tostring(siloAssistState.isStuck), speed,
        tostring(siloAssistToolDetection.armToolIndex)
    ))
end

---------------------------------------------------------------------
-- Pre-positioning (before silo entry)
-- Lowers the blade to near-operating height as the vehicle approaches.
-- Uses ease-in curve: slow at first, then faster as we get closer.
---------------------------------------------------------------------
function siloAssistHeightController.applyPreEntry(vehicle, distanceToSilo)
    local config = siloAssistConfig
    if distanceToSilo > config.PRE_ENTRY_DISTANCE then
        return
    end

    -- progress: 1.0 = far away (PRE_ENTRY_DISTANCE), 0.0 = at silo edge
    -- ease-in: fast drop when close, gentle when far
    local rawProgress = distanceToSilo / config.PRE_ENTRY_DISTANCE
    local progress = rawProgress * rawProgress

    if siloAssistToolDetection.controlType == "attacherJointControl" then
        local toolObject = siloAssistToolDetection.toolObject
        if toolObject ~= nil and toolObject.spec_attacherJointControl ~= nil then
            local spec = toolObject.spec_attacherJointControl
            local jointDesc = spec.jointDesc
            if jointDesc ~= nil then
                local loweredAlpha = jointDesc.lowerAlpha
                local raisedAlpha = jointDesc.upperAlpha
                -- progress=1 (far): raised. progress=0 (at silo): lowered.
                local targetAlpha = raisedAlpha + (loweredAlpha - raisedAlpha) * (1.0 - progress)
                spec.heightTargetAlpha = math.clamp(targetAlpha, raisedAlpha, loweredAlpha)
            end
        end
    elseif siloAssistToolDetection.controlType == "cylindered" then
        if siloAssistToolDetection.armToolIndex ~= nil then
            local cylVehicle = siloAssistToolDetection.cylinderedVehicle or vehicle
            -- progress=1 (far): 0 (raised). progress=0 (at silo): 1 (lowered).
            local targetInput = (1.0 - progress)
            if targetInput > 0.05 then
                Cylindered.actionEventInput(cylVehicle, "", targetInput, siloAssistToolDetection.armToolIndex, true)
            end
        end
    end
end

---------------------------------------------------------------------
-- Raise blade (deactivation / leaving silo)
---------------------------------------------------------------------
function siloAssistHeightController.raiseBlade(vehicle)
    siloAssistDebug.log("Height", "raiseBlade: ctrl=" .. tostring(siloAssistToolDetection.controlType))
    if siloAssistToolDetection.controlType == "attacherJointControl" then
        local toolObject = siloAssistToolDetection.toolObject
        if toolObject ~= nil and toolObject.spec_attacherJointControl ~= nil then
            local spec = toolObject.spec_attacherJointControl
            if spec.jointDesc ~= nil then
                spec.heightTargetAlpha = spec.jointDesc.upperAlpha
                spec.heightController.moveAlphaLastManual = spec.heightController.moveAlpha
            end
        end
    elseif siloAssistToolDetection.controlType == "cylindered" then
        if siloAssistToolDetection.armToolIndex ~= nil then
            local cylVehicle = siloAssistToolDetection.cylinderedVehicle or vehicle
            Cylindered.actionEventInput(cylVehicle, "", -0.8, siloAssistToolDetection.armToolIndex, true)
        end
    end
    siloAssistHeightController.lastAlphaDirection = -1
end

---------------------------------------------------------------------
-- Main update: calculate target, measure actual, apply correction
---------------------------------------------------------------------
function siloAssistHeightController.update(vehicle, silo, progress, fillHeight, dt)
    if vehicle == nil or siloAssistToolDetection.toolType == nil then
        return
    end

    local config = siloAssistConfig
    local speed = vehicle:getLastSpeed()

    siloAssistHeightController.lastPitchDeg = siloAssistHeightController.getToolPitchDegrees(
        siloAssistToolDetection.bladeNode, siloAssistToolDetection.toolObject)

    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    local zx, zy, zz = localToWorld(vehicle.rootNode, 0, 0, 1)
    local vehiclePitch, _ = MathUtil.directionToPitchYaw(zx - vx, zy - vy, zz - vz)
    siloAssistHeightController.vehiclePitchDeg = math.deg(vehiclePitch)

    if siloAssistVehicleState.getSiloMode() == "wedge" then
        siloAssistHeightController.updateWedgePass(progress)
    end

    local followFactor = siloAssistVehicleState.getFollowFactor()
    if followFactor > 0 then
        local surfaceTarget = siloAssistHeightController.sampleSurfaceAhead(vehicle)
        if surfaceTarget ~= nil then
            fillHeight = fillHeight * (1 - followFactor) + surfaceTarget * followFactor
            siloAssistDebug.logThrottled("Height", "surface", string.format(
                "follow=%.1f surfaceTarget=%.3f blended=%.3f",
                followFactor, surfaceTarget, fillHeight
            ))
        end
    end

    local targetAboveGround = siloAssistHeightController.calculateTargetHeight(progress, fillHeight)
    targetAboveGround = math.floor(targetAboveGround * 100 + 0.5) / 100

    local bladeAboveGround = siloAssistHeightController.getDistanceFromGround(
        vehicle, siloAssistToolDetection.toolObject, siloAssistToolDetection.bladeNode)

    if bladeAboveGround ~= nil then
        siloAssistHeightController.lastRaycastGroundDistance = bladeAboveGround
    end

    siloAssistHeightController.lastTargetHeightAboveGround = targetAboveGround

    siloAssistDebug.logThrottled("Height", "calc", string.format(
        "mode=%s prog=%.3f fillH=%.3f target=%.3f blade=%.3f vehPitch=%.1f toolPitch=%s speed=%.1f",
        siloAssistVehicleState.getSiloMode(),
        progress,
        fillHeight,
        targetAboveGround,
        bladeAboveGround ~= nil and bladeAboveGround or -1,
        siloAssistHeightController.vehiclePitchDeg,
        siloAssistHeightController.lastPitchDeg ~= nil and string.format("%.1f", siloAssistHeightController.lastPitchDeg) or "nil",
        speed
    ))

    if bladeAboveGround ~= nil then
        local heightDiff = targetAboveGround - bladeAboveGround

        if siloAssistToolDetection.controlType == "attacherJointControl" then
            siloAssistHeightController.applyAttacherJointControl(
                vehicle, siloAssistToolDetection.toolObject, heightDiff, dt)
        elseif siloAssistToolDetection.controlType == "cylindered" then
            siloAssistHeightController.applyCylinderedControl(vehicle, heightDiff, speed)
        end
    else
        local bladeNode = siloAssistToolDetection.bladeNode
        if bladeNode == nil then
            return
        end
        local _, bladeY, _ = getWorldTranslation(bladeNode)
        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vx, 0, vz)
        local bladeH = bladeY - terrainHeight
        local heightDiff = targetAboveGround - bladeH

        siloAssistDebug.logThrottled("Height", "fallback", string.format(
            "Raycast=nil, using terrain. bladeY=%.3f terrH=%.3f bladeH=%.3f hDiff=%.3f",
            bladeY, terrainHeight, bladeH, heightDiff
        ))

        if siloAssistToolDetection.controlType == "attacherJointControl" then
            siloAssistHeightController.applyAttacherJointControl(
                vehicle, siloAssistToolDetection.toolObject, heightDiff, dt)
        elseif siloAssistToolDetection.controlType == "cylindered" then
            siloAssistHeightController.applyCylinderedControl(vehicle, heightDiff, speed)
        end
    end
end