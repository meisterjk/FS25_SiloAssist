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

-- Silo sensor (16th sensor, 15m ahead center)
siloAssistHeightController.siloSensorFillHeight = nil
siloAssistHeightController.siloSensorFillDetected = false
siloAssistHeightController.siloSensorWorldPos = nil

-- Exit sensor: detects when blade is approaching silo exit (no fill ahead)
siloAssistHeightController.exitSensorFillHeight = nil
siloAssistHeightController.exitSensorFillDetected = true  -- default true = still in silo
siloAssistHeightController.exitSensorWorldPos = nil

-- Silo end sensor: checks if a point ahead is still inside the silo area (walls, not fill)
siloAssistHeightController.siloEndInside = true  -- default true = still inside silo
siloAssistHeightController.siloEndWorldPos = nil

-- Exit ramp state
siloAssistHeightController.exitRampActive = false
siloAssistHeightController.exitRampProgress = 0
siloAssistHeightController.exitRampHeightAdd = 0

-- Push mode: full silo scan state
siloAssistHeightController.pushScanAvgHeight = nil     -- average height of plateau (excluding ramps)
siloAssistHeightController.pushScanMedianHeight = nil  -- median height of plateau
siloAssistHeightController.pushScanMinHeight = nil      -- min height in scan
siloAssistHeightController.pushScanMaxHeight = nil      -- max height in scan
siloAssistHeightController.pushScanCount = 0           -- number of scan points
siloAssistHeightController.pushScanDone = false         -- scan completed?
siloAssistHeightController.pushNeedRescan = false       -- trigger rescan on next update
siloAssistHeightController.pushScanPoints = {}          -- {x, z, fillH} for visualization

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistHeightController.reset()
    siloAssistHeightController.currentTargetAlpha = nil
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
    siloAssistHeightController.longRangeFillHeight = nil
    siloAssistHeightController.longRangeFillDetected = false
    siloAssistHeightController.longRangeWorldPos = nil
    siloAssistHeightController.exitRampActive = false
    siloAssistHeightController.exitRampProgress = 0
    siloAssistHeightController.exitRampHeightAdd = 0
    siloAssistHeightController._lastBladeWorldPos = nil
    siloAssistHeightController._lastBladeVy = nil
    siloAssistHeightController._buryTiltActive = false
    siloAssistHeightController._buryTiltStartTime = 0
    siloAssistHeightController.siloSensorFillHeight = nil
    siloAssistHeightController.siloSensorFillDetected = false
    siloAssistHeightController.siloSensorWorldPos = nil
    siloAssistHeightController.exitSensorFillHeight = nil
    siloAssistHeightController.exitSensorFillDetected = true
    siloAssistHeightController.exitSensorWorldPos = nil
    siloAssistHeightController.siloEndInside = true
    siloAssistHeightController.siloEndWorldPos = nil
    siloAssistHeightController.siloSensorWorldPos = nil
    siloAssistHeightController.pushScanAvgHeight = nil
    siloAssistHeightController.pushScanMedianHeight = nil
    siloAssistHeightController.pushScanMinHeight = nil
    siloAssistHeightController.pushScanMaxHeight = nil
    siloAssistHeightController.pushScanCount = 0
    siloAssistHeightController.pushScanDone = false
    siloAssistHeightController.pushNeedRescan = false
    siloAssistHeightController.pushScanPoints = {}
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
-- Shared: calculate effective offset (user + auto, clamped to minimum).
-- Used by all modes via dispatcher.
---------------------------------------------------------------------
function siloAssistHeightController.calcEffectiveOffset(fillHeight, densityH)
    local config = siloAssistConfig
    local heightOffset = siloAssistVehicleState.getHeightOffset()
    local offsetBase = math.max(fillHeight, densityH or 0)
    local autoOffset = offsetBase * config.AUTO_FILL_OFFSET_FACTOR
    return math.max(heightOffset + autoOffset, config.MIN_HEIGHT_ABOVE_FILL)
end

---------------------------------------------------------------------
-- Shared: universal ramp target calculation.
-- Pure math — no mode logic, no config access.
--   baseHeight: base fill height (e.g. fillHeight or scanned average)
--   offset: effective offset above base
--   progress: 0=silo entrance, 1=silo end
--   rampStart: progress fraction where entry ramp starts (0 = no ramp)
--   rampEnd: progress fraction where exit ramp ends (1 = no ramp)
--   rampHeight: additional height at progress=1 (0 = flat, >0 = wedge slope)
---------------------------------------------------------------------
function siloAssistHeightController.calcRampTarget(baseHeight, offset, progress, rampStart, rampEnd, rampHeight)
    local groundOffset = offset
    local fullHeight = baseHeight + offset

    if progress < rampStart and rampStart > 0 then
        local t = progress / rampStart
        return groundOffset + (fullHeight - groundOffset) * t
    elseif progress > rampEnd and rampEnd < 1 and rampHeight ~= 0 then
        local t = (progress - rampEnd) / (1 - rampEnd)
        return fullHeight + rampHeight * (1 - t)
    else
        if rampHeight > 0 then
            return baseHeight + progress * rampHeight + offset
        else
            return fullHeight
        end
    end
end

---------------------------------------------------------------------
-- Target height calculation — dispatcher.
-- Computes shared offset, delegates to mode module.
---------------------------------------------------------------------
function siloAssistHeightController.calculateTargetHeight(progress, fillHeight)
    local densityH = math.max(
        siloAssistSiloDetector.densityFillHeightAtBlade or 0,
        siloAssistSiloDetector.densityFillHeightAtVehicle or 0)
    local effectiveOffset = siloAssistHeightController.calcEffectiveOffset(fillHeight, densityH)

    local siloMode = siloAssistVehicleState.getSiloMode()
    local target

    if siloMode == "push" then
        target = siloAssistModePush.calcTarget(progress, fillHeight, effectiveOffset)
    elseif siloMode == "smooth" then
        target = siloAssistModeSmooth.calcTarget(progress, fillHeight, effectiveOffset)
    elseif siloMode == "wedge" then
        target = siloAssistModeWedge.calcTarget(progress, fillHeight, effectiveOffset)
    else
        target = fillHeight + effectiveOffset
    end

    target = target + (siloAssistState.stuckHeightAdd or 0)

    return target
end



---------------------------------------------------------------------
-- Full silo scan for push mode: samples the entire silo plateau
-- (excluding entry/exit ramp zones) and computes average fill height.
-- Result stored in pushScanAvgHeight, remains fixed until rescan triggered.
---------------------------------------------------------------------
function siloAssistHeightController.scanFullSilo(silo, area)
    if silo == nil or area == nil then
        siloAssistDebug.log("Height", "scanFullSilo: silo or area nil")
        return
    end

    local dhx, dhz, dwx, dwz
    if area.dhx ~= nil then
        dhx, dhz = area.dhx, area.dhz
        dwx, dwz = area.dwx, area.dwz
    else
        dhx = area.hx - area.sx
        dhz = area.hz - area.sz
        dwx = area.wx - area.sx
        dwz = area.wz - area.sz
    end
    local siloLength = MathUtil.vector3Length(dhx, 0, dhz)
    local siloWidth = MathUtil.vector3Length(dwx, 0, dwz)
    if siloLength < 1 or siloWidth < 1 then
        siloAssistDebug.log("Height", "scanFullSilo: invalid silo dimensions")
        return
    end

    local nhx, nhz = dhx / siloLength, dhz / siloLength
    local nwx, nwz = dwx / siloWidth, dwz / siloWidth

    local config = siloAssistConfig
    local rampStartPct = math.min(config.ENTRY_RAMP_METERS / siloLength, 0.5)
    local rampEndPct = math.max(1 - config.EXIT_RAMP_LENGTH / siloLength, 0.5)

    -- Dynamic step: ensure at least PUSH_SCAN_MIN_POINTS per strip, cap at PUSH_SCAN_STEP_M
    local step = siloLength / config.PUSH_SCAN_MIN_POINTS
    step = math.max(step, 0.5)       -- minimum 0.5m resolution
    step = math.min(step, config.PUSH_SCAN_STEP_M)  -- maximum step
    local numLong = math.floor(siloLength / step)
    if numLong < 2 then numLong = 2 end
    local actualStep = siloLength / numLong

    -- Lateral strips: 25%, 50%, 75% of width
    local latStrips = {0.25, 0.50, 0.75}

    local heights = {}
    local sum, count = 0, 0
    local startY = 100
    local scanPoints = {}

    for i = 0, numLong do
        local prog = i / numLong
        for _, latPct in ipairs(latStrips) do
            local wx = area.sx + nhx * prog * siloLength + nwx * latPct * siloWidth
            local wz = area.sz + nhz * prog * siloLength + nwz * latPct * siloWidth
            local _, fillAbove = DensityMapHeightUtil.getHeightAtWorldPos(wx, startY, wz)
            local fillH = math.max(fillAbove or 0, 0)
            local isRamp = config.PUSH_SCAN_RAMP_EXCLUDE and (prog < rampStartPct or prog > rampEndPct)
            scanPoints[#scanPoints + 1] = { x = wx, z = wz, fillH = fillH, isRamp = isRamp }
            if not isRamp then
                sum = sum + fillH
                count = count + 1
                heights[#heights + 1] = fillH
            end
        end
    end

    if count > 0 then
        table.sort(heights)
        local avg = sum / count
        local median = heights[math.ceil(#heights / 2)]
        local minH = heights[1]
        local maxH = heights[#heights]

        siloAssistHeightController.pushScanAvgHeight = avg
        siloAssistHeightController.pushScanMedianHeight = median
        siloAssistHeightController.pushScanMinHeight = minH
        siloAssistHeightController.pushScanMaxHeight = maxH
        siloAssistHeightController.pushScanCount = count
        siloAssistHeightController.pushScanDone = true
        siloAssistHeightController.pushNeedRescan = false
        siloAssistHeightController.pushScanPoints = scanPoints
        siloAssistDebug.log("Height", string.format(
            "scanFullSilo: avg=%.3f med=%.3f min=%.3f max=%.3f count=%d step=%.2f len=%.1f wid=%.1f rampPct=[%.2f..%.2f]",
            avg, median, minH, maxH, count, actualStep,
            siloLength, siloWidth, rampStartPct, rampEndPct))
    else
        siloAssistDebug.log("Height", "scanFullSilo: no samples collected (ramp zones cover entire silo?)")
    end
end

---------------------------------------------------------------------
-- Surface-aware sampling: measure fill height ahead of blade.
-- 16-sensor array:
--   10 outer sensors (L+R) at distances {1,3,5,8,10}m, lateral offset halfW+1m
--    5 center sensors at distances {1,3,5,8,10}m, lateral 0 (between L and R)
--    1 silo sensor at 15m, center (separate from longRange)
-- All 15 height sensors (excluding silo sensor) feed into the median.
-- For compatibility, collisionSampleHeights stores per-distance:
--   leftFill, rightFill, midFill, distance
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
    local outerOffset = halfW + 1.0  -- L/R sensors 1m further out

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

    siloAssistDebug.logThrottled("Height", "surface_entry", string.format(
        "isFront=%s pushDir=%d bladePos=(%.1f,%.1f,%.1f) fwdDir=(%.3f,%.3f) vehPos=(%.1f,%.1f,%.1f) sensor1m=(%.1f,%.1f)",
        tostring(siloAssistToolDetection.isFrontAttached), pushDir,
        bx, by, bz, fdx, fdz, vx, vy, vz,
        bx + fdx * pushDir * 1.0, bz + fdz * pushDir * 1.0))

    -- Fixed distances (meters). No speed scaling.
    local distances = {1.0, 3.0, 5.0, 8.0, 10.0}

    siloAssistHeightController.surfaceSamples = {}
    siloAssistHeightController.surfaceSampleHeights = {}
    siloAssistHeightController.collisionSamples = {}
    siloAssistHeightController.collisionSampleHeights = {}

    -- Collect all fill heights from 15 sensors (10 L/R + 5 mid) for median
    local allFills = {}

    for i, d in ipairs(distances) do
        local sx = bx + fdx * pushDir * d
        local sz = bz + fdz * pushDir * d

        -- Outer L/R: 1m further out than blade half-width
        local lx = sx - perpX * outerOffset
        local lz = sz - perpZ * outerOffset
        local rx = sx + perpX * outerOffset
        local rz = sz + perpZ * outerOffset
        -- Center: lateral 0
        local mx = sx
        local mz = sz

        local lSurfaceY, lFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(lx, by, lz)
        local rSurfaceY, rFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(rx, by, rz)
        local mSurfaceY, mFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(mx, by, mz)
        local lFill = math.max(lFillAbove or 0, 0)
        local rFill = math.max(rFillAbove or 0, 0)
        local mFill = math.max(mFillAbove or 0, 0)

        table.insert(siloAssistHeightController.collisionSamples, {
            left = {lx, by, lz},
            right = {rx, by, rz},
            mid = {mx, by, mz},
        })
        table.insert(siloAssistHeightController.collisionSampleHeights, {
            left = lSurfaceY,
            right = rSurfaceY,
            mid = mSurfaceY,
            leftFill = lFill,
            rightFill = rFill,
            midFill = mFill,
            distance = d,
        })

        -- Collect for median: only 9 farthest sensors (distances 5,8,10 = indices 3,4,5)
        -- Exclude the 6 nearest (distances 1,3 = indices 1,2) — they're skewed by
        -- the silage hill building up directly in front of the blade.
        if i >= 3 then
            table.insert(allFills, lFill)
            table.insert(allFills, rFill)
            table.insert(allFills, mFill)
        end

        siloAssistDebug.logThrottled("Height", string.format("cp%d", i), string.format(
            "d=%dm L=%.3f M=%.3f R=%.3f lx=%.1f lz=%.1f rx=%.1f rz=%.1f",
            d, lFill, mFill, rFill, lx, lz, rx, rz))
    end

    if #allFills == 0 then
        return nil
    end

    -- Silo sensor: 15m ahead, center
    local siloDist = siloAssistConfig.SILO_SENSOR_DIST
    local ssx = bx + fdx * pushDir * siloDist
    local ssz = bz + fdz * pushDir * siloDist
    local _, siloFillAbove = DensityMapHeightUtil.getHeightAtWorldPos(ssx, by, ssz)
    local siloFillH = math.max(siloFillAbove or 0, 0)
    siloAssistHeightController.siloSensorFillHeight = siloFillH
    siloAssistHeightController.siloSensorFillDetected = siloFillH > siloAssistConfig.SILO_SENSOR_FILL_THRESHOLD
    siloAssistHeightController.siloSensorWorldPos = {ssx, by, ssz}

    -- Median: sort and take middle element
    table.sort(allFills)
    local mid = math.ceil(#allFills / 2)
    local median = allFills[mid]
    siloAssistHeightController.lastSurfaceTarget = median

    siloAssistDebug.logThrottled("Height", "surface_summary", string.format(
        "median=%.3f n=%d siloSensor=%.3f(%s) bladeY=%.1f outerOff=%.2f",
        median, #allFills, siloFillH, tostring(siloAssistHeightController.siloSensorFillDetected),
        by, outerOffset))
    return median
end

---------------------------------------------------------------------
-- Long-range sampling: 15m ahead of blade in push direction.
-- Uses pushDir to always sample toward the silo.
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

    -- Vehicle direction (Z+ = rear in FS25)
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

    local pushDir = siloAssistToolDetection.bladePushDir
    local dist = siloAssistConfig.LONG_RANGE_SAMPLE_DIST
    local sx = bx + fdx * pushDir * dist
    local sz = bz + fdz * pushDir * dist

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
-- Exit sensor: detects when blade is approaching silo exit.
-- Raycasts at EXIT_DETECT_DISTANCE ahead of blade in push direction.
-- When fill is no longer detected, exit ramp should start.
---------------------------------------------------------------------
function siloAssistHeightController.sampleExitSensor(vehicle)
    local bladeNode = siloAssistToolDetection.bladeNode
    if bladeNode == nil or vehicle == nil then
        siloAssistHeightController.exitSensorFillHeight = nil
        siloAssistHeightController.exitSensorFillDetected = true
        siloAssistHeightController.exitSensorWorldPos = nil
        return
    end

    local bx, by, bz = getWorldTranslation(bladeNode)
    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    local vzx, vzy, vzz = localToWorld(vehicle.rootNode, 0, 0, 1)
    local fdx = vzx - vx
    local fdy = vzy - vy
    local fdz = vzz - vz
    local fLen = MathUtil.vector3Length(fdx, fdy, fdz)
    if fLen < 0.001 then
        siloAssistHeightController.exitSensorFillHeight = nil
        siloAssistHeightController.exitSensorFillDetected = true
        return
    end
    fdx = fdx / fLen
    fdz = fdz / fLen

    local pushDir = siloAssistToolDetection.bladePushDir

    local dist = siloAssistConfig.EXIT_DETECT_DISTANCE
    local sx = bx + fdx * pushDir * dist
    local sz = bz + fdz * pushDir * dist

    local _, fillAbove = DensityMapHeightUtil.getHeightAtWorldPos(sx, by, sz)
    local fillH = math.max(fillAbove or 0, 0)

    siloAssistHeightController.exitSensorFillHeight = fillH
    siloAssistHeightController.exitSensorFillDetected = fillH > siloAssistConfig.EXIT_DETECT_FILL_THRESHOLD
    siloAssistHeightController.exitSensorWorldPos = {sx, by, sz}

    siloAssistDebug.logThrottled("Height", "exitSensor", string.format(
        "sx=%.1f sz=%.1f fillH=%.3f detected=%s dist=%.1f pushDir=%d",
        sx, sz, fillH, tostring(siloAssistHeightController.exitSensorFillDetected), dist, pushDir))
end

---------------------------------------------------------------------
-- Silo end sensor: checks if a point SILO_END_SENSOR_DIST meters ahead
-- of the blade is still inside the silo area (parallelogram).
-- Used for wedge mode to detect silo exit (walls), not fill level.
---------------------------------------------------------------------
function siloAssistHeightController.sampleSiloEndSensor(vehicle)
    local bladeNode = siloAssistToolDetection.bladeNode
    local silo = siloAssistSiloDetector.currentSilo
    if bladeNode == nil or vehicle == nil or silo == nil then
        siloAssistHeightController.siloEndInside = true
        siloAssistHeightController.siloEndWorldPos = nil
        return
    end

    local area = siloAssistSiloDetector.getSiloArea(silo)
    if area == nil then
        siloAssistHeightController.siloEndInside = true
        siloAssistHeightController.siloEndWorldPos = nil
        return
    end

    local dhx, dhz, dwx, dwz
    if area.dhx ~= nil then
        dhx, dhz = area.dhx, area.dhz
        dwx, dwz = area.dwx, area.dwz
    else
        dhx = area.hx - area.sx
        dhz = area.hz - area.sz
        dwx = area.wx - area.sx
        dwz = area.wz - area.sz
    end

    local bx, by, bz = getWorldTranslation(bladeNode)
    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    local vzx, vzy, vzz = localToWorld(vehicle.rootNode, 0, 0, 1)
    local fdx = vzx - vx
    local fdy = vzy - vy
    local fdz = vzz - vz
    local fLen = MathUtil.vector3Length(fdx, fdy, fdz)
    if fLen < 0.001 then
        siloAssistHeightController.siloEndInside = true
        siloAssistHeightController.siloEndWorldPos = nil
        return
    end
    fdx = fdx / fLen
    fdz = fdz / fLen

    local pushDir = siloAssistToolDetection.bladePushDir
    local dist = siloAssistConfig.SILO_END_SENSOR_DIST
    local sx = bx + fdx * pushDir * dist
    local sz = bz + fdz * pushDir * dist

    local inside = MathUtil.isPointInParallelogram(sx, sz, area.sx, area.sz, dwx, dwz, dhx, dhz)

    siloAssistHeightController.siloEndInside = inside
    siloAssistHeightController.siloEndWorldPos = {sx, by, sz}

    siloAssistDebug.logThrottled("Height", "siloEnd", string.format(
        "sx=%.1f sz=%.1f inside=%s dist=%.1f pushDir=%d",
        sx, sz, tostring(inside), dist, pushDir))
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
        elseif siloAssistToolDetection.controlType == "attacherJoints" then
            siloAssistHeightController.applyAttacherJointsControl(vehicle, heightDiff, dt)
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
-- Height application: AttacherJoints direct (3-point without AJC)
-- Used for compactor tools like HOLARAS Stego that have no
-- spec_attacherJointControl. Directly sets moveAlpha on the joint.
---------------------------------------------------------------------
function siloAssistHeightController.applyAttacherJointsControl(vehicle, heightDiff, dt)
    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
    local toolObject = siloAssistToolDetection.toolObject
    local jointDescIndex = siloAssistToolDetection.jointDescIndex

    if rootVehicle.spec_attacherJoints == nil or rootVehicle.spec_attacherJoints.attacherJoints == nil then
        return
    end

    local config = siloAssistConfig
    siloAssistHeightController.lastHeightDiff = heightDiff

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

    -- Ground guard: don't lower further if almost touching ground
    if direction == -1 then
        local bladeDist = siloAssistHeightController.lastRaycastGroundDistance
        if bladeDist ~= nil and bladeDist < config.BLADE_MIN_GROUND_DIST then
            direction = 0
        end
    end

    siloAssistHeightController.lastAlphaDirection = direction

    for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
        if toolObject == nil or joint.moveAttacherJointObject == toolObject then
            if joint.moveAlpha ~= nil and joint.lowerAlpha ~= nil and joint.upperAlpha ~= nil then
                local alphaRange = joint.lowerAlpha - joint.upperAlpha
                local stepSize = config.ALPHA_STEP * alphaRange

                if direction == -1 then
                    joint.moveAlpha = math.max(joint.moveAlpha - stepSize, joint.upperAlpha)
                elseif direction == 1 then
                    joint.moveAlpha = math.min(joint.moveAlpha + stepSize, joint.lowerAlpha)
                end

                siloAssistDebug.logThrottled("Height", "attJoints", string.format(
                    "hDiff=%.4f dir=%d moveAlpha=%.4f [%.3f..%.3f]",
                    heightDiff, direction, joint.moveAlpha,
                    joint.upperAlpha, joint.lowerAlpha))
            end
        end
    end
end

---------------------------------------------------------------------
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
    elseif siloAssistToolDetection.controlType == "attacherJoints" then
        local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
        local toolObject = siloAssistToolDetection.toolObject
        if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
            for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
                if toolObject == nil or joint.moveAttacherJointObject == toolObject then
                    if joint.moveAlpha ~= nil and joint.upperAlpha ~= nil and joint.lowerAlpha ~= nil then
                        local raisedAlpha = joint.upperAlpha
                        local loweredAlpha = joint.lowerAlpha
                        local targetAlpha = raisedAlpha + (loweredAlpha - raisedAlpha) * (1.0 - progress)
                        joint.moveAlpha = math.clamp(targetAlpha, raisedAlpha, loweredAlpha)
                    end
                end
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
    elseif siloAssistToolDetection.controlType == "attacherJoints" then
        local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
        local toolObject = siloAssistToolDetection.toolObject
        if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
            for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
                if toolObject == nil or joint.moveAttacherJointObject == toolObject then
                    if joint.moveAlpha ~= nil and joint.upperAlpha ~= nil then
                        joint.moveAlpha = joint.upperAlpha
                    end
                end
            end
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
function siloAssistHeightController.update(vehicle, silo, progress, entryProgress, fillHeight, dt)
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

    -- Target height calculation (dispatches to mode modules: push/smooth/wedge)
    -- Use entryProgress for wedge mode (entry-oriented), progress for others
    local mode = siloAssistVehicleState.getSiloMode()
    local calcProgress = (mode == "wedge") and entryProgress or progress
    local targetAboveGround = siloAssistHeightController.calculateTargetHeight(calcProgress, fillHeight)

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
        "mode=%s prog=%.3f entryProg=%.3f fillH=%.3f target=%.3f blade=%.3f vehPitch=%.1f toolPitch=%s speed=%.1f",
        siloAssistVehicleState.getSiloMode(),
        progress,
        entryProgress,
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
        elseif siloAssistToolDetection.controlType == "attacherJoints" then
            siloAssistHeightController.applyAttacherJointsControl(vehicle, heightDiff, dt)
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
        elseif siloAssistToolDetection.controlType == "attacherJoints" then
            siloAssistHeightController.applyAttacherJointsControl(vehicle, heightDiff, dt)
        end
    end
end