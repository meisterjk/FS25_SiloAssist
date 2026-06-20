--====================================================================
-- SiloAssist - Tilt Controller
-- Responsibility: keep the leveler blade horizontal by compensating
-- for vehicle pitch. Separate from height control so it can be
-- debugged and tuned independently.
-- Supports: AttacherJointControl (3-point) and Cylindered (wheel/front loader)
--====================================================================

siloAssistTiltController = {}

siloAssistTiltController.lastAppliedTiltDeg = 0
siloAssistTiltController.lastToolPitchDeg = nil
siloAssistTiltController.saturationTilt = 0
siloAssistTiltController.forceTiltActive = false
siloAssistTiltController.forceTiltDeg = 0

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistTiltController.reset()
    siloAssistTiltController.lastAppliedTiltDeg = 0
    siloAssistTiltController.lastToolPitchDeg = nil
    siloAssistTiltController.saturationTilt = 0
    siloAssistTiltController.forceTiltActive = false
    siloAssistTiltController.forceTiltDeg = 0
end

---------------------------------------------------------------------
-- Update: called every frame when assist is active
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Force tilt override (used for entry/exit mode)
---------------------------------------------------------------------
function siloAssistTiltController.forceTilt(vehicle, targetDeg)
    siloAssistTiltController.forceTiltActive = true
    siloAssistTiltController.forceTiltDeg = targetDeg
    siloAssistTiltController.lastAppliedTiltDeg = targetDeg
    siloAssistDebug.log("Tilt", string.format("forceTilt: %.1f°", targetDeg))
    if siloAssistToolDetection.controlType == "attacherJointControl" then
        siloAssistTiltController.applyTilt3Point(siloAssistToolDetection.toolObject, targetDeg)
    elseif siloAssistToolDetection.controlType == "cylindered" then
        siloAssistTiltController.applyTiltCylindered(targetDeg)
    end
end

function siloAssistTiltController.clearForceTilt()
    if siloAssistTiltController.forceTiltActive then
        siloAssistDebug.log("Tilt", "clearForceTilt")
    end
    siloAssistTiltController.forceTiltActive = false
    siloAssistTiltController.forceTiltDeg = 0
end

function siloAssistTiltController.update(vehicle, dt)
    -- Reversing blade: always reset tilt to 0 regardless of forceTilt
    local shouldRaiseTilt = (siloAssistToolDetection.isFrontAttached == siloAssistState.isReversing)
    if shouldRaiseTilt and siloAssistToolDetection.toolType ~= "shovel" then
        siloAssistTiltController.saturationTilt = 0
        siloAssistTiltController.clearForceTilt()
        siloAssistTiltController.lastAppliedTiltDeg = 0
        if siloAssistToolDetection.controlType == "attacherJointControl" then
            siloAssistTiltController.applyTilt3Point(siloAssistToolDetection.toolObject, 0)
        elseif siloAssistToolDetection.controlType == "cylindered" then
            siloAssistTiltController.applyTiltCylindered(0)
        end
        return
    end

    -- Force tilt active: re-apply every frame and skip normal logic
    if siloAssistTiltController.forceTiltActive then
        local deg = siloAssistTiltController.forceTiltDeg
        if siloAssistToolDetection.controlType == "attacherJointControl" then
            siloAssistTiltController.applyTilt3Point(siloAssistToolDetection.toolObject, deg)
        elseif siloAssistToolDetection.controlType == "cylindered" then
            siloAssistTiltController.applyTiltCylindered(deg)
        end
        return
    end

    local config = siloAssistConfig
    local vehiclePitchDeg = siloAssistHeightController.vehiclePitchDeg or 0
    local pitchFactor = siloAssistToolDetection.isFrontAttached and 1 or -1

    -- Auto-tilt: degrees = fill height * AUTO_TILT_FACTOR (e.g. 2.5m * 4 = 10°)
    local currentStagedFill = siloAssistSiloDetector.stagedFillHeight or 0
    local autoTilt = currentStagedFill * config.AUTO_TILT_FACTOR

    -- Saturation tilt: alpha at limit but height error remains
    local isSaturated = false
    if siloAssistToolDetection.controlType == "attacherJointControl" then
        isSaturated = siloAssistHeightController.alphaAtUpperLimit
    end
    local heightDiff = siloAssistHeightController.lastHeightDiff or 0

    if isSaturated and math.abs(heightDiff) > 0.001 then
        local targetSat = heightDiff * config.TILT_HEIGHT_GAIN
        targetSat = math.clamp(targetSat, -config.SATURATION_MAX, config.SATURATION_MAX)
        siloAssistTiltController.saturationTilt = targetSat
    else
        local decay = config.SATURATION_DECAY_RATE * dt
        local currentSat = siloAssistTiltController.saturationTilt
        if math.abs(currentSat) < decay then
            siloAssistTiltController.saturationTilt = 0
        else
            local sign = currentSat > 0 and 1 or -1
            siloAssistTiltController.saturationTilt = currentSat - sign * decay
        end
    end

    siloAssistDebug.logThrottled("Tilt", "calc", string.format(
        "stagedFill=%.2f autoTilt=%.1f satTilt=%.1f isSat=%s hDiff=%.3f",
        currentStagedFill, autoTilt, siloAssistTiltController.saturationTilt,
        tostring(isSaturated), heightDiff
    ))

    local targetTiltDeg = config.SHIELD_TILT_DEG + siloAssistVehicleState.getTiltOffset()
        + autoTilt + vehiclePitchDeg * pitchFactor + siloAssistTiltController.saturationTilt
    targetTiltDeg = math.clamp(targetTiltDeg, config.TILT_MIN, config.TILT_MAX)

    local hysteresis = config.SHIELD_TILT_HYSTERESIS_DEG
    local lastTilt = siloAssistTiltController.lastAppliedTiltDeg

    if math.abs(targetTiltDeg - lastTilt) < hysteresis then
        siloAssistDebug.logThrottled("Tilt", "skip", string.format(
            "SKIP: target=%.2f last=%.2f diff=%.2f < hyst=%.2f",
            targetTiltDeg, lastTilt, math.abs(targetTiltDeg - lastTilt), hysteresis
        ))
        return
    end

    siloAssistDebug.log("Tilt", string.format(
        "APPLY: vehPitch=%.2f pitchFac=%d isFront=%s target=%.2f last=%.2f autoTilt=%.1f satTilt=%.1f ctrl=%s",
        vehiclePitchDeg, pitchFactor, tostring(siloAssistToolDetection.isFrontAttached),
        targetTiltDeg, lastTilt, autoTilt, siloAssistTiltController.saturationTilt,
        tostring(siloAssistToolDetection.controlType)
    ))

    siloAssistTiltController.lastAppliedTiltDeg = targetTiltDeg

    if siloAssistToolDetection.controlType == "attacherJointControl" then
        siloAssistTiltController.applyTilt3Point(siloAssistToolDetection.toolObject, targetTiltDeg)
    elseif siloAssistToolDetection.controlType == "cylindered" then
        siloAssistTiltController.applyTiltCylindered(targetTiltDeg)
    end
end

---------------------------------------------------------------------
-- Tilt for AttacherJointControl (3-point hitch)
-- Sets rotation offsets directly AND syncs tiltController.moveAlpha
-- so the game's damping doesn't override our tilt.
---------------------------------------------------------------------
function siloAssistTiltController.applyTilt3Point(toolObject, targetAngleDeg)
    if toolObject == nil or toolObject.spec_attacherJointControl == nil then
        return
    end
    local spec = toolObject.spec_attacherJointControl
    if spec.jointDesc == nil then
        return
    end

    local jointDesc = spec.jointDesc
    if jointDesc.upperRotationOffsetBackup == nil or jointDesc.lowerRotationOffsetBackup == nil then
        return
    end

    local maxTiltAngle = spec.maxTiltAngle
    if maxTiltAngle == nil or maxTiltAngle <= 0 then
        maxTiltAngle = math.rad(30)
    end

    local targetAngle = math.clamp(math.rad(targetAngleDeg), -maxTiltAngle, maxTiltAngle)

    jointDesc.upperRotationOffset = (jointDesc.upperRotationOffsetBackup or 0) - targetAngle
    jointDesc.lowerRotationOffset = (jointDesc.lowerRotationOffsetBackup or 0) - targetAngle

    if spec.tiltController ~= nil then
        local maxTiltDeg = math.deg(maxTiltAngle)
        local targetMoveAlpha = 0.5 - (targetAngleDeg / maxTiltDeg) * 0.5
        targetMoveAlpha = math.clamp(targetMoveAlpha, 0, 1)
        spec.tiltController.moveAlpha = targetMoveAlpha
        spec.tiltController.moveAlphaLastManual = targetMoveAlpha
        spec.tiltController.moveAlphaSent = targetMoveAlpha

        siloAssistDebug.log("Tilt", string.format(
            "3PT: targetDeg=%.2f rad=%.4f maxRad=%.4f moveAlpha=%.4f upperOff=%.4f lowerOff=%.4f",
            targetAngleDeg, targetAngle, maxTiltAngle, targetMoveAlpha,
            jointDesc.upperRotationOffset, jointDesc.lowerRotationOffset
        ))
    end
end

---------------------------------------------------------------------
-- Tilt for Cylindered (wheel loader / front loader)
---------------------------------------------------------------------
function siloAssistTiltController.applyTiltCylindered(targetAngleDeg)
    if siloAssistToolDetection.dumpToolIndex == nil or siloAssistToolDetection.cylinderedVehicle == nil then
        return
    end
    local tiltValue = 0
    if targetAngleDeg > 0.5 then
        tiltValue = -1
    elseif targetAngleDeg < -0.5 then
        tiltValue = 1
    end
    siloAssistDebug.log("Tilt", string.format(
        "CYL: targetDeg=%.2f tiltVal=%d dumpIx=%s",
        targetAngleDeg, tiltValue, tostring(siloAssistToolDetection.dumpToolIndex)
    ))
    Cylindered.actionEventInput(
        siloAssistToolDetection.cylinderedVehicle,
        "",
        tiltValue,
        siloAssistToolDetection.dumpToolIndex,
        true
    )
end

---------------------------------------------------------------------
-- Reset tilt to neutral (used in raiseBlade)
---------------------------------------------------------------------
function siloAssistTiltController.resetTilt()
    siloAssistDebug.log("Tilt", "resetTilt: ctrl=" .. tostring(siloAssistToolDetection.controlType))
    siloAssistTiltController.lastAppliedTiltDeg = 0

    if siloAssistToolDetection.controlType == "attacherJointControl" then
        local toolObject = siloAssistToolDetection.toolObject
        if toolObject ~= nil and toolObject.spec_attacherJointControl ~= nil then
            local spec = toolObject.spec_attacherJointControl
            if spec.jointDesc ~= nil then
                if spec.jointDesc.upperRotationOffsetBackup ~= nil then
                    spec.jointDesc.upperRotationOffset = spec.jointDesc.upperRotationOffsetBackup
                    spec.jointDesc.lowerRotationOffset = spec.jointDesc.lowerRotationOffsetBackup
                end
                if spec.tiltController ~= nil then
                    spec.tiltController.moveAlpha = 0.5
                    spec.tiltController.moveAlphaLastManual = 0.5
                    spec.tiltController.moveAlphaSent = 0.5
                end
            end
        end
    elseif siloAssistToolDetection.controlType == "cylindered" then
        if siloAssistToolDetection.dumpToolIndex ~= nil and siloAssistToolDetection.cylinderedVehicle ~= nil then
            Cylindered.actionEventInput(
                siloAssistToolDetection.cylinderedVehicle,
                "",
                0,
                siloAssistToolDetection.dumpToolIndex,
                true
            )
        end
    end
end

---------------------------------------------------------------------
-- Full retract tilt: blade tilted maximally backward (for deactivate)
---------------------------------------------------------------------
function siloAssistTiltController.fullRetractTilt()
    local targetDeg = siloAssistConfig.TILT_MAX
    siloAssistDebug.log("Tilt", "fullRetractTilt: target=" .. tostring(targetDeg) .. " ctrl=" .. tostring(siloAssistToolDetection.controlType))
    siloAssistTiltController.lastAppliedTiltDeg = targetDeg

    if siloAssistToolDetection.controlType == "attacherJointControl" then
        siloAssistTiltController.applyTilt3Point(siloAssistToolDetection.toolObject, targetDeg)
    elseif siloAssistToolDetection.controlType == "cylindered" then
        siloAssistTiltController.applyTiltCylindered(targetDeg)
    end
end