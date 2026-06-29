--====================================================================
-- SiloAssist - Push Mode (Schieben)
-- Responsibility: Collect push-specific parameters and delegate
-- to the shared calculation method in heightController.
--====================================================================

siloAssistModePush = {}

---------------------------------------------------------------------
-- Calculate target height above ground for push mode.
-- Uses scanned average fill height with entry ramp.
---------------------------------------------------------------------
function siloAssistModePush.calcTarget(progress, fillHeight, effectiveOffset)
    local config = siloAssistConfig
    local hc = siloAssistHeightController

    local avg = hc.pushScanAvgHeight
    if avg == nil then
        avg = fillHeight
    end

    local densityH = math.max(
        siloAssistSiloDetector.densityFillHeightAtBlade or 0,
        siloAssistSiloDetector.densityFillHeightAtVehicle or 0)
    local offsetBase = math.max(avg, densityH)
    local autoOffset = offsetBase * config.AUTO_FILL_OFFSET_FACTOR
    local heightOffset = siloAssistVehicleState.getHeightOffset()
    local pushEffectiveOffset = math.max(heightOffset + autoOffset, config.MIN_HEIGHT_ABOVE_FILL)

    local siloLength = math.max(siloAssistSiloDetector.siloLength or 1, 1)
    local rampStart = math.min(config.ENTRY_RAMP_METERS / siloLength, 0.5)

    hc.lastEffectiveRampStart = rampStart
    hc.lastEffectiveRampEnd = 1

    local target = siloAssistHeightController.calcRampTarget(
        avg,
        pushEffectiveOffset,
        progress,
        rampStart,
        1,
        0
    )

    target = target + hc.exitRampHeightAdd
    return target
end

---------------------------------------------------------------------
-- Base tilt angle for push mode (degrees).
---------------------------------------------------------------------
function siloAssistModePush.getBaseTiltDeg()
    return siloAssistConfig.SHIELD_TILT_DEG
end