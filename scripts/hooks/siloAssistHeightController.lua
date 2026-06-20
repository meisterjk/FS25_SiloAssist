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
siloAssistHeightController.alphaAtUpperLimit = false
siloAssistHeightController.alphaAtLowerLimit = false
siloAssistHeightController.vehiclePitchDeg = 0
siloAssistHeightController.lastEffectiveRampStart = 0
siloAssistHeightController.lastEffectiveRampEnd = 0

-- Surface sampling
siloAssistHeightController.surfaceSamples = {}  -- {x,y,z} world positions for debug viz
siloAssistHeightController.surfaceSampleHeights = {}  -- fill heights (m above ground) at 5 sample points
siloAssistHeightController.lastSurfaceTarget = nil

-- Vehicle ground height sampling (via wheel nodes)
siloAssistHeightController.vehicleFrontGroundHeight = nil  -- ground distance under front axle
siloAssistHeightController.vehicleRearGroundHeight = nil   -- ground distance under rear axle
siloAssistHeightController._cachedWheelFrontZ = nil  -- cached local-Z offset of front axle
siloAssistHeightController._cachedWheelRearZ = nil   -- cached local-Z offset of rear axle
siloAssistHeightController._cachedWheelVehicle = nil -- vehicle rootNode for cache identity

-- Edge surface samples (C1-C5 left/right)
siloAssistHeightController.collisionSamples = {}  -- {left={x,z,y}, right={x,z,y}} world pos of edge points
siloAssistHeightController.collisionSampleHeights = {}  -- {left=surfaceY, right=surfaceY} absolute surface Y at edges (from DensityMapHeightUtil)

-- Blade width cache
siloAssistHeightController._bladeHalfWidth = nil
siloAssistHeightController._bladeWidthNode = nil

-- Long-range entry/exit detection
siloAssistHeightController.longRangeFillHeight = nil
siloAssistHeightController.longRangeFillDetected = false
siloAssistHeightController.longRangeWorldPos = nil

-- Exit ramp state
siloAssistHeightController.exitRampActive = false
siloAssistHeightController.exitRampProgress = 0

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
    siloAssistHeightController.alphaAtUpperLimit = false
    siloAssistHeightController.alphaAtLowerLimit = false
    siloAssistHeightController.vehiclePitchDeg = 0
    siloAssistHeightController.lastEffectiveRampStart = 0
    siloAssistHeightController.lastEffectiveRampEnd = 0
    siloAssistHeightController.surfaceSamples = {}
    siloAssistHeightController.surfaceSampleHeights = {}
    siloAssistHeightController.collisionSamples = {}
    siloAssistHeightController.collisionSampleHeights = {}
    siloAssistHeightController.lastSurfaceTarget = nil
    siloAssistHeightController.vehicleFrontGroundHeight = nil
    siloAssistHeightController.vehicleRearGroundHeight = nil
    siloAssistHeightController._cachedWheelFrontZ = nil
    siloAssistHeightController._cachedWheelRearZ = nil
    siloAssistHeightController._cachedWheelVehicle = nil
    siloAssistHeightController._bladeHalfWidth = nil
    siloAssistHeightController._bladeWidthNode = nil
    siloAssistHeightController._profileType = "flat"
    siloAssistHeightController._preemptiveHeightDiff = 0
    siloAssistHeightController._profileCurvature = 0
    siloAssistHeightController._profileGradNear = 0
    siloAssistHeightController._profileGradFar = 0
    siloAssistHeightController._profileNearFlat = false
    siloAssistHeightController._profileEntering = false
    siloAssistHeightController.longRangeFillHeight = nil
    siloAssistHeightController.longRangeFillDetected = false
    siloAssistHeightController.longRangeWorldPos = nil
    siloAssistHeightController.exitRampActive = false
    siloAssistHeightController.exitRampProgress = 0
    siloAssistHeightController._lastBladeWorldPos = nil
    siloAssistHeightController._lastBladeVy = nil
    siloAssistHeightController._buryTiltActive = false
    siloAssistHeightController._buryTiltStartTime = 0
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
-- Ground raycast: returns world Y of collision surface
-- Uses raycastAll with corrected arg mapping:
--   callback args: (self, actorId, x, y, z, distance, nx, ny, ...)
---------------------------------------------------------------------
function siloAssistHeightController.raycastHitYCallback(self, transformId, _, worldY, worldZ, distance)
    if self.ignoreNodes ~= nil and self.ignoreNodes[transformId] then
        return true
    end
    self.hitY = worldY
    return false
end

function siloAssistHeightController.groundRaycastHitY(worldX, worldY, worldZ, ignoreNodes)
    local params = {
        hitY = nil,
        ignoreNodes = ignoreNodes or {},
        raycastCallback = siloAssistHeightController.raycastHitYCallback
    }
    local startY = worldY + 30
    raycastAll(worldX, startY, worldZ, 0, -1, 0, 60,
        "raycastCallback", params, siloAssistHeightController.RAYCAST_COLLISION_FLAGS)
    return params.hitY
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
    local densityH = math.max(
        siloAssistSiloDetector.densityFillHeightAtBlade or 0,
        siloAssistSiloDetector.densityFillHeightAtVehicle or 0)
    local offsetBase = math.max(fillHeight, densityH)
    local autoOffset = offsetBase * config.AUTO_FILL_OFFSET_FACTOR
    local effectiveOffset = math.max(heightOffset + autoOffset, config.MIN_HEIGHT_ABOVE_FILL)
    local groundOffset = effectiveOffset
    local middleHeight = fillHeight + effectiveOffset

    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local rampStart = math.min(config.ENTRY_RAMP_METERS / siloLength, 0.5)
    local rampEnd = math.max(1 - math.min(config.EXIT_RAMP_METERS / siloLength, 0.5), 0.5)

    siloAssistHeightController.lastEffectiveRampStart = rampStart
    siloAssistHeightController.lastEffectiveRampEnd = rampEnd

    local result
    if progress < rampStart then
        local rampProgress = progress / rampStart
        result = groundOffset + (middleHeight - groundOffset) * rampProgress
    elseif progress > rampEnd then
        local rampUp = (progress - rampEnd) / (1.0 - rampEnd)
        local exitHeight = middleHeight + config.EXIT_RAMP_HEIGHT_ADD + fillHeight * config.EXIT_RAMP_HEIGHT_FILL_FACTOR
        result = middleHeight + (exitHeight - middleHeight) * rampUp
    else
        result = middleHeight
    end
    return result
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

    local densityH = math.max(
        siloAssistSiloDetector.densityFillHeightAtBlade or 0,
        siloAssistSiloDetector.densityFillHeightAtVehicle or 0)
    local offsetBase = math.max(fillHeight, densityH)
    local autoOffset = offsetBase * config.AUTO_FILL_OFFSET_FACTOR
    local effectiveOffset = math.max(heightOffset + autoOffset, config.MIN_HEIGHT_ABOVE_FILL)

    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local rampEnd = math.max(1 - math.min(config.EXIT_RAMP_METERS / siloLength, 0.5), 0.5)

    local wedgeTarget = fillHeight + (1.0 - progress) * currentWedgeHeight + effectiveOffset

    if progress > rampEnd then
        local rampUp = (progress - rampEnd) / (1.0 - rampEnd)
        local exitHeight = wedgeTarget + config.EXIT_RAMP_HEIGHT_ADD + fillHeight * config.EXIT_RAMP_HEIGHT_FILL_FACTOR
        wedgeTarget = wedgeTarget + (exitHeight - wedgeTarget) * rampUp
    end

    return wedgeTarget
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
-- Surface-aware sampling: measure fill height ahead of blade.
-- S1-S5 center points have been REMOVED — only CL1-5 + CR1-5 (left/right
-- blade edge points) are sampled now, using FIXED distances {1,3,5,8,10}m.
-- The result is the MEDIAN of all 10 measured fill heights (more robust
-- against the silage hill that builds up directly in front of the blade,
-- which would skew the 1m point high).
-- For compatibility with consumers expecting surfaceSamples, we keep the
-- arrays but surfaceSamples/surfaceSampleHeights are now empty (no center
-- points); all data lives in collisionSamples/collisionSampleHeights.
---------------------------------------------------------------------
function siloAssistHeightController.sampleSurfaceAhead(vehicle)
    local bladeNode = siloAssistToolDetection.bladeNode
    if bladeNode == nil or vehicle == nil then
        return nil
    end

    local bx, by, bz = getWorldTranslation(bladeNode)

    -- Blade half-width from bounding box (cached)
    if siloAssistHeightController._bladeWidthNode ~= bladeNode then
        local ok, minX, _, _, maxX = pcall(getBoundingBox, bladeNode)
        if ok and minX ~= nil and maxX ~= nil and maxX > minX then
            siloAssistHeightController._bladeHalfWidth = (maxX - minX) * 0.5
        else
            siloAssistHeightController._bladeHalfWidth = 1.0
        end
        siloAssistHeightController._bladeWidthNode = bladeNode
        siloAssistDebug.log("Height", string.format("bladeHalfWidth=%.2f", siloAssistHeightController._bladeHalfWidth))
    end
    local halfW = siloAssistHeightController._bladeHalfWidth or 1.0

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

    local pushDir = siloAssistToolDetection.bladePushDir

    -- Left-perpendicular direction (for blade edge offsets)
    local perpX = -fdz
    local perpZ = fdx
    local perpLen = math.sqrt(perpX * perpX + perpZ * perpZ)
    if perpLen > 0.001 then
        perpX = perpX / perpLen
        perpZ = perpZ / perpLen
    end

    siloAssistDebug.logThrottled("Height", "surface_entry", "isFrontAttached=" .. tostring(siloAssistToolDetection.isFrontAttached) .. " pushDir=" .. pushDir .. " bladeNode=" .. string.format("%.1f,%.1f,%.1f", bx, by, bz))

    -- Fixed distances (meters). No speed scaling — TopoMap provides the
    -- strategic view; these points feed TopoMap and analyzeSurfaceProfile.
    local distances = {1.0, 3.0, 5.0, 8.0, 10.0}

    -- S1-S5 center points are no longer sampled. Arrays kept empty for
    -- compatibility with HUD/debug consumers that iterate them safely.
    siloAssistHeightController.surfaceSamples = {}
    siloAssistHeightController.surfaceSampleHeights = {}
    siloAssistHeightController.collisionSamples = {}
    siloAssistHeightController.collisionSampleHeights = {}

    -- Collect all fill heights from CL+CR for median computation
    local allFills = {}

    for i, d in ipairs(distances) do
        local sx = bx + fdx * pushDir * d
        local sz = bz + fdz * pushDir * d

        -- CL/CR: left and right blade edge points (sampled via DensityMapHeightUtil)
        local lx = sx - perpX * halfW
        local lz = sz - perpZ * halfW
        local rx = sx + perpX * halfW
        local rz = sz + perpZ * halfW

        local lSurfaceY, lFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(lx, by, lz)
        local rSurfaceY, rFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(rx, by, rz)
        local lFill = math.max(lFillAbove or 0, 0)
        local rFill = math.max(rFillAbove or 0, 0)

        table.insert(siloAssistHeightController.collisionSamples, {
            left = {lx, by, lz},
            right = {rx, by, rz}
        })
        table.insert(siloAssistHeightController.collisionSampleHeights, {
            left = lSurfaceY,
            right = rSurfaceY,
            leftFill = lFill,
            rightFill = rFill,
            distance = d,  -- stored for TopoMap Berg-filter (1m excluded)
        })

        -- Collect for median (all 10 points: 5 left + 5 right)
        table.insert(allFills, lFill)
        table.insert(allFills, rFill)

        siloAssistDebug.logThrottled("Height", string.format("cp%d", i), string.format(
            "d=%dm L=%.3f R=%.3f lx=%.1f lz=%.1f rx=%.1f rz=%.1f",
            d, lFill, rFill, lx, lz, rx, rz))
    end

    if #allFills == 0 then
        return nil
    end

    -- Median: sort and take middle element. Robust against outliers
    -- (e.g. 1m point hitting the silage hill in front of the blade).
    table.sort(allFills)
    local mid = math.ceil(#allFills / 2)
    local median = allFills[mid]
    siloAssistHeightController.lastSurfaceTarget = median

    local vx2, vy2, vz2 = getWorldTranslation(vehicle.rootNode)
    siloAssistDebug.logThrottled("Height", "surface_summary", string.format(
        "median=%.3f n=%d bladeY=%.1f vehY=%.1f fwd=%.2f,%.2f,%.2f perpLen=%.2f",
        median, #allFills, by, vy2, fdx, fdy, fdz, perpLen))
    return median
end

---------------------------------------------------------------------
-- Long-range sampling: 15m ahead of vehicle (NOT blade pushDir)
-- Always uses vehicle forward direction (+Z) for entry/exit detection.
---------------------------------------------------------------------
function siloAssistHeightController.sampleLongRange(vehicle)
    local bladeNode = siloAssistToolDetection.bladeNode
    if bladeNode == nil or vehicle == nil then
        siloAssistHeightController.longRangeFillHeight = nil
        siloAssistHeightController.longRangeFillDetected = false
        siloAssistHeightController.longRangeWorldPos = nil
        return
    end

    local bx, by, bz = getWorldTranslation(bladeNode)
    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)

    -- Vehicle forward direction
    local zx, zy, zz = localToWorld(vehicle.rootNode, 0, 0, 1)
    local fdx = zx - vx
    local fdy = zy - vy
    local fdz = zz - vz
    local fLen = MathUtil.vector3Length(fdx, fdy, fdz)
    if fLen < 0.001 then
        siloAssistHeightController.longRangeFillHeight = nil
        siloAssistHeightController.longRangeFillDetected = false
        return
    end
    fdx = fdx / fLen
    fdz = fdz / fLen

    local dist = siloAssistConfig.LONG_RANGE_SAMPLE_DIST
    local sx = bx + fdx * dist
    local sz = bz + fdz * dist

    local _, fillAbove = DensityMapHeightUtil.getHeightAtWorldPos(sx, by, sz)
    local fillH = math.max(fillAbove or 0, 0)

    siloAssistHeightController.longRangeFillHeight = fillH
    siloAssistHeightController.longRangeFillDetected = fillH > siloAssistConfig.LONG_RANGE_FILL_THRESHOLD
    siloAssistHeightController.longRangeWorldPos = {sx, by, sz}

    siloAssistDebug.logThrottled("Height", "longRange", string.format(
        "sx=%.1f sz=%.1f fillH=%.3f detected=%s",
        sx, sz, fillH, tostring(siloAssistHeightController.longRangeFillDetected)))
end

---------------------------------------------------------------------
-- Apply entry/exit height: set blade to a target height above ground
-- Reuses existing applyAttacherJointControl/applyCylinderedControl.
---------------------------------------------------------------------
function siloAssistHeightController.applyEntryExitHeight(vehicle, targetAboveGround)
    local bladeAboveGround = siloAssistHeightController.getDistanceFromGround(
        vehicle, siloAssistToolDetection.toolObject, siloAssistToolDetection.bladeNode)

    if bladeAboveGround ~= nil then
        local heightDiff = targetAboveGround - bladeAboveGround
        local dt = 0.016
        if siloAssistToolDetection.controlType == "attacherJointControl" then
            siloAssistHeightController.applyAttacherJointControl(vehicle, siloAssistToolDetection.toolObject, heightDiff, dt)
        elseif siloAssistToolDetection.controlType == "cylindered" then
            siloAssistHeightController.applyCylinderedControl(vehicle, heightDiff, 5)
        end
    end
end

---------------------------------------------------------------------
-- Profile analysis: classify the surface ahead using CL/CR edge points.
-- Replaces the former S1-S5 center-point analysis. For each distance slot
-- we compute the mean of leftFill+rightFill, giving us a 5-point profile
-- along the push direction. The 1m slot catches the silage hill in front
-- of the blade (intentional — a peak there triggers preemptive lift).
---------------------------------------------------------------------
function siloAssistHeightController.analyzeSurfaceProfile()
    local ch = siloAssistHeightController.collisionSampleHeights
    if ch == nil or #ch < 5
        or ch[1] == nil or ch[5] == nil
        or ch[1].leftFill == nil or ch[5].rightFill == nil then
        siloAssistHeightController._profileType = "flat"
        siloAssistHeightController._preemptiveHeightDiff = 0
        return
    end

    -- Build 5-point profile from mean of CL+CR per distance slot
    local s = {}
    for i = 1, 5 do
        local entry = ch[i]
        if entry == nil or entry.leftFill == nil or entry.rightFill == nil then
            siloAssistHeightController._profileType = "flat"
            siloAssistHeightController._preemptiveHeightDiff = 0
            return
        end
        s[i] = (entry.leftFill + entry.rightFill) * 0.5
    end

    local gradNear = s[2] - s[1]
    local gradFar = s[5] - s[4]
    local curvature = s[3] * 2 - s[2] - s[4]

    local profileType = "flat"
    local preemptive = 0

    if curvature > 0.03 then
        profileType = "peak"
        preemptive = -curvature * siloAssistConfig.PROFILE_GAIN
    elseif curvature < -0.03 then
        profileType = "void"
        preemptive = -curvature * siloAssistConfig.PROFILE_GAIN
    elseif gradNear > 0.05 then
        profileType = "rising"
        preemptive = gradNear * siloAssistConfig.PROFILE_GAIN
    elseif gradNear < -0.05 then
        profileType = "falling"
        preemptive = gradNear * siloAssistConfig.PROFILE_GAIN
    end

    preemptive = math.clamp(preemptive, -0.05, 0.05)

    siloAssistHeightController._profileType = profileType
    siloAssistHeightController._preemptiveHeightDiff = preemptive
    siloAssistHeightController._profileCurvature = curvature
    siloAssistHeightController._profileGradNear = gradNear
    siloAssistHeightController._profileGradFar = gradFar

    siloAssistDebug.logThrottled("Height", "profile", string.format(
        "type=%s s=[%.2f,%.2f,%.2f,%.2f,%.2f] gradN=%.3f gradF=%.3f curve=%.3f preempt=%+.4f",
        profileType, s[1], s[2], s[3], s[4], s[5],
        gradNear, gradFar, curvature, preemptive))
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

    local proportionalStep = config.ALPHA_STEP * math.clamp(math.abs(heightDiff) * 5, 0.5, 3.0)

    -- D8: Dynamischer Deadband — bei hoher TopoMap-Varianz (unruhiges Silo)
    -- den Deadband verdoppeln, damit das Schild träger reagiert und nicht
    -- auf jede kleine Unebenheit over-reacted.
    local deadband = config.HEIGHT_DEADBAND
    if siloAssistTopoMap.rows > 0 then
        local varP = siloAssistTopoMap.lastStats.variancePlateau or 0
        if varP > config.DYNAMIC_DEADBAND_VAR then
            deadband = deadband * 2
        end
    end

    local direction = 0
    if heightDiff > deadband then
        direction = -1
    elseif heightDiff < -deadband then
        direction = 1
    end

    -- D7: Boden-Abstand-Minimum — wenn Schild fast am Boden (<5cm), nicht
    -- weiter absenken. Verhindert Vergraben im Loch.
    if direction == -1 then
        local bladeDist = siloAssistHeightController.lastRaycastGroundDistance
        if bladeDist ~= nil and bladeDist < config.BLADE_MIN_GROUND_DIST then
            direction = 0
            siloAssistDebug.logThrottled("Height", "groundGuard",
                string.format("bladeDist=%.3f < %.3f → Absenken blockiert",
                    bladeDist, config.BLADE_MIN_GROUND_DIST))
        end
        -- D5: Rate-Limit — Absenken max mit halbem ALPHA_STEP (verhindert
        -- dass Schild in einem Frame um viel absinkt, z.B. in ein Loch stürzt)
        proportionalStep = proportionalStep * config.LOWER_RATE_LIMIT_FACTOR
    end

    if direction ~= 0 then
        local atUpperLimit = currentAlpha <= spec.jointDesc.upperAlpha + 0.001
        local atLowerLimit = currentAlpha >= spec.jointDesc.lowerAlpha - 0.001
        siloAssistHeightController.alphaAtUpperLimit = atUpperLimit
        siloAssistHeightController.alphaAtLowerLimit = atLowerLimit
        if direction == -1 and atUpperLimit then
            direction = 0
        elseif direction == 1 and atLowerLimit then
            direction = 0
        end
    else
        siloAssistHeightController.alphaAtUpperLimit = false
        siloAssistHeightController.alphaAtLowerLimit = false
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
        "hDiff=%.4f dir=%d alpha=%.4f->%.4f [%.3f..%.3f] stuck=%s deadband=%.3f",
        heightDiff, direction, currentAlpha, spec.heightTargetAlpha,
        spec.jointDesc.upperAlpha, spec.jointDesc.lowerAlpha,
        tostring(siloAssistState.isStuck), deadband
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

    -- D8: Dynamischer Threshold (analog zu Deadband bei AttacherJointControl)
    if siloAssistTopoMap.rows > 0 then
        local varP = siloAssistTopoMap.lastStats.variancePlateau or 0
        if varP > config.DYNAMIC_DEADBAND_VAR then
            threshold = threshold * 2
        end
    end

    local direction = 0
    if heightDiff > threshold then
        direction = 1
    elseif heightDiff < -threshold then
        direction = -1
    end

    -- D7: Boden-Abstand-Minimum — nicht weiter absenken wenn fast am Boden
    if direction == -1 then
        local bladeDist = siloAssistHeightController.lastRaycastGroundDistance
        if bladeDist ~= nil and bladeDist < config.BLADE_MIN_GROUND_DIST then
            direction = 0
            siloAssistDebug.logThrottled("Height", "groundGuard",
                string.format("bladeDist=%.3f < %.3f → Absenken blockiert (cyl)",
                    bladeDist, config.BLADE_MIN_GROUND_DIST))
        end
    end

    siloAssistHeightController.lastAlphaDirection = direction

    if direction ~= 0 then
        local analogValue = math.clamp(math.abs(heightDiff) * 2, 0.3, 1.0) * direction
        -- D5: Rate-Limit beim Absenken (analogValue verkleinern)
        if direction == -1 then
            analogValue = analogValue * config.LOWER_RATE_LIMIT_FACTOR
        end
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
-- Cache wheel axle offsets from vehicle.spec_wheels.wheels
---------------------------------------------------------------------
function siloAssistHeightController.cacheWheelOffsets(vehicle)
    local root = vehicle.rootNode
    if root == siloAssistHeightController._cachedWheelVehicle then
        return
    end

    siloAssistHeightController._cachedWheelFrontZ = 1.5
    siloAssistHeightController._cachedWheelRearZ = -1.5

    local spec = vehicle.spec_wheels
    if spec ~= nil and spec.wheels ~= nil then
        local maxZ, minZ = -math.huge, math.huge
        for _, wheel in ipairs(spec.wheels) do
            if wheel.driveNode ~= nil then
                local _, _, lz = localToLocal(wheel.driveNode, root, 0, 0, 0)
                if lz > maxZ then maxZ = lz end
                if lz < minZ then minZ = lz end
            end
        end
        if maxZ > minZ then
            siloAssistHeightController._cachedWheelFrontZ = maxZ
            siloAssistHeightController._cachedWheelRearZ = minZ
        end
    end

    siloAssistHeightController._cachedWheelVehicle = root

    siloAssistDebug.log("Height", string.format(
        "cachedWheels: frontZ=%.2f rearZ=%.2f from %d wheels",
        siloAssistHeightController._cachedWheelFrontZ,
        siloAssistHeightController._cachedWheelRearZ,
        spec ~= nil and spec.wheels ~= nil and #spec.wheels or 0
    ))
end

---------------------------------------------------------------------
-- Sample ground height under front and rear axles (via raycast)
---------------------------------------------------------------------
function siloAssistHeightController.sampleVehicleGroundHeights(vehicle)
    siloAssistHeightController.cacheWheelOffsets(vehicle)

    local root = vehicle.rootNode
    local vx, vy, vz = getWorldTranslation(root)

    local fx, _, fz = localToWorld(root, 0, 0, siloAssistHeightController._cachedWheelFrontZ)
    local rx, _, rz = localToWorld(root, 0, 0, siloAssistHeightController._cachedWheelRearZ)

    local startY = vy + 30
    local ignore = vehicle.vehicleNodes or {}

    local fp = { groundDistance = nil, ignoreNodes = ignore,
        raycastCallback = siloAssistHeightController.raycastCallback }
    raycastAll(fx, startY, fz, 0, -1, 0, 60,
        "raycastCallback", fp, siloAssistHeightController.RAYCAST_COLLISION_FLAGS)
    siloAssistHeightController.vehicleFrontGroundHeight = fp.groundDistance

    local rp = { groundDistance = nil, ignoreNodes = ignore,
        raycastCallback = siloAssistHeightController.raycastCallback }
    raycastAll(rx, startY, rz, 0, -1, 0, 60,
        "raycastCallback", rp, siloAssistHeightController.RAYCAST_COLLISION_FLAGS)
    siloAssistHeightController.vehicleRearGroundHeight = rp.groundDistance
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
        -- sampleSurfaceAhead was already called in main.lua update loop.
        -- Use the cached median (lastSurfaceTarget) instead of re-sampling.
        local surfaceTarget = siloAssistHeightController.lastSurfaceTarget
        if surfaceTarget ~= nil then
            fillHeight = fillHeight * (1 - followFactor) + surfaceTarget * followFactor
            siloAssistDebug.logThrottled("Height", "surface", string.format(
                "follow=%.1f surfaceTarget=%.3f blended=%.3f",
                followFactor, surfaceTarget, fillHeight
            ))
        end
    end

    -- Profile analysis for preemptive adjustment and ramp prediction
    siloAssistHeightController.analyzeSurfaceProfile()
    -- Build a 5-point profile from CL+CR means (same as analyzeSurfaceProfile uses)
    local ch = siloAssistHeightController.collisionSampleHeights
    local s = {}
    if ch ~= nil and #ch >= 5 then
        for i = 1, 5 do
            if ch[i] ~= nil and ch[i].leftFill ~= nil and ch[i].rightFill ~= nil then
                s[i] = (ch[i].leftFill + ch[i].rightFill) * 0.5
            end
        end
    end
    siloAssistHeightController._profileNearFlat = s[1] ~= nil and s[5] ~= nil
        and (s[3] or 0) < 0.01 and (s[4] or 0) < 0.01 and (s[5] or 0) < 0.01
    siloAssistHeightController._profileEntering = s[1] ~= nil and s[5] ~= nil
        and (s[1] or 0) > 0.01 and (s[4] or 0) < 0.01 and (s[5] or 0) < 0.01

    local legacyTarget = siloAssistHeightController.calculateTargetHeight(progress, fillHeight)
    local targetAboveGround = legacyTarget

    -- TopoMap correction: blend in map-based target deviation.
    -- gain=0 (default) → no influence, exact legacy behavior.
    -- In ramp zone, gain is damped by TOPO_MAP_RAMP_DAMPING (0.3) so the
    -- TopoMap does not fight the legacy entry/exit ramp shape.
    -- D6: Stuck → TopoMap-Korrektur komplett deaktivieren (verhindert dass
    --     sie noch tiefer zieht während das Schild feststeckt)
    local topoGain = siloAssistVehicleState.getTopoGain()
    if topoGain > 0.001 and siloAssistTopoMap.rows > 0
        and siloAssistToolDetection.bladeNode ~= nil
        and not siloAssistState.isStuck then
        local bx, by, bz = getWorldTranslation(siloAssistToolDetection.bladeNode)
        local correction, cellInRamp = siloAssistTopoMap.getCorrectionAt(bx, bz)
        if correction ~= nil then
            -- D3: Pitch-Schutz — wenn Fahrzeug stark vorne runter geneigt
            -- (bergab im Silo), keine TopoMap-Absenkung (correction < 0)
            if siloAssistHeightController.vehiclePitchDeg < siloAssistConfig.PITCH_NO_LOWER_DEG
                and correction < 0 then
                correction = 0
                siloAssistDebug.logThrottled("TopoMap", "pitchGuard",
                    string.format("pitch=%.1f < %.1f → TopoMap-Absenkung blockiert",
                        siloAssistHeightController.vehiclePitchDeg,
                        siloAssistConfig.PITCH_NO_LOWER_DEG))
            end

            local effectiveGain = topoGain
            if cellInRamp then
                effectiveGain = topoGain * siloAssistConfig.TOPO_MAP_RAMP_DAMPING
            end
            targetAboveGround = targetAboveGround + correction * effectiveGain

            -- D1: Max-Korrektur-Term — TopoMap darf Legacy-Ziel max um 30cm verschieben
            local totalCorrection = targetAboveGround - legacyTarget
            local maxCorr = siloAssistConfig.TOPO_MAX_CORRECTION
            if math.abs(totalCorrection) > maxCorr then
                targetAboveGround = legacyTarget + math.clamp(totalCorrection, -maxCorr, maxCorr)
                siloAssistDebug.logThrottled("TopoMap", "cap",
                    string.format("corr=%.3f capped to ±%.2f", totalCorrection, maxCorr))
            end

            siloAssistDebug.logThrottled("TopoMap", "correct", string.format(
                "gain=%.2f effGain=%.2f corr=%+.3f ramp=%s target=%.3f",
                topoGain, effectiveGain, correction, tostring(cellInRamp),
                targetAboveGround))
        end
    end

    targetAboveGround = math.floor(targetAboveGround * 100 + 0.5) / 100

    local bladeAboveGround = siloAssistHeightController.getDistanceFromGround(
        vehicle, siloAssistToolDetection.toolObject, siloAssistToolDetection.bladeNode)

    if bladeAboveGround ~= nil then
        siloAssistHeightController.lastRaycastGroundDistance = bladeAboveGround
    end

    -- D4b: Release buryTilt only when minimum duration has elapsed AND blade
    -- is safely above target. Prevents oscillation between forceTilt/clearForceTilt.
    if siloAssistHeightController._buryTiltActive and bladeAboveGround ~= nil then
        local elapsed = g_currentMission.time - siloAssistHeightController._buryTiltStartTime
        if elapsed >= siloAssistConfig.BURY_VY_MIN_DURATION_MS then
            local releaseMargin = siloAssistConfig.BURY_VY_RELEASE_MARGIN
            if bladeAboveGround >= targetAboveGround + releaseMargin then
                siloAssistTiltController.clearForceTilt()
                siloAssistHeightController._buryTiltActive = false
                siloAssistDebug.log("Height", string.format(
                    "buryTilt released: blade=%.3f >= target+margin=%.3f after %dms",
                    bladeAboveGround, targetAboveGround + releaseMargin, elapsed))
            end
        end
    end

    -- D4: vy-Schutz — Schild-Vertikal-Geschwindigkeit messen. Wenn das Schild
    -- schnell nach unten stürzt (vy < threshold), prophylaktisch anheben und
    -- Neigung ganz nach hinten (forceTilt). Release erst nach Mindestdauer und
    -- wenn Schild wieder über Ziel (siehe D4b oben).
    if siloAssistToolDetection.bladeNode ~= nil then
        local bx, by, bz = getWorldTranslation(siloAssistToolDetection.bladeNode)
        local prev = siloAssistHeightController._lastBladeWorldPos
        siloAssistHeightController._lastBladeWorldPos = {bx, by, bz}
        if prev ~= nil then
            local dtSec = math.max(dt / 1000, 0.001)
            local vy = (by - prev[2]) / dtSec
            siloAssistHeightController._lastBladeVy = vy
            if not siloAssistHeightController._buryTiltActive and vy < siloAssistConfig.BURY_VY_THRESHOLD then
                targetAboveGround = targetAboveGround + siloAssistConfig.BURY_VY_LIFT
                siloAssistTiltController.forceTilt(vehicle, siloAssistConfig.TILT_MAX)
                siloAssistHeightController._buryTiltActive = true
                siloAssistHeightController._buryTiltStartTime = g_currentMission.time
                siloAssistDebug.logThrottled("Height", "vyGuard",
                    string.format("vy=%.2f < %.2f → +%+.2fm + forceTilt(%d°)",
                        vy, siloAssistConfig.BURY_VY_THRESHOLD,
                        siloAssistConfig.BURY_VY_LIFT, siloAssistConfig.TILT_MAX))
            end
        end
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
        local preemptive = siloAssistHeightController._preemptiveHeightDiff or 0
        if math.abs(preemptive) > 0.001 then
            heightDiff = heightDiff + preemptive
            siloAssistDebug.logThrottled("Height", "preempt", string.format(
                "preempt=%.4f hDiffAfter=%.4f", preemptive, heightDiff))
        end

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
        local preemptive = siloAssistHeightController._preemptiveHeightDiff or 0
        if math.abs(preemptive) > 0.001 then
            heightDiff = heightDiff + preemptive
        end

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