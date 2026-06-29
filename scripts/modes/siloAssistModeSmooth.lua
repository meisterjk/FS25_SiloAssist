--====================================================================
-- SiloAssist - Smooth Mode (Glätten)
-- Responsibility: Collect smooth-specific parameters and delegate
-- to the shared calculation method in heightController.
--====================================================================

siloAssistModeSmooth = {}

---------------------------------------------------------------------
-- Calculate target height above ground for smooth mode.
-- Uses average of far sensors with fixed offset. No ramp.
---------------------------------------------------------------------
function siloAssistModeSmooth.calcTarget(progress, fillHeight, effectiveOffset)
    local config = siloAssistConfig
    local hc = siloAssistHeightController

    local ch = hc.collisionSampleHeights
    local sum, count = 0, 0
    if ch ~= nil and #ch >= 5 then
        for i = 3, 5 do
            local entry = ch[i]
            if entry ~= nil then
                if entry.leftFill  ~= nil then sum = sum + entry.leftFill;  count = count + 1 end
                if entry.rightFill ~= nil then sum = sum + entry.rightFill; count = count + 1 end
                if entry.midFill   ~= nil then sum = sum + entry.midFill;   count = count + 1 end
            end
        end
    end

    local avg
    if count > 0 then
        avg = sum / count
    else
        avg = fillHeight
    end

    hc.lastEffectiveRampStart = 0
    hc.lastEffectiveRampEnd = 1

    return avg + config.SMOOTH_HEIGHT_ADD + effectiveOffset + hc.exitRampHeightAdd
end

---------------------------------------------------------------------
-- Base tilt angle for smooth mode (degrees).
---------------------------------------------------------------------
function siloAssistModeSmooth.getBaseTiltDeg()
    return siloAssistConfig.SHIELD_TILT_DEG
end