--====================================================================
-- SiloAssist - Wedge Mode (Keilsilo)
-- Responsibility: Calculate target height for wedge mode.
--
-- Wedge mode creates a RISING ramp from entry to exit, computed from
-- the actual fill volume:
--   Volume = (startHeight + endHeight) / 2 * length * width
--   => endHeight = 2 * fillLevel/density/(L*W) - startHeight
--
-- The wedge grows naturally as more silage is added — no pass counting.
-- Entry is always at WEDGE_MIN_END_HEIGHT (0.1m) above ground, fixed.
--====================================================================

siloAssistModeWedge = {}

---------------------------------------------------------------------
-- Calculate target height above ground for wedge mode.
-- Rising ramp computed from fill volume:
--   start = WEDGE_MIN_END_HEIGHT (0.1m, fixed at entry)
--   end   = derived from wedge volume formula, clamped [MIN, MAX]
--   target= start + offset + progress * (end - start)
-- WEDGE_END_EXTRA is added as a separate ramp (0→extra over length)
-- to steepen the slope beyond the pure volume calculation.
---------------------------------------------------------------------
function siloAssistModeWedge.calcTarget(progress, fillHeight, effectiveOffset)
    local config = siloAssistConfig
    local hc = siloAssistHeightController
    local sd = siloAssistSiloDetector

    local length = math.max(sd.siloLength or 1, 1)
    local width = math.max(sd.siloWidth or 1, 1)
    local fillLevel = sd.siloFillLevel or 0

    local avgFillHeight = fillLevel / config.DENSITY_LITERS_PER_CBM / (length * width)

    local startHeight = config.WEDGE_MIN_END_HEIGHT
    local endHeight = 2 * avgFillHeight - startHeight
    endHeight = math.max(config.WEDGE_MIN_END_HEIGHT, endHeight)

    local target
    if endHeight > config.WEDGE_MAX_HEIGHT then
        -- Shortened wedge: keep 4.0m at exit wall, wedge compressed by 1.0m from exit side
        endHeight = config.WEDGE_MAX_HEIGHT
        local wedgeFrac = math.max(1.0 - 1.0 / length, 0.5)
        if progress < wedgeFrac then
            local relProgress = progress / wedgeFrac
            target = startHeight + effectiveOffset + relProgress * (endHeight - startHeight)
        else
            -- Last 1.0m before exit wall: flat at max height
            target = endHeight + effectiveOffset
        end
    else
        -- Full-length wedge with extra steepening
        target = startHeight + effectiveOffset + progress * (endHeight - startHeight) + progress * config.WEDGE_END_EXTRA
    end

    target = target + hc.exitRampHeightAdd
    return target
end

---------------------------------------------------------------------
-- Base tilt angle for wedge mode (degrees).
-- Reduced tilt (5) compared to push/smooth (10) for better
-- wedge shaping with less aggressive blade angle.
---------------------------------------------------------------------
function siloAssistModeWedge.getBaseTiltDeg()
    return siloAssistConfig.WEDGE_TILT_DEG
end
