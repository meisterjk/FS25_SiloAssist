--====================================================================
-- SiloAssist - Topography Map
-- A persistent 1m^2 grid over the silo parallelogram that stores fill
-- heights from surface samples (S1-S5 + C1-C5) and computes a target
-- topography per silo mode.
--
-- Phase 1: Fundament - init/sample/update/reset + logging only.
--          No steering influence yet (gain=0).
--====================================================================

siloAssistTopoMap = {}

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
siloAssistTopoMap.grid = {}              -- grid[r][c] = { fillHeight, samples, lastUpdate, target }
siloAssistTopoMap.rows = 0
siloAssistTopoMap.cols = 0
siloAssistTopoMap.cellSize = 1.0
siloAssistTopoMap.origin = { x = 0, z = 0 }   -- area.sx, area.sz
siloAssistTopoMap.axisH = { x = 0, z = 0 }   -- normalized length axis (dh/|dh|)
siloAssistTopoMap.axisW = { x = 0, z = 0 }   -- normalized width  axis (dw/|dw|)
siloAssistTopoMap.length = 0                 -- meters
siloAssistTopoMap.width = 0                  -- meters
siloAssistTopoMap.siloRef = nil              -- silo object reference (for change detection)
siloAssistTopoMap.areaRef = nil              -- area object reference
siloAssistTopoMap.lastStats = {
    avg = 0, avgPlateau = 0, avgRamp = 0,
    min = 0, max = 0,
    variance = 0, variancePlateau = 0,
    coveragePct = 0, cellsFilled = 0, cellsPlateau = 0, cellsRamp = 0, cellsTotal = 0,
    done = false,
}
siloAssistTopoMap.doneHoldTimer = 0          -- ms accumulator while variance below tolerance
siloAssistTopoMap.doneConfirmed = false      -- true once holdTimer exceeds TOPO_MAP_DONE_HOLD_SEC

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistTopoMap.reset()
    siloAssistTopoMap.grid = {}
    siloAssistTopoMap.rows = 0
    siloAssistTopoMap.cols = 0
    siloAssistTopoMap.cellSize = 1.0
    siloAssistTopoMap.origin = { x = 0, z = 0 }
    siloAssistTopoMap.axisH = { x = 0, z = 0 }
    siloAssistTopoMap.axisW = { x = 0, z = 0 }
    siloAssistTopoMap.length = 0
    siloAssistTopoMap.width = 0
    siloAssistTopoMap.siloRef = nil
    siloAssistTopoMap.areaRef = nil
    siloAssistTopoMap.lastStats = {
        avg = 0, avgPlateau = 0, avgRamp = 0,
        min = 0, max = 0,
        variance = 0, variancePlateau = 0,
        coveragePct = 0, cellsFilled = 0, cellsPlateau = 0, cellsRamp = 0, cellsTotal = 0,
        done = false,
    }
    siloAssistTopoMap.doneHoldTimer = 0
    siloAssistTopoMap.doneConfirmed = false
end

---------------------------------------------------------------------
-- Init: build empty grid from silo parallelogram.
-- area has sx/sz + dhx/dhz/dwx/dwz (or hx/hz/wx/wz) like getSiloAreaVectors.
-- Returns true on success, false otherwise.
---------------------------------------------------------------------
function siloAssistTopoMap.init(silo, area, cellSize)
    if silo == nil or area == nil then
        siloAssistDebug.log("TopoMap", "init: silo or area nil")
        return false
    end

    -- If same silo + same cell size, skip rebuild (preserve samples)
    if siloAssistTopoMap.siloRef == silo
        and siloAssistTopoMap.cellSize == cellSize
        and siloAssistTopoMap.rows > 0 then
        siloAssistDebug.log("TopoMap", "init: same silo, skip rebuild")
        return true
    end

    -- Extract vectors
    local dhx, dhz, dwx, dwz, length, width
    if area.dhx ~= nil then
        dhx, dhz = area.dhx, area.dhz
        dwx, dwz = area.dwx, area.dwz
        length = MathUtil.vector3Length(dhx, 0, dhz)
        width  = MathUtil.vector3Length(dwx, 0, dwz)
    else
        dhx = area.hx - area.sx
        dhz = area.hz - area.sz
        dwx = area.wx - area.sx
        dwz = area.wz - area.sz
        length = MathUtil.vector3Length(dhx, 0, dhz)
        width  = MathUtil.vector3Length(dwx, 0, dwz)
    end

    if length == nil or width == nil or length < 0.5 or width < 0.5 then
        siloAssistDebug.log("TopoMap", string.format(
            "init: invalid dims len=%.2f wid=%.2f", length or -1, width or -1))
        return false
    end

    -- Normalize axes (unit vectors along silo length and width)
    local lenLen = MathUtil.vector3Length(dhx, 0, dhz)
    local widLen = MathUtil.vector3Length(dwx, 0, dwz)
    if lenLen < 0.001 or widLen < 0.001 then
        return false
    end
    local axH = { x = dhx / lenLen, z = dhz / lenLen }
    local axW = { x = dwx / widLen, z = dwz / widLen }

    -- Grid dimensions (ceil so full silo fits)
    local rows = math.max(1, math.ceil(length / cellSize))
    local cols = math.max(1, math.ceil(width / cellSize))

    -- Build empty grid
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = {
                fillHeight = nil,    -- meters above terrain (EMA-smoothed)
                samples = 0,          -- count of samples written
                lastUpdate = 0,       -- ms timestamp of last sample
                target = nil,         -- target fill height (set by computeTargetTopography)
                isRamp = false,       -- true if this cell falls in the entry/exit ramp zone
            }
        end
    end

    siloAssistTopoMap.grid = grid
    siloAssistTopoMap.rows = rows
    siloAssistTopoMap.cols = cols
    siloAssistTopoMap.cellSize = cellSize
    siloAssistTopoMap.origin = { x = area.sx, z = area.sz }
    siloAssistTopoMap.axisH = axH
    siloAssistTopoMap.axisW = axW
    siloAssistTopoMap.length = length
    siloAssistTopoMap.width = width
    siloAssistTopoMap.siloRef = silo
    siloAssistTopoMap.areaRef = area
    siloAssistTopoMap.lastStats = {
        avg = 0, min = 0, max = 0, variance = 0,
        coveragePct = 0, cellsFilled = 0, cellsTotal = rows * cols,
        done = false,
    }

    siloAssistDebug.log("TopoMap", string.format(
        "init: rows=%d cols=%d cellSize=%.2f len=%.2f wid=%.2f origin=(%.1f,%.1f)",
        rows, cols, cellSize, length, width, area.sx, area.sz))
    return true
end

---------------------------------------------------------------------
-- Project world (x,z) to local grid coords (u, v) in meters.
-- u along length axis (0..length), v along width axis (0..width).
-- Returns u, v (may be outside 0..length/width if point outside silo).
---------------------------------------------------------------------
function siloAssistTopoMap.worldToLocal(x, z)
    local dx = x - siloAssistTopoMap.origin.x
    local dz = z - siloAssistTopoMap.origin.z
    local u = dx * siloAssistTopoMap.axisH.x + dz * siloAssistTopoMap.axisH.z
    local v = dx * siloAssistTopoMap.axisW.x + dz * siloAssistTopoMap.axisW.z
    return u, v
end

---------------------------------------------------------------------
-- Convert (u, v) in meters to grid indices (r, c). 1-based.
-- Returns r, c (clamped to grid if outside).
---------------------------------------------------------------------
function siloAssistTopoMap.localToCell(u, v)
    local r = math.floor(u / siloAssistTopoMap.cellSize) + 1
    local c = math.floor(v / siloAssistTopoMap.cellSize) + 1
    return r, c
end

---------------------------------------------------------------------
-- Convert grid (r, c) back to world (x, z). Returns center of cell.
---------------------------------------------------------------------
function siloAssistTopoMap.cellToWorld(r, c)
    local u = (r - 0.5) * siloAssistTopoMap.cellSize
    local v = (c - 0.5) * siloAssistTopoMap.cellSize
    local x = siloAssistTopoMap.origin.x
        + siloAssistTopoMap.axisH.x * u
        + siloAssistTopoMap.axisW.x * v
    local z = siloAssistTopoMap.origin.z
        + siloAssistTopoMap.axisH.z * u
        + siloAssistTopoMap.axisW.z * v
    return x, z
end

---------------------------------------------------------------------
-- Get cell at world (x, z). Returns cell or nil if outside grid.
---------------------------------------------------------------------
function siloAssistTopoMap.getCell(x, z)
    if siloAssistTopoMap.rows == 0 then
        return nil
    end
    local u, v = siloAssistTopoMap.worldToLocal(x, z)
    if u < 0 or v < 0 or u >= siloAssistTopoMap.length or v >= siloAssistTopoMap.width then
        return nil
    end
    local r, c = siloAssistTopoMap.localToCell(u, v)
    r = math.clamp(r, 1, siloAssistTopoMap.rows)
    c = math.clamp(c, 1, siloAssistTopoMap.cols)
    return siloAssistTopoMap.grid[r][c], r, c
end

---------------------------------------------------------------------
-- Check if a world (x, z) position falls in the silo entry/exit ramp zone.
-- Uses the same rampStart/rampEnd formula as siloAssistModePush:
--   rampStart = min(ENTRY_RAMP_METERS / siloLength, 0.5)
--   rampEnd   = max(1 - EXIT_RAMP_LENGTH / siloLength, 0.5)
-- Returns true if in ramp zone, false if in plateau, nil if outside silo or
-- no silo length available.
---------------------------------------------------------------------
function siloAssistTopoMap.isPointInRampZone(x, z)
    if siloAssistTopoMap.length <= 0 then
        return nil
    end
    local u, _ = siloAssistTopoMap.worldToLocal(x, z)
    if u < 0 or u >= siloAssistTopoMap.length then
        return nil
    end
    local progress = u / siloAssistTopoMap.length
    local rampStart = math.min(siloAssistConfig.ENTRY_RAMP_METERS / siloAssistTopoMap.length, 0.5)
    local rampEnd = math.max(1 - siloAssistConfig.EXIT_RAMP_LENGTH / siloAssistTopoMap.length, 0.5)
    return progress < rampStart or progress > rampEnd
end

---------------------------------------------------------------------
-- Sample a single world point into the grid.
-- Uses DensityMapHeightUtil; falls back to stagedFillHeight when nil
-- (inside BunkerSilo, DensityMap returns nil — known gotcha).
-- Applies EMA smoothing into the cell.
-- isRamp (optional): if given, sets cell.isRamp accordingly.
-- Returns the fill height written, or nil on failure.
---------------------------------------------------------------------
function siloAssistTopoMap.samplePoint(x, y, z, now, isRamp)
    if siloAssistTopoMap.rows == 0 then
        return nil
    end

    local cell, r, c = siloAssistTopoMap.getCell(x, z)
    if cell == nil then
        return nil
    end

    -- DensityMapHeightUtil returns surfaceHeight, fillHeightAboveTerrain
    local _, fillAbove = DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)
    local fillH = math.max(fillAbove or 0, 0)

    -- Fallback for points inside BunkerSilo where DensityMap returns 0/nil
    if fillH < 0.001 and siloAssistSiloDetector.stagedFillHeight > 0.001 then
        fillH = siloAssistSiloDetector.stagedFillHeight
    end

    -- EMA smoothing
    local ema = siloAssistConfig.TOPO_MAP_EMA
    if cell.fillHeight == nil or cell.samples == 0 then
        cell.fillHeight = fillH
    else
        cell.fillHeight = cell.fillHeight * (1 - ema) + fillH * ema
    end
    cell.samples = cell.samples + 1
    cell.lastUpdate = now or 0

    -- Mark ramp zone (caller can override; otherwise compute from position)
    if isRamp ~= nil then
        cell.isRamp = isRamp
    else
        local r2 = siloAssistTopoMap.isPointInRampZone(x, z)
        if r2 ~= nil then
            cell.isRamp = r2
        end
    end

    return fillH
end

---------------------------------------------------------------------
-- Coarse initial scan: sample a sparse grid (e.g. every 5m) once on
-- silo entry. Limits to ~40 DensityMap calls so it fits one frame.
---------------------------------------------------------------------
function siloAssistTopoMap.sampleCoarseGrid(stepM)
    if siloAssistTopoMap.rows == 0 then
        return
    end
    local step = math.max(stepM or 5.0, siloAssistTopoMap.cellSize)
    local now = getTime() * 1000
    local count = 0

    local u = step * 0.5
    while u < siloAssistTopoMap.length do
        local v = step * 0.5
        while v < siloAssistTopoMap.width do
            local x = siloAssistTopoMap.origin.x
                + siloAssistTopoMap.axisH.x * u
                + siloAssistTopoMap.axisW.x * v
            local z = siloAssistTopoMap.origin.z
                + siloAssistTopoMap.axisH.z * u
                + siloAssistTopoMap.axisW.z * v
            -- Y coordinate: use a high start (DensityMap only needs x,z)
            siloAssistTopoMap.samplePoint(x, 0, z, now)
            count = count + 1
            v = v + step
        end
        u = u + step
    end

    siloAssistDebug.log("TopoMap", string.format(
        "coarseScan: step=%.1f sampled=%d cells (%.0fx%.0f grid)",
        step, count, siloAssistTopoMap.rows, siloAssistTopoMap.cols))
end

---------------------------------------------------------------------
-- Update from sampleSurfaceAhead results (called every frame after
-- sampleSurfaceAhead). Writes CL+CR edge points into their grid cells.
-- surfaceSamples/surfaceSampleHeights are no longer used (S1-S5 removed);
-- they are kept as parameters for signature stability but ignored.
-- collisionSampleHeights entries now carry a `distance` field; the 1m slot
-- is EXCLUDED from the TopoMap (it sits on the silage hill in front of the
-- blade and would skew the persistent map). 1m is still used by
-- analyzeSurfaceProfile for preemptive lift, just not stored.
---------------------------------------------------------------------
function siloAssistTopoMap.updateFromSamples(
        surfaceSamples, surfaceSampleHeights,
        collisionSamples, collisionSampleHeights)

    if siloAssistTopoMap.rows == 0 then
        return
    end

    local now = getTime() * 1000
    local written = 0

    -- S1-S5 center points: no longer sampled (array empty). Loop kept as
    -- a no-op for compatibility; no work to do.

    -- CL+CR edge points. Skip the 1m slot (i==1) — it sits on the silage
    -- hill directly in front of the blade and would corrupt the map.
    if collisionSamples ~= nil and collisionSampleHeights ~= nil then
        for i = 1, math.min(#collisionSamples, #collisionSampleHeights) do
            if i > 1 then  -- skip 1m slot
                local cs = collisionSamples[i]
                local ch = collisionSampleHeights[i]
                if cs ~= nil and ch ~= nil then
                    -- Left
                    if cs.left ~= nil and #cs.left >= 3 and ch.leftFill ~= nil then
                        local isRampL = siloAssistTopoMap.isPointInRampZone(cs.left[1], cs.left[3])
                        siloAssistTopoMap.writeFillAt(cs.left[1], cs.left[3], ch.leftFill, now, isRampL)
                        written = written + 1
                    end
                    -- Right
                    if cs.right ~= nil and #cs.right >= 3 and ch.rightFill ~= nil then
                        local isRampR = siloAssistTopoMap.isPointInRampZone(cs.right[1], cs.right[3])
                        siloAssistTopoMap.writeFillAt(cs.right[1], cs.right[3], ch.rightFill, now, isRampR)
                        written = written + 1
                    end
                end
            end
        end
    end

    if written > 0 then
        siloAssistDebug.logThrottled("TopoMap", "update", string.format(
            "written=%d cellsFilled=%d/%d", written,
            siloAssistTopoMap.lastStats.cellsFilled or 0,
            siloAssistTopoMap.lastStats.cellsTotal or 0))
    end
end

---------------------------------------------------------------------
-- Write a pre-measured fill height into the cell at world (x, z).
-- Used by updateFromSamples for C1-C5 points (already measured).
-- isRamp (optional): if given, sets cell.isRamp accordingly.
---------------------------------------------------------------------
function siloAssistTopoMap.writeFillAt(x, z, fillH, now, isRamp)
    if siloAssistTopoMap.rows == 0 then
        return
    end
    local cell = siloAssistTopoMap.getCell(x, z)
    if cell == nil then
        return
    end
    fillH = math.max(fillH or 0, 0)
    local ema = siloAssistConfig.TOPO_MAP_EMA
    if cell.fillHeight == nil or cell.samples == 0 then
        cell.fillHeight = fillH
    else
        cell.fillHeight = cell.fillHeight * (1 - ema) + fillH * ema
    end
    cell.samples = cell.samples + 1
    cell.lastUpdate = now or 0

    -- Mark ramp zone (caller can override; otherwise compute from position)
    if isRamp ~= nil then
        cell.isRamp = isRamp
    else
        local r2 = siloAssistTopoMap.isPointInRampZone(x, z)
        if r2 ~= nil then
            cell.isRamp = r2
        end
    end
end

---------------------------------------------------------------------
-- Bilinear interpolation of fillHeight at (u, v) in meters.
-- Returns nil if any of the 4 surrounding cells is empty.
---------------------------------------------------------------------
function siloAssistTopoMap.getInterpolatedHeight(u, v)
    if siloAssistTopoMap.rows == 0 then
        return nil
    end

    local r = u / siloAssistTopoMap.cellSize
    local c = v / siloAssistTopoMap.cellSize
    local r0 = math.floor(r)
    local c0 = math.floor(c)
    local fr = r - r0
    local fc = c - c0

    local r1 = r0 + 1
    local c1 = c0 + 1

    -- 1-based grid indices
    local gr0 = math.clamp(r0 + 1, 1, siloAssistTopoMap.rows)
    local gr1 = math.clamp(r1 + 1, 1, siloAssistTopoMap.rows)
    local gc0 = math.clamp(c0 + 1, 1, siloAssistTopoMap.cols)
    local gc1 = math.clamp(c1 + 1, 1, siloAssistTopoMap.cols)

    local cell00 = siloAssistTopoMap.grid[gr0][gc0]
    local cell01 = siloAssistTopoMap.grid[gr0][gc1]
    local cell10 = siloAssistTopoMap.grid[gr1][gc0]
    local cell11 = siloAssistTopoMap.grid[gr1][gc1]

    if cell00.fillHeight == nil or cell01.fillHeight == nil
        or cell10.fillHeight == nil or cell11.fillHeight == nil then
        return nil
    end

    local h00 = cell00.fillHeight
    local h01 = cell01.fillHeight
    local h10 = cell10.fillHeight
    local h11 = cell11.fillHeight

    local h0 = h00 * (1 - fc) + h01 * fc
    local h1 = h10 * (1 - fc) + h11 * fc
    return h0 * (1 - fr) + h1 * fr
end

---------------------------------------------------------------------
-- Same as getInterpolatedHeight but for cell.target.
---------------------------------------------------------------------
function siloAssistTopoMap.getInterpolatedTarget(u, v)
    if siloAssistTopoMap.rows == 0 then
        return nil
    end

    local r = u / siloAssistTopoMap.cellSize
    local c = v / siloAssistTopoMap.cellSize
    local r0 = math.floor(r)
    local c0 = math.floor(c)
    local fr = r - r0
    local fc = c - c0

    local r1 = r0 + 1
    local c1 = c0 + 1

    local gr0 = math.clamp(r0 + 1, 1, siloAssistTopoMap.rows)
    local gr1 = math.clamp(r1 + 1, 1, siloAssistTopoMap.rows)
    local gc0 = math.clamp(c0 + 1, 1, siloAssistTopoMap.cols)
    local gc1 = math.clamp(c1 + 1, 1, siloAssistTopoMap.cols)

    local t00 = siloAssistTopoMap.grid[gr0][gc0].target
    local t01 = siloAssistTopoMap.grid[gr0][gc1].target
    local t10 = siloAssistTopoMap.grid[gr1][gc0].target
    local t11 = siloAssistTopoMap.grid[gr1][gc1].target

    if t00 == nil or t01 == nil or t10 == nil or t11 == nil then
        return nil
    end

    local h0 = t00 * (1 - fc) + t01 * fc
    local h1 = t10 * (1 - fc) + t11 * fc
    return h0 * (1 - fr) + h1 * fr
end

---------------------------------------------------------------------
-- Compute target topography for all cells.
-- mode = "push", "smooth", or "wedge"
-- For push/smooth: target = avg + offset (flat plateau)
-- For wedge:        target = baseHeight + (u/length) * wedgeHeight + offset
--                  (rising keil shape from silo entrance to end)
-- opts may contain: offset (m), wedgeHeight (m)
-- Writes cell.target for every cell that has samples.
---------------------------------------------------------------------
function siloAssistTopoMap.computeTargetTopography(mode, opts)
    if siloAssistTopoMap.rows == 0 then
        return
    end
    opts = opts or {}
    local offset = opts.offset or 0
    local stats = siloAssistTopoMap.computeStats()
    -- Use plateau average (excludes ramp cells) as the meaningful "Soll" height.
    -- Falls back to overall avg when no plateau cells exist yet (e.g. only ramp zone sampled).
    local avg = stats.avgPlateau
    if avg == 0 and stats.cellsPlateau == 0 and stats.cellsFilled > 0 then
        avg = stats.avgRamp  -- better than 0 when only ramp zone sampled so far
    end

    if mode == "wedge" then
        local wedgeHeight = opts.wedgeHeight or siloAssistConfig.WEDGE_MIN_END_HEIGHT
        local baseHeight = math.max(avg - wedgeHeight, 0)
        for r = 1, siloAssistTopoMap.rows do
            local u = (r - 0.5) * siloAssistTopoMap.cellSize
            local frac = u / siloAssistTopoMap.length
            local cellTarget = baseHeight + frac * wedgeHeight + offset
            for c = 1, siloAssistTopoMap.cols do
                local cell = siloAssistTopoMap.grid[r][c]
                if cell.fillHeight ~= nil then
                    cell.target = cellTarget
                end
            end
        end
    else
        -- push/smooth (default): flat at plateau avg + offset for ALL cells
        -- (plateau + ramp identical). Legacy ramp logic in HeightController
        -- controls the actual entry/exit ramp shape; TopoMap just provides
        -- a flat "Soll" so the plateau gets smoothed toward an even surface.
        local flatTarget = avg + offset
        for r = 1, siloAssistTopoMap.rows do
            for c = 1, siloAssistTopoMap.cols do
                local cell = siloAssistTopoMap.grid[r][c]
                if cell.fillHeight ~= nil then
                    cell.target = flatTarget
                end
            end
        end
    end

    siloAssistDebug.log("TopoMap", string.format(
        "computeTarget mode=%s avgP=%.3f avgR=%.3f offset=%.3f cellsP=%d cellsR=%d",
        mode, stats.avgPlateau, stats.avgRamp, offset,
        stats.cellsPlateau, stats.cellsRamp))
end

---------------------------------------------------------------------
-- Compute statistics across all filled cells.
-- Plateau cells (isRamp == false) and ramp cells (isRamp == true) are
-- tracked separately. The "eben" condition uses plateau variance only,
-- since ramp cells are intentionally uneven (they form the entry/exit ramp).
-- Updates lastStats and returns it.
---------------------------------------------------------------------
function siloAssistTopoMap.computeStats()
    local stats = siloAssistTopoMap.lastStats
    if siloAssistTopoMap.rows == 0 then
        stats.avg = 0
        stats.avgPlateau = 0
        stats.avgRamp = 0
        stats.min = 0
        stats.max = 0
        stats.variance = 0
        stats.variancePlateau = 0
        stats.coveragePct = 0
        stats.cellsFilled = 0
        stats.cellsPlateau = 0
        stats.cellsRamp = 0
        stats.cellsTotal = 0
        stats.done = false
        return stats
    end

    local total = siloAssistTopoMap.rows * siloAssistTopoMap.cols

    -- Pass 1: sum / min / max / count for plateau and ramp separately
    local sumP, countP, minP, maxP = 0, 0, math.huge, -math.huge
    local sumR, countR, minR, maxR = 0, 0, math.huge, -math.huge
    for r = 1, siloAssistTopoMap.rows do
        for c = 1, siloAssistTopoMap.cols do
            local cell = siloAssistTopoMap.grid[r][c]
            local h = cell.fillHeight
            if h ~= nil then
                if cell.isRamp then
                    sumR = sumR + h
                    countR = countR + 1
                    if h < minR then minR = h end
                    if h > maxR then maxR = h end
                else
                    sumP = sumP + h
                    countP = countP + 1
                    if h < minP then minP = h end
                    if h > maxP then maxP = h end
                end
            end
        end
    end

    local count = countP + countR
    if count == 0 then
        stats.avg = 0
        stats.avgPlateau = 0
        stats.avgRamp = 0
        stats.min = 0
        stats.max = 0
        stats.variance = 0
        stats.variancePlateau = 0
        stats.coveragePct = 0
        stats.cellsFilled = 0
        stats.cellsPlateau = 0
        stats.cellsRamp = 0
        stats.cellsTotal = total
        stats.done = false
        return stats
    end

    local avgP = countP > 0 and (sumP / countP) or 0
    local avgR = countR > 0 and (sumR / countR) or 0
    local avgAll = (sumP + sumR) / count

    -- Pass 2: variance over plateau cells only (ramp cells are intentionally uneven)
    local varSumP = 0
    for r = 1, siloAssistTopoMap.rows do
        for c = 1, siloAssistTopoMap.cols do
            local cell = siloAssistTopoMap.grid[r][c]
            local h = cell.fillHeight
            if h ~= nil and not cell.isRamp then
                local d = h - avgP
                varSumP = varSumP + d * d
            end
        end
    end
    local varianceP = countP > 0 and (varSumP / countP) or 0

    -- Overall variance (for backwards compat in HUD that references .variance)
    local varSumAll = 0
    for r = 1, siloAssistTopoMap.rows do
        for c = 1, siloAssistTopoMap.cols do
            local cell = siloAssistTopoMap.grid[r][c]
            local h = cell.fillHeight
            if h ~= nil then
                local d = h - avgAll
                varSumAll = varSumAll + d * d
            end
        end
    end
    local varianceAll = varSumAll / count

    -- Overall min/max (across plateau + ramp) for HUD info
    local minAll = math.min(minP == math.huge and 0 or minP, minR == math.huge and 0 or minR)
    local maxAll = math.max(maxP == -math.huge and 0 or maxP, maxR == -math.huge and 0 or maxR)

    stats.avg = avgP  -- avg now equals plateau avg (the meaningful "Soll")
    stats.avgPlateau = avgP
    stats.avgRamp = avgR
    stats.min = minAll
    stats.max = maxAll
    stats.variance = varianceAll      -- overall (kept for backwards compat)
    stats.variancePlateau = varianceP  -- plateau-only (used for "eben")
    stats.coveragePct = (count / total) * 100
    stats.cellsFilled = count
    stats.cellsPlateau = countP
    stats.cellsRamp = countR
    stats.cellsTotal = total
    -- "eben" requires plateau cells to exist AND be below tolerance variance.
    -- If no plateau cells (countP == 0), done stays false.
    stats.done = countP > 0 and varianceP < (siloAssistConfig.TOPO_MAP_DONE_TOLERANCE ^ 2)

    return stats
end

---------------------------------------------------------------------
-- Get correction at world (x, z): interpolated target - interpolated height.
-- Returns:
--   correction, isRamp  -- correction in meters, isRamp = true if the
--                          queried cell is in the ramp zone (caller may
--                          damp the gain in that case)
--   nil, nil             -- insufficient data
-- Used by height controller (Phase 3+).
---------------------------------------------------------------------
function siloAssistTopoMap.getCorrectionAt(x, z)
    if siloAssistTopoMap.rows == 0 then
        return nil, nil
    end
    local u, v = siloAssistTopoMap.worldToLocal(x, z)
    if u < 0 or v < 0 or u >= siloAssistTopoMap.length or v >= siloAssistTopoMap.width then
        return nil, nil
    end
    local target = siloAssistTopoMap.getInterpolatedTarget(u, v)
    local height = siloAssistTopoMap.getInterpolatedHeight(u, v)
    if target == nil or height == nil then
        return nil, nil
    end

    -- Determine isRamp from the cell at the query position
    local cell = siloAssistTopoMap.getCell(x, z)
    local isRamp = cell ~= nil and cell.isRamp or false

    return target - height, isRamp
end

---------------------------------------------------------------------
-- Get interpolated height at world (x, z). Wrapper for external use.
---------------------------------------------------------------------
function siloAssistTopoMap.getHeightAt(x, z)
    if siloAssistTopoMap.rows == 0 then
        return nil
    end
    local u, v = siloAssistTopoMap.worldToLocal(x, z)
    if u < 0 or v < 0 or u >= siloAssistTopoMap.length or v >= siloAssistTopoMap.width then
        return nil
    end
    return siloAssistTopoMap.getInterpolatedHeight(u, v)
end

---------------------------------------------------------------------
-- Update "done" (eben) state: requires variance below tolerance for
-- a sustained hold period (TOPO_MAP_DONE_HOLD_SEC). Also requires a
-- minimum coverage so "eben" is not triggered on a near-empty map.
-- Call every frame with dt (ms).
---------------------------------------------------------------------
function siloAssistTopoMap.updateDoneState(dt)
    if siloAssistTopoMap.rows == 0 then
        siloAssistTopoMap.doneHoldTimer = 0
        siloAssistTopoMap.doneConfirmed = false
        return
    end

    local stats = siloAssistTopoMap.lastStats
    local tolerance = siloAssistConfig.TOPO_MAP_DONE_TOLERANCE
    local minCoverage = 50  -- % der Zellen muessen gefuellt sein (gesamt)
    local minPlateauCells = 10  -- absolut minimum an Plateau-Zellen

    -- "eben" requires plateau variance below tolerance AND enough plateau
    -- cells AND enough overall coverage. Ramp variance is ignored.
    if stats.cellsPlateau >= minPlateauCells
        and stats.variancePlateau < (tolerance ^ 2)
        and stats.coveragePct >= minCoverage then
        siloAssistTopoMap.doneHoldTimer = siloAssistTopoMap.doneHoldTimer + dt
        local holdMs = siloAssistConfig.TOPO_MAP_DONE_HOLD_SEC * 1000
        if siloAssistTopoMap.doneHoldTimer >= holdMs then
            if not siloAssistTopoMap.doneConfirmed then
                siloAssistDebug.log("TopoMap", string.format(
                    "EBEN bestaetigt: varP=%.4f tol=%.4f cov=%.0f%% cellsP=%d hold=%.1fs",
                    stats.variancePlateau, tolerance ^ 2, stats.coveragePct,
                    stats.cellsPlateau, siloAssistTopoMap.doneHoldTimer / 1000))
            end
            siloAssistTopoMap.doneConfirmed = true
        end
    else
        if siloAssistTopoMap.doneConfirmed then
            siloAssistDebug.log("TopoMap", "EBEN zurueckgezogen: varP/coverage/cellsP ausser Toleranz")
        end
        siloAssistTopoMap.doneHoldTimer = 0
        siloAssistTopoMap.doneConfirmed = false
    end
end