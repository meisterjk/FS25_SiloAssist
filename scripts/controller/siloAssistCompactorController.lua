--====================================================================
-- SiloAssist - Compactor Controller
-- Responsibility: lower/raise compactor implements in the silo.
-- Active when compactorEnabled=true and compactorTool is set.
-- Lowers implement when in silo, raises when leaving.
--
-- DESIGN: Key-simulation approach.
-- Instead of setting moveAlpha directly every frame, we simulate
-- the game's own LOWER_IMPLEMENT action:
--   - AJC (AttacherJointControl): set heightTargetAlpha once, game interpolates
--   - AttacherJoints (3-point): call setJointMoveDown() once, engine handles
--   - Cylindered: call actionEventInput() once (already one-shot)
-- No per-frame override needed — the game holds the setpoint.
--====================================================================

siloAssistCompactorController = {}

siloAssistCompactorController.isLowered = false
siloAssistCompactorController.lowerAlpha = 1.0
siloAssistCompactorController.upperAlpha = 0.0

siloAssistCompactorController._controlPath = nil

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistCompactorController.reset()
    siloAssistCompactorController.isLowered = false
    siloAssistCompactorController.lowerAlpha = 1.0
    siloAssistCompactorController.upperAlpha = 0.0
    siloAssistCompactorController._controlPath = nil
end

---------------------------------------------------------------------
-- Lower implement: one-shot key-simulation
---------------------------------------------------------------------
function siloAssistCompactorController.lowerImplement(vehicle)
    if vehicle == nil then return end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
    local path = siloAssistCompactorController._controlPath
        or siloAssistToolDetection.compactorControlPath

    if path == "attacherJointControl" then
        if rootVehicle.spec_attacherJointControl ~= nil then
            rootVehicle.spec_attacherJointControl.heightTargetAlpha = siloAssistCompactorController.lowerAlpha
            siloAssistDebug.log("Compactor", string.format(
                "lower: AJC heightTargetAlpha=%.3f", siloAssistCompactorController.lowerAlpha))
        end

    elseif path == "implementAJC" then
        local t = siloAssistToolDetection.compactorTool
        if t ~= nil and t.spec_attacherJointControl ~= nil and t.spec_attacherJointControl.jointDesc ~= nil then
            t.spec_attacherJointControl.heightTargetAlpha = siloAssistCompactorController.lowerAlpha
            siloAssistDebug.log("Compactor", string.format(
                "lower: Impl AJC heightTargetAlpha=%.3f", siloAssistCompactorController.lowerAlpha))
        end

    elseif path == "attacherJoints" then
        local jdx = siloAssistToolDetection.compactorJointDescIndex
        if jdx ~= nil then
            rootVehicle:setJointMoveDown(jdx, true, false)
            siloAssistDebug.log("Compactor", string.format(
                "lower: setJointMoveDown(jdx=%d, true)", jdx))
        end

    elseif path == "cylindered" then
        local armIx = siloAssistToolDetection.compactorArmToolIndex
        local cylVeh = siloAssistToolDetection.compactorCylinderedVehicle
            or siloAssistToolDetection.compactorTool or vehicle
        if armIx ~= nil then
            Cylindered.actionEventInput(cylVeh, "", 1, armIx, true)
            siloAssistDebug.log("Compactor", string.format(
                "lower: Cylindered armIx=%d input=+1", armIx))
        end
    end

    siloAssistCompactorController.isLowered = true
end

---------------------------------------------------------------------
-- Raise implement: one-shot key-simulation
---------------------------------------------------------------------
function siloAssistCompactorController.raiseImplement(vehicle)
    if vehicle == nil then return end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
    local path = siloAssistCompactorController._controlPath
        or siloAssistToolDetection.compactorControlPath

    if path == "attacherJointControl" then
        if rootVehicle.spec_attacherJointControl ~= nil then
            rootVehicle.spec_attacherJointControl.heightTargetAlpha = siloAssistCompactorController.upperAlpha
            siloAssistDebug.log("Compactor", string.format(
                "raise: AJC heightTargetAlpha=%.3f", siloAssistCompactorController.upperAlpha))
        end

    elseif path == "implementAJC" then
        local t = siloAssistToolDetection.compactorTool
        if t ~= nil and t.spec_attacherJointControl ~= nil and t.spec_attacherJointControl.jointDesc ~= nil then
            t.spec_attacherJointControl.heightTargetAlpha = siloAssistCompactorController.upperAlpha
            siloAssistDebug.log("Compactor", string.format(
                "raise: Impl AJC heightTargetAlpha=%.3f", siloAssistCompactorController.upperAlpha))
        end

    elseif path == "attacherJoints" then
        local jdx = siloAssistToolDetection.compactorJointDescIndex
        if jdx ~= nil then
            rootVehicle:setJointMoveDown(jdx, false, false)
            siloAssistDebug.log("Compactor", string.format(
                "raise: setJointMoveDown(jdx=%d, false)", jdx))
        end

    elseif path == "cylindered" then
        local armIx = siloAssistToolDetection.compactorArmToolIndex
        local cylVeh = siloAssistToolDetection.compactorCylinderedVehicle
            or siloAssistToolDetection.compactorTool or vehicle
        if armIx ~= nil then
            Cylindered.actionEventInput(cylVeh, "", -1, armIx, true)
            siloAssistDebug.log("Compactor", string.format(
                "raise: Cylindered armIx=%d input=-1", armIx))
        end
    end

    siloAssistCompactorController.isLowered = false
end

---------------------------------------------------------------------
-- Detect control path (fallback if not set by initCompactorTool)
---------------------------------------------------------------------
function siloAssistCompactorController.detectControlPath(vehicle)
    if vehicle == nil then return nil end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
    local compactorTool = siloAssistToolDetection.compactorTool

    -- Use the path already detected by initCompactorTool
    if siloAssistToolDetection.compactorControlPath ~= nil then
        siloAssistCompactorController._controlPath = siloAssistToolDetection.compactorControlPath
        return siloAssistToolDetection.compactorControlPath
    end

    -- Fallback: find the attacher joint on the tractor
    if compactorTool ~= nil and rootVehicle.spec_attacherJoints ~= nil
        and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
            if joint.moveAttacherJointObject == compactorTool then
                siloAssistCompactorController.lowerAlpha = joint.lowerAlpha or 1.0
                siloAssistCompactorController.upperAlpha = joint.upperAlpha or 0.0
                local hasAJC = rootVehicle.spec_attacherJointControl ~= nil
                siloAssistCompactorController._controlPath = hasAJC and "attacherJointControl" or "attacherJoints"
                return siloAssistCompactorController._controlPath
            end
        end
    end

    siloAssistCompactorController._controlPath = "none"
    return nil
end

---------------------------------------------------------------------
-- Update: check transitions, one-shot actions only.
-- No per-frame alpha override — game holds the setpoint.
---------------------------------------------------------------------
function siloAssistCompactorController.update(vehicle)
    -- HUD toggle off -> raise and skip
    if not siloAssistVehicleState.isCompactorEnabled() then
        if siloAssistCompactorController.isLowered then
            siloAssistCompactorController.raiseImplement(vehicle)
        end
        return
    end

    if siloAssistToolDetection.compactorTool == nil then
        return
    end

    -- Ensure control path is detected
    local path = siloAssistCompactorController._controlPath
        or siloAssistToolDetection.compactorControlPath
    if path == nil then
        if siloAssistCompactorController.detectControlPath(vehicle) == nil then
            return
        end
        path = siloAssistCompactorController._controlPath
    end
    if path == "none" then
        return
    end

    local state = siloAssistVehicleState.getState()
    local inSilo = siloAssistSiloDetector.isInSilo

    -- Lower when HUD toggle ON + inside silo + assist active
    local shouldBeLowered = inSilo and state ~= siloAssistConfig.STATE_OFF

    if shouldBeLowered and not siloAssistCompactorController.isLowered then
        siloAssistCompactorController.lowerImplement(vehicle)
    elseif not shouldBeLowered and siloAssistCompactorController.isLowered then
        siloAssistCompactorController.raiseImplement(vehicle)
    end
end
