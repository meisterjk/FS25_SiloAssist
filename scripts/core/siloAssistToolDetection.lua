--====================================================================
-- SiloAssist - Tool Detection & Vehicle State
-- Extracted from siloAssistHeightController for clarity.
-- Responsibility: detect attached tools, find control nodes,
-- determine control type, cache vehicle state (reversing, etc.)
--====================================================================

siloAssistToolDetection = {}

siloAssistToolDetection.toolType = nil
siloAssistToolDetection.toolObject = nil
siloAssistToolDetection.controlType = nil
siloAssistToolDetection.currentTargetAlpha = nil
siloAssistToolDetection.armToolIndex = nil
siloAssistToolDetection.dumpToolIndex = nil
siloAssistToolDetection.bladeNode = nil
siloAssistToolDetection.jointDescIndex = nil
siloAssistToolDetection.cylinderedVehicle = nil
siloAssistToolDetection.cachedIsReversing = false
siloAssistToolDetection.isFrontAttached = false
siloAssistToolDetection.bladePushDir = 1   -- 1 = vorne (Samples in Fahrzeug-Vorwärtsrichtung), -1 = hinten (Samples entgegen Fahrzeug-Vorwärtsrichtung)

function siloAssistToolDetection.reset()
    if siloAssistToolDetection.controlType == "cylindered" and siloAssistToolDetection.armToolIndex ~= nil then
        local cylVehicle = siloAssistToolDetection.cylinderedVehicle
        if cylVehicle ~= nil then
            Cylindered.actionEventInput(cylVehicle, "", 0, siloAssistToolDetection.armToolIndex, true)
        end
        if siloAssistToolDetection.dumpToolIndex ~= nil then
            Cylindered.actionEventInput(cylVehicle, "", 0, siloAssistToolDetection.dumpToolIndex, true)
        end
    end

    siloAssistToolDetection.toolType = nil
    siloAssistToolDetection.toolObject = nil
    siloAssistToolDetection.controlType = nil
    siloAssistToolDetection.currentTargetAlpha = nil
    siloAssistToolDetection.armToolIndex = nil
    siloAssistToolDetection.dumpToolIndex = nil
    siloAssistToolDetection.bladeNode = nil
    siloAssistToolDetection.jointDescIndex = nil
    siloAssistToolDetection.cylinderedVehicle = nil
    siloAssistToolDetection.cachedIsReversing = false
    siloAssistToolDetection.isFrontAttached = false
    siloAssistToolDetection.bladePushDir = 1
end

function siloAssistToolDetection.isReversing(vehicle)
    if vehicle ~= nil and vehicle.getMotor ~= nil then
        local motor = vehicle:getMotor()
        if motor ~= nil and motor.getGearRatio ~= nil then
            local ratio = motor:getGearRatio()
            if ratio ~= nil and ratio < 0 then
                siloAssistDebug.logThrottled("Tool", "isReversing", "gearRatio=" .. tostring(ratio) .. " -> reversing")
                return true
            end
        end
    end
    if vehicle ~= nil and vehicle.movingDirection ~= nil then
        local md = vehicle.movingDirection
        siloAssistDebug.logThrottled("Tool", "isReversing", "movingDirection=" .. tostring(md) .. " -> " .. tostring(md < 0))
        return md < 0
    end
    if vehicle ~= nil and vehicle.lastSpeedReal ~= nil then
        siloAssistDebug.logThrottled("Tool", "isReversing", "lastSpeedReal=" .. string.format("%.6f", vehicle.lastSpeedReal))
        return vehicle.lastSpeedReal < -0.00001
    end
    return false
end

function siloAssistToolDetection.detectTool(vehicle)
    if vehicle == nil then
        return nil, nil, nil
    end

    if vehicle.getAttachedImplements ~= nil then
        for _, implement in ipairs(vehicle:getAttachedImplements()) do
            local impl = implement.object
            if impl ~= nil then
                if impl.spec_leveler ~= nil then
                    local toolType = "leveler"
                    local toolObject = impl
                    local controlType = impl.spec_attacherJointControl ~= nil and "attacherJointControl" or "cylindered"
                    return toolType, toolObject, controlType
                end

                if impl.spec_shovel ~= nil then
                    local toolType = "shovel"
                    local toolObject = impl
                    local controlType = impl.spec_cylindered ~= nil and "cylindered"
                        or (impl.spec_attacherJointControl ~= nil and "attacherJointControl" or "cylindered")
                    return toolType, toolObject, controlType
                end
            end
        end
    end

    if vehicle.spec_leveler ~= nil then
        return "leveler", vehicle, vehicle.spec_cylindered ~= nil and "cylindered" or nil
    end

    return nil, nil, nil
end

function siloAssistToolDetection.findCylinderedTools(vehicle, toolObject)
    local armIndex = nil
    local dumpIndex = nil
    local cylVehicle = nil

    if vehicle == nil then
        return nil, nil, nil
    end

    local function scanMovingTools(obj)
        if obj == nil or obj.spec_cylindered == nil or obj.spec_cylindered.movingTools == nil then
            return nil, nil
        end
        for i, movingTool in ipairs(obj.spec_cylindered.movingTools) do
            if movingTool.controlGroupIndex ~= nil or movingTool.axis ~= nil then
                local axis = movingTool.axis
                if axis == "AXIS_FRONTLOADER_ARM" or axis == "AXIS_COCKPIT_ARM" then
                    return i, nil
                elseif axis == "AXIS_FRONTLOADER_TOOL" or axis == "AXIS_COCKPIT_TOOL" then
                    return nil, i
                end
            end
        end
        return nil, nil
    end

    if vehicle.getChildVehicles ~= nil then
        for _, child in ipairs(vehicle:getChildVehicles()) do
            if child.spec_cylindered ~= nil and child.spec_cylindered.movingTools ~= nil then
                for i, movingTool in ipairs(child.spec_cylindered.movingTools) do
                    if movingTool.controlGroupIndex ~= nil then
                        if movingTool.axis == "AXIS_FRONTLOADER_ARM" or movingTool.axis == "AXIS_COCKPIT_ARM" then
                            armIndex = i
                            cylVehicle = child
                        elseif movingTool.axis == "AXIS_FRONTLOADER_TOOL" or movingTool.axis == "AXIS_COCKPIT_TOOL" then
                            dumpIndex = i
                        end
                    end
                end
                if armIndex ~= nil then
                    break
                end
            end
        end
    end

    if armIndex == nil and toolObject ~= nil then
        if toolObject.spec_cylindered ~= nil and toolObject.spec_cylindered.movingTools ~= nil then
            for i, movingTool in ipairs(toolObject.spec_cylindered.movingTools) do
                if movingTool.axis ~= nil then
                    if movingTool.axis == "AXIS_FRONTLOADER_ARM" or movingTool.axis == "AXIS_COCKPIT_ARM" then
                        armIndex = i
                        cylVehicle = toolObject
                    elseif movingTool.axis == "AXIS_FRONTLOADER_TOOL" or movingTool.axis == "AXIS_COCKPIT_TOOL" then
                        dumpIndex = i
                    end
                end
            end
        end
    end

    if armIndex == nil and vehicle.spec_cylindered ~= nil and vehicle.spec_cylindered.movingTools ~= nil then
        for i, movingTool in ipairs(vehicle.spec_cylindered.movingTools) do
            if movingTool.axis ~= nil then
                if movingTool.axis == "AXIS_FRONTLOADER_ARM" or movingTool.axis == "AXIS_COCKPIT_ARM" then
                    armIndex = i
                    cylVehicle = vehicle
                elseif movingTool.axis == "AXIS_FRONTLOADER_TOOL" or movingTool.axis == "AXIS_COCKPIT_TOOL" then
                    dumpIndex = i
                end
            end
        end
    end

    return armIndex, dumpIndex, cylVehicle
end

function siloAssistToolDetection.findAttacherJointIndex(vehicle, toolObject)
    if vehicle == nil then
        return nil
    end

    local spec = vehicle.spec_attacherJoints
    if spec == nil or spec.attacherJoints == nil then
        return nil
    end

    for i, joint in ipairs(spec.attacherJoints) do
        if joint.moveAttacherJointObject == toolObject then
            return i
        end
        if joint.attacherVehicle == toolObject then
            return i
        end
    end

    if toolObject ~= nil then
        for i, implement in ipairs(vehicle:getAttachedImplements()) do
            if implement.object == toolObject then
                return implement.jointDescIndex
            end
        end
    end

    return nil
end

function siloAssistToolDetection.getBladeNode(toolType, toolObject, vehicle)
    if toolType == "leveler" then
        if toolObject ~= nil and toolObject.spec_leveler ~= nil and toolObject.spec_leveler.nodes ~= nil and #toolObject.spec_leveler.nodes > 0 then
            return toolObject.spec_leveler.nodes[1].node
        end
        if vehicle.spec_leveler ~= nil and vehicle.spec_leveler.nodes ~= nil and #vehicle.spec_leveler.nodes > 0 then
            return vehicle.spec_leveler.nodes[1].node
        end
    end

    if toolObject ~= nil and toolObject.rootNode ~= nil then
        return toolObject.rootNode
    end

    if vehicle ~= nil and vehicle.rootNode ~= nil then
        return vehicle.rootNode
    end

    return nil
end

function siloAssistToolDetection.initTool(vehicle)
    local toolType, toolObject, controlType = siloAssistToolDetection.detectTool(vehicle)

    if toolType == nil then
        print("[SiloAssist] detectTool: NO tool found on " .. tostring(vehicle.configFileName))
        return false
    end

    print("[SiloAssist] detectTool: type=" .. tostring(toolType) .. " control=" .. tostring(controlType) .. " toolObj=" .. tostring(toolObject ~= nil and toolObject.configFileName or "nil"))

    siloAssistToolDetection.toolType = toolType
    siloAssistToolDetection.toolObject = toolObject
    siloAssistToolDetection.controlType = controlType
    siloAssistToolDetection.bladeNode = siloAssistToolDetection.getBladeNode(toolType, toolObject, vehicle)

    siloAssistToolDetection.isFrontAttached = siloAssistToolDetection.detectIsFrontAttached(vehicle, toolObject, controlType)
    siloAssistToolDetection.bladePushDir = siloAssistToolDetection.isFrontAttached and 1 or -1

    siloAssistDebug.log("Tool", string.format(
        "initTool: type=%s ctrl=%s bladeNode=%s isFront=%s bladePushDir=%s",
        tostring(toolType), tostring(controlType), tostring(siloAssistToolDetection.bladeNode),
        tostring(siloAssistToolDetection.isFrontAttached),
        tostring(siloAssistToolDetection.bladePushDir)
    ))

    if controlType == "cylindered" then
        local rootVehicle = vehicle
        if vehicle.getRootVehicle ~= nil then
            rootVehicle = vehicle:getRootVehicle()
        end
        local armIndex, dumpIndex, cylVehicle = siloAssistToolDetection.findCylinderedTools(rootVehicle, toolObject)
        siloAssistToolDetection.armToolIndex = armIndex
        siloAssistToolDetection.dumpToolIndex = dumpIndex
        siloAssistToolDetection.cylinderedVehicle = cylVehicle
        print("[SiloAssist] cylindered: armIx=" .. tostring(armIndex) .. " dumpIx=" .. tostring(dumpIndex) .. " cylVeh=" .. tostring(cylVehicle ~= nil and cylVehicle.configFileName or "nil"))
    elseif controlType == "attacherJointControl" then
        siloAssistToolDetection.jointDescIndex = siloAssistToolDetection.findAttacherJointIndex(vehicle, toolObject)
        if toolObject ~= nil and toolObject.spec_attacherJointControl ~= nil then
            siloAssistToolDetection.currentTargetAlpha = toolObject.spec_attacherJointControl.heightController.moveAlpha
        end
    end

    return true
end

---------------------------------------------------------------------
-- Detect if tool is attached to the front of the vehicle.
-- Front-mounted: isFrontAttached=true, pitchFactor=+1, bladePushDir=1.
-- Rear-mounted: isFrontAttached=false, pitchFactor=-1, bladePushDir=-1.
-- 3-point hitch: Z position of joint node relative to vehicle root (+Z = vorne).
-- Wheel loaders (cylindered): always front-mounted.
---------------------------------------------------------------------
function siloAssistToolDetection.detectIsFrontAttached(vehicle, toolObject, controlType)
    if controlType == "cylindered" then
        return true
    end

    if vehicle == nil or vehicle.spec_attacherJoints == nil or vehicle.spec_attacherJoints.attacherJoints == nil then
        return false
    end

    local spec = vehicle.spec_attacherJoints
    for _, joint in ipairs(spec.attacherJoints) do
        if joint.jointDescIndex ~= nil and toolObject ~= nil then
            local implement = vehicle:getAttachedImplement(toolObject)
            if implement ~= nil and implement.jointDescIndex == joint.jointDescIndex then
                local jointNode = joint.node
                if jointNode ~= nil then
                    local _, _, tz = localToLocal(jointNode, vehicle.rootNode, 0, 0, 0)
                    return tz > 0
                end
            end
        end
    end

    if toolObject ~= nil and toolObject.rootNode ~= nil then
        local _, _, tz = localToLocal(toolObject.rootNode, vehicle.rootNode, 0, 0, 0)
        return tz > 0
    end

    return false
end