--====================================================================
-- SiloAssist - Tool Detection & Vehicle Classification
-- Responsibility: detect attached tools, classify vehicle type,
-- find control nodes, determine control type.
--
-- PHASED INIT:
--   Phase 1: scanVehicle() — classify vehicle + collect implements
--   Phase 2: initTool() — setup control indices for each detected tool
--
-- PRIMARY TOOL: leveler/shovel used for height/tilt/sensors
-- COMPACTOR TOOL: separate implement for compactor controller
--
-- Vehicle types:
--   "tractor"    — Traktor mit 3-Punkt (front/hinter)
--   "wheelLoader" — Radlader mit Cylindered-Arm
--   "selfPropelled" — Selbstfahrer mit festangebauten Geraeten
--
-- Attach positions:
--   "front"  — vorne am Fahrzeug (Z > 0)
--   "rear"   — hinten am Fahrzeug (Z < 0)
--   "integrated" — festangebaut (Radlader/Selbstfahrer)
--====================================================================

siloAssistToolDetection = {}

---------------------------------------------------------------------
-- Primary tool state
---------------------------------------------------------------------
siloAssistToolDetection.toolType = nil
siloAssistToolDetection.toolObject = nil
siloAssistToolDetection.controlType = nil
siloAssistToolDetection.attachPosition = nil
siloAssistToolDetection.currentTargetAlpha = nil
siloAssistToolDetection.armToolIndex = nil
siloAssistToolDetection.dumpToolIndex = nil
siloAssistToolDetection.bladeNode = nil
siloAssistToolDetection.jointDescIndex = nil
siloAssistToolDetection.cylinderedVehicle = nil
siloAssistToolDetection.cachedIsReversing = false
siloAssistToolDetection.isFrontAttached = false
siloAssistToolDetection.bladePushDir = 1
siloAssistToolDetection.isCompactor = false
siloAssistToolDetection.attachType = nil

---------------------------------------------------------------------
-- Compactor tool state (separate from primary)
---------------------------------------------------------------------
siloAssistToolDetection.compactorTool = nil
siloAssistToolDetection.compactorControlType = nil
siloAssistToolDetection.compactorObject = nil

---------------------------------------------------------------------
-- Vehicle classification
---------------------------------------------------------------------
siloAssistToolDetection.vehicleType = nil

---------------------------------------------------------------------
-- Compactor control state (own indices, NOT shared with primary)
---------------------------------------------------------------------
siloAssistToolDetection.compactorJointDescIndex = nil
siloAssistToolDetection.compactorArmToolIndex = nil
siloAssistToolDetection.compactorCylinderedVehicle = nil
siloAssistToolDetection.compactorControlPath = nil

---------------------------------------------------------------------
-- Reset all state
---------------------------------------------------------------------
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
    -- Also reset compactor cylindered if present
    if siloAssistToolDetection.compactorArmToolIndex ~= nil and siloAssistToolDetection.compactorCylinderedVehicle ~= nil then
        Cylindered.actionEventInput(siloAssistToolDetection.compactorCylinderedVehicle, "", 0, siloAssistToolDetection.compactorArmToolIndex, true)
    end

    siloAssistToolDetection.toolType = nil
    siloAssistToolDetection.toolObject = nil
    siloAssistToolDetection.controlType = nil
    siloAssistToolDetection.attachPosition = nil
    siloAssistToolDetection.currentTargetAlpha = nil
    siloAssistToolDetection.armToolIndex = nil
    siloAssistToolDetection.dumpToolIndex = nil
    siloAssistToolDetection.bladeNode = nil
    siloAssistToolDetection.jointDescIndex = nil
    siloAssistToolDetection.cylinderedVehicle = nil
    siloAssistToolDetection.cachedIsReversing = false
    siloAssistToolDetection.isFrontAttached = false
    siloAssistToolDetection.bladePushDir = 1
    siloAssistToolDetection.isCompactor = false
    siloAssistToolDetection.attachType = nil

    siloAssistToolDetection.compactorTool = nil
    siloAssistToolDetection.compactorControlType = nil
    siloAssistToolDetection.compactorObject = nil
    siloAssistToolDetection.compactorJointDescIndex = nil
    siloAssistToolDetection.compactorArmToolIndex = nil
    siloAssistToolDetection.compactorCylinderedVehicle = nil
    siloAssistToolDetection.compactorControlPath = nil

    siloAssistToolDetection.vehicleType = nil
end

---------------------------------------------------------------------
-- Is vehicle reversing?
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- Normalize configFileName for comparison
---------------------------------------------------------------------
local function normalizeConfigFileName(name)
    if name == nil then return nil end
    name = string.lower(name)
    name = string.gsub(name, "[/\\]", "/")
    return name
end

---------------------------------------------------------------------
-- Classify vehicle type
---------------------------------------------------------------------
local function classifyVehicle(vehicle)
    if vehicle == nil then return "unknown" end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle

    if rootVehicle.spec_cylindered ~= nil then
        local hasFrontLoaderArm = false
        if rootVehicle.spec_cylindered.movingTools ~= nil then
            for _, mt in ipairs(rootVehicle.spec_cylindered.movingTools) do
                if mt.axis == "AXIS_FRONTLOADER_ARM" or mt.axis == "AXIS_COCKPIT_ARM" then
                    hasFrontLoaderArm = true
                    break
                end
            end
        end
        if hasFrontLoaderArm then
            return "wheelLoader"
        end
    end

    if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        return "tractor"
    end

    return "selfPropelled"
end

---------------------------------------------------------------------
-- Detect attach position of an implement relative to root vehicle.
-- Returns "front", "rear", or "integrated"
---------------------------------------------------------------------
local function detectAttachPosition(rootVehicle, impl)
    if rootVehicle == nil or impl == nil then
        return "integrated"
    end

    if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
            if joint.moveAttacherJointObject == impl or joint.attacherVehicle == impl then
                local jointNode = joint.node
                if jointNode ~= nil then
                    local _, _, tz = localToLocal(jointNode, rootVehicle.rootNode, 0, 0, 0)
                    -- FS25: local Z+ = front of vehicle (confirmed by tz=3.853 for front-mounted MES 400)
                    local pos = tz > 0 and "front" or "rear"
                    print(string.format("[SiloAssist] detectAttachPosition: impl=%s tz=%.3f -> %s (jointNode)", tostring(impl.configFileName), tz, pos))
                    return pos
                end
            end
        end
    end

    if impl.rootNode ~= nil and rootVehicle.rootNode ~= nil then
        local _, _, tz = localToLocal(impl.rootNode, rootVehicle.rootNode, 0, 0, 0)
        if math.abs(tz) > 0.1 then
            local pos = tz > 0 and "front" or "rear"
            print(string.format("[SiloAssist] detectAttachPosition: impl=%s tz=%.3f -> %s (rootNode)", tostring(impl.configFileName), tz, pos))
            return pos
        end
    end

    print(string.format("[SiloAssist] detectAttachPosition: impl=%s -> integrated (fallback)", tostring(impl.configFileName)))
    return "integrated"
end

---------------------------------------------------------------------
-- Detect tool type and control type for a single implement.
-- Returns: toolType, controlType
---------------------------------------------------------------------
local function detectImplementControlType(impl, vehicleType)
    if impl == nil then return nil end

    if impl.spec_attacherJointControl ~= nil then
        return "attacherJointControl"
    end

    if impl.spec_cylindered ~= nil and impl.spec_cylindered.movingTools ~= nil then
        for _, mt in ipairs(impl.spec_cylindered.movingTools) do
            if mt.axis == "AXIS_FRONTLOADER_ARM" or mt.axis == "AXIS_COCKPIT_ARM" then
                return "cylindered"
            end
        end
    end

    if vehicleType == "tractor" then
        return "attacherJoints"
    end

    return "cylindered"
end

---------------------------------------------------------------------
-- Detect tool type and control type for the vehicle itself
-- (self-propelled: wheel loader with built-in leveler/compactor)
---------------------------------------------------------------------
local function detectVehicleControlType(vehicle)
    if vehicle.spec_cylindered ~= nil then
        return "cylindered"
    end
    return "cylindered"
end

---------------------------------------------------------------------
-- Scan all attached implements and classify the vehicle.
-- Returns: primaryType, primaryObject, primaryControlType, primaryAttachPosition,
--          compactorImpl, compactorCtrlType
---------------------------------------------------------------------
function siloAssistToolDetection.detectTool(vehicle)
    if vehicle == nil then
        return nil, nil, nil, nil
    end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle
    siloAssistToolDetection.vehicleType = classifyVehicle(vehicle)

    local primaryType = nil
    local primaryObject = nil
    local primaryControlType = nil
    local primaryAttachPosition = nil

    local compactorImpl = nil
    local compactorCtrlType = nil

    if rootVehicle.getAttachedImplements ~= nil then
        for _, implement in ipairs(rootVehicle:getAttachedImplements()) do
            local impl = implement.object
            if impl ~= nil then
                local cfgToolType = siloAssistEquipmentConfig.getEffectiveToolType(impl)
                if cfgToolType ~= nil then
                    local cfgControlMode = siloAssistEquipmentConfig.getEffectiveControlMode(impl) or "attacherJointControl"
                    local cfgAttachType = siloAssistEquipmentConfig.getEffectiveAttachType(impl)

                    if cfgToolType == "compactor" then
                        compactorImpl = impl
                        compactorCtrlType = cfgControlMode
                        print(string.format("[SiloAssist] detectTool: XML compactor override for %s -> ctrl=%s attach=%s",
                            tostring(impl.configFileName), tostring(cfgControlMode), tostring(cfgAttachType)))
                    elseif primaryType == nil then
                        primaryType = cfgToolType
                        primaryObject = impl
                        primaryControlType = cfgControlMode
                        primaryAttachPosition = detectAttachPosition(rootVehicle, impl)
                        print(string.format("[SiloAssist] detectTool: XML primary override for %s -> type=%s ctrl=%s attachType=%s pos=%s",
                            tostring(impl.configFileName), tostring(cfgToolType), tostring(cfgControlMode), tostring(cfgAttachType), tostring(primaryAttachPosition)))
                    end

                elseif impl.spec_leveler ~= nil and impl.spec_bunkerSiloCompacter == nil then
                    if primaryType == nil then
                        primaryType = "leveler"
                        primaryObject = impl
                        primaryControlType = detectImplementControlType(impl, siloAssistToolDetection.vehicleType)
                        primaryAttachPosition = detectAttachPosition(rootVehicle, impl)
                    end

                elseif impl.spec_shovel ~= nil then
                    if primaryType == nil then
                        primaryType = "shovel"
                        primaryObject = impl
                        primaryControlType = detectImplementControlType(impl, siloAssistToolDetection.vehicleType)
                        primaryAttachPosition = detectAttachPosition(rootVehicle, impl)
                    end

                elseif impl.spec_bunkerSiloCompacter ~= nil then
                    compactorImpl = impl
                    compactorCtrlType = detectImplementControlType(impl, siloAssistToolDetection.vehicleType)
                end
            end
        end
    end

    -- Self-propelled compactor (e.g. Prinoth Leitwolf Agripower)
    if vehicle.spec_bunkerSiloCompacter ~= nil then
        local cfgToolType = siloAssistEquipmentConfig.getEffectiveToolType(vehicle)
        if cfgToolType ~= nil then
            if cfgToolType == "compactor" then
                compactorImpl = vehicle
                compactorCtrlType = siloAssistEquipmentConfig.getEffectiveControlMode(vehicle) or "cylindered"
            elseif primaryType == nil then
                primaryType = cfgToolType
                primaryObject = vehicle
                primaryControlType = siloAssistEquipmentConfig.getEffectiveControlMode(vehicle) or "cylindered"
                primaryAttachPosition = "integrated"
            end
        else
            if compactorImpl == nil then
                compactorImpl = vehicle
                compactorCtrlType = detectVehicleControlType(vehicle)
            end
        end
    end

    -- Self-propelled leveler (e.g. wheel loader with spec_leveler)
    if vehicle.spec_leveler ~= nil and primaryType == nil then
        primaryType = "leveler"
        primaryObject = vehicle
        primaryControlType = detectVehicleControlType(vehicle)
        primaryAttachPosition = "integrated"
    end

    siloAssistToolDetection.compactorTool = compactorImpl
    siloAssistToolDetection.compactorControlType = compactorCtrlType
    siloAssistToolDetection.compactorObject = compactorImpl

    if primaryType ~= nil then
        siloAssistToolDetection.isCompactor = false
        print(string.format("[SiloAssist] detectTool: vType=%s primary=%s ctrl=%s pos=%s compactor=%s",
            tostring(siloAssistToolDetection.vehicleType),
            tostring(primaryType), tostring(primaryControlType), tostring(primaryAttachPosition),
            tostring(compactorImpl ~= nil and compactorImpl.configFileName or "none")))
        return primaryType, primaryObject, primaryControlType, primaryAttachPosition
    end

    if compactorImpl ~= nil then
        siloAssistToolDetection.isCompactor = true
        local compAttachPos = detectAttachPosition(rootVehicle, compactorImpl)
        if compAttachPos == nil then compAttachPos = "integrated" end
        print(string.format("[SiloAssist] detectTool: compactor-only mode: vType=%s %s ctrl=%s pos=%s",
            tostring(siloAssistToolDetection.vehicleType),
            tostring(compactorImpl.configFileName), tostring(compactorCtrlType), tostring(compAttachPos)))
        return "compactor", compactorImpl, compactorCtrlType, compAttachPos
    end

    siloAssistToolDetection.isCompactor = false
    return nil, nil, nil, nil
end

---------------------------------------------------------------------
-- Find Cylindered movingTool indices for a specific tool object.
-- Returns: armIndex, dumpIndex, cylVehicle
---------------------------------------------------------------------
function siloAssistToolDetection.findCylinderedTools(vehicle, toolObject)
    local armIndex = nil
    local dumpIndex = nil
    local cylVehicle = nil

    if vehicle == nil then
        return nil, nil, nil
    end

    local customArmAxis, customDumpAxis = nil, nil
    if toolObject ~= nil then
        customArmAxis, customDumpAxis = siloAssistEquipmentConfig.getAxisNames(toolObject)
    end

    local armAxisNames = {"AXIS_FRONTLOADER_ARM", "AXIS_COCKPIT_ARM"}
    local dumpAxisNames = {"AXIS_FRONTLOADER_TOOL", "AXIS_COCKPIT_TOOL"}

    if customArmAxis ~= nil then
        armAxisNames = {customArmAxis}
    end
    if customDumpAxis ~= nil then
        dumpAxisNames = {customDumpAxis}
    end

    local function isArmAxis(axis)
        for _, name in ipairs(armAxisNames) do
            if axis == name then return true end
        end
        return false
    end

    local function isDumpAxis(axis)
        for _, name in ipairs(dumpAxisNames) do
            if axis == name then return true end
        end
        return false
    end

    if vehicle.getChildVehicles ~= nil then
        for _, child in ipairs(vehicle:getChildVehicles()) do
            if child.spec_cylindered ~= nil and child.spec_cylindered.movingTools ~= nil then
                for i, movingTool in ipairs(child.spec_cylindered.movingTools) do
                    if movingTool.controlGroupIndex ~= nil then
                        if isArmAxis(movingTool.axis) then
                            armIndex = i
                            cylVehicle = child
                        elseif isDumpAxis(movingTool.axis) then
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
                    if isArmAxis(movingTool.axis) then
                        armIndex = i
                        cylVehicle = toolObject
                    elseif isDumpAxis(movingTool.axis) then
                        dumpIndex = i
                    end
                end
            end
        end
    end

    if armIndex == nil and vehicle.spec_cylindered ~= nil and vehicle.spec_cylindered.movingTools ~= nil then
        for i, movingTool in ipairs(vehicle.spec_cylindered.movingTools) do
            if movingTool.axis ~= nil then
                if isArmAxis(movingTool.axis) then
                    armIndex = i
                    cylVehicle = vehicle
                elseif isDumpAxis(movingTool.axis) then
                    dumpIndex = i
                end
            end
        end
    end

    if armIndex == nil then
        siloAssistToolDetection._logMovingTools(vehicle, toolObject)
    end

    return armIndex, dumpIndex, cylVehicle
end

---------------------------------------------------------------------
-- Find Cylindered indices for the COMPACTOR tool (separate from primary)
-- Returns: armIndex, cylVehicle (compactor has no dump)
---------------------------------------------------------------------
local function findCompactorCylinderedTools(rootVehicle, compactorTool)
    if compactorTool == nil then return nil, nil end

    local customArmAxis = siloAssistEquipmentConfig.getAxisNames(compactorTool)
    local armAxisNames = {"AXIS_FRONTLOADER_ARM", "AXIS_COCKPIT_ARM"}
    if customArmAxis ~= nil then
        armAxisNames = {customArmAxis}
    end

    local armIndex = nil
    local cylVehicle = nil

    local function isArmAxis(axis)
        for _, name in ipairs(armAxisNames) do
            if axis == name then return true end
        end
        return false
    end

    -- Check rootVehicle's child vehicles
    if rootVehicle.getChildVehicles ~= nil then
        for _, child in ipairs(rootVehicle:getChildVehicles()) do
            if child == compactorTool and child.spec_cylindered ~= nil and child.spec_cylindered.movingTools ~= nil then
                for i, movingTool in ipairs(child.spec_cylindered.movingTools) do
                    if movingTool.axis ~= nil and isArmAxis(movingTool.axis) then
                        armIndex = i
                        cylVehicle = child
                        break
                    end
                end
                if armIndex ~= nil then break end
            end
        end
    end

    -- Check compactor tool itself
    if armIndex == nil and compactorTool.spec_cylindered ~= nil and compactorTool.spec_cylindered.movingTools ~= nil then
        for i, movingTool in ipairs(compactorTool.spec_cylindered.movingTools) do
            if movingTool.axis ~= nil and isArmAxis(movingTool.axis) then
                armIndex = i
                cylVehicle = compactorTool
                break
            end
        end
    end

    -- Check rootVehicle itself (self-propelled)
    if armIndex == nil and rootVehicle.spec_cylindered ~= nil and rootVehicle.spec_cylindered.movingTools ~= nil then
        for i, movingTool in ipairs(rootVehicle.spec_cylindered.movingTools) do
            if movingTool.axis ~= nil and isArmAxis(movingTool.axis) then
                armIndex = i
                cylVehicle = rootVehicle
                break
            end
        end
    end

    if armIndex == nil then
        -- Fallback: use the first movingTool with any axis (for 3-point tools without FRONTLOADER naming)
        if compactorTool.spec_cylindered ~= nil and compactorTool.spec_cylindered.movingTools ~= nil then
            for i, movingTool in ipairs(compactorTool.spec_cylindered.movingTools) do
                if movingTool.axis ~= nil then
                    armIndex = i
                    cylVehicle = compactorTool
                    print(string.format("[SiloAssist] Compactor cyl fallback: movingTool[%d] axis=%s",
                        i, tostring(movingTool.axis)))
                    break
                end
            end
        end
    end

    return armIndex, cylVehicle
end

---------------------------------------------------------------------
-- Log all movingTools for debugging (when no arm axis found)
---------------------------------------------------------------------
function siloAssistToolDetection._logMovingTools(vehicle, toolObject)
    local function logVehicleCylindered(veh, label)
        if veh == nil or veh.spec_cylindered == nil or veh.spec_cylindered.movingTools == nil then
            return
        end
        for i, mt in ipairs(veh.spec_cylindered.movingTools) do
            print(string.format("[SiloAssist] movingTool %s[%d]: axis=%s controlGroupIndex=%s rotMin=%.3f rotMax=%.3f",
                label, i, tostring(mt.axis), tostring(mt.controlGroupIndex),
                mt.rotMin or 0, mt.rotMax or 0))
        end
    end

    print("[SiloAssist] No arm axis found, logging all movingTools:")
    logVehicleCylindered(vehicle, "vehicle")
    if toolObject ~= nil and toolObject ~= vehicle then
        logVehicleCylindered(toolObject, "toolObject")
    end
    if vehicle.getRootVehicle ~= nil then
        local root = vehicle:getRootVehicle()
        if root ~= nil and root ~= vehicle then
            logVehicleCylindered(root, "rootVehicle")
        end
        if root ~= nil and root.getChildVehicles ~= nil then
            for _, child in ipairs(root:getChildVehicles()) do
                if child ~= vehicle and child ~= toolObject then
                    logVehicleCylindered(child, "child")
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Find AttacherJoint index for a tool on a vehicle
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- Find AttacherJoint for the compactor tool (may be on different
-- vehicle than primary tool, e.g. tractor's 3-point for Stego)
---------------------------------------------------------------------
local function findCompactorAttacherJointIndex(rootVehicle, compactorTool)
    if rootVehicle == nil or compactorTool == nil then
        return nil
    end

    local spec = rootVehicle.spec_attacherJoints
    if spec == nil or spec.attacherJoints == nil then
        return nil
    end

    for i, joint in ipairs(spec.attacherJoints) do
        if joint.moveAttacherJointObject == compactorTool then
            return i
        end
    end

    for i, implement in ipairs(rootVehicle:getAttachedImplements()) do
        if implement.object == compactorTool then
            return implement.jointDescIndex
        end
    end

    return nil
end

---------------------------------------------------------------------
-- Get blade node (leveler node or root node)
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- Initialize PRIMARY tool control.
-- Called after detectTool() found a primary tool.
-- Sets up: controlType indices, bladeNode, attachPosition, pushDir.
---------------------------------------------------------------------
local function initPrimaryTool(vehicle, toolType, toolObject, controlType, attachPosition)
    siloAssistToolDetection.toolType = toolType
    siloAssistToolDetection.toolObject = toolObject
    siloAssistToolDetection.controlType = controlType
    siloAssistToolDetection.attachPosition = attachPosition
    siloAssistToolDetection.bladeNode = siloAssistToolDetection.getBladeNode(toolType, toolObject, vehicle)

    siloAssistToolDetection.isFrontAttached = (attachPosition == "front" or attachPosition == "integrated")
    siloAssistToolDetection.bladePushDir = siloAssistToolDetection.isFrontAttached and 1 or -1
    siloAssistToolDetection.attachType = attachPosition

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle

    if controlType == "cylindered" then
        local armIndex, dumpIndex, cylVehicle = siloAssistToolDetection.findCylinderedTools(rootVehicle, toolObject)
        siloAssistToolDetection.armToolIndex = armIndex
        siloAssistToolDetection.dumpToolIndex = dumpIndex
        siloAssistToolDetection.cylinderedVehicle = cylVehicle
        print("[SiloAssist] primary cylindered: armIx=" .. tostring(armIndex) .. " dumpIx=" .. tostring(dumpIndex) .. " cylVeh=" .. tostring(cylVehicle ~= nil and cylVehicle.configFileName or "nil"))

    elseif controlType == "attacherJointControl" then
        siloAssistToolDetection.jointDescIndex = siloAssistToolDetection.findAttacherJointIndex(vehicle, toolObject)
        if toolObject ~= nil and toolObject.spec_attacherJointControl ~= nil then
            siloAssistToolDetection.currentTargetAlpha = toolObject.spec_attacherJointControl.heightController.moveAlpha
        end
        print("[SiloAssist] primary AJC: jointDescIndex=" .. tostring(siloAssistToolDetection.jointDescIndex))

    elseif controlType == "attacherJoints" then
        siloAssistToolDetection.jointDescIndex = findCompactorAttacherJointIndex(rootVehicle, toolObject)
        print("[SiloAssist] primary attacherJoints: jointDescIndex=" .. tostring(siloAssistToolDetection.jointDescIndex))
    end

    print(string.format("[SiloAssist] initPrimaryTool: type=%s ctrl=%s pos=%s blade=%s isFront=%s pushDir=%s vType=%s",
        tostring(toolType), tostring(controlType), tostring(attachPosition),
        tostring(siloAssistToolDetection.bladeNode ~= nil),
        tostring(siloAssistToolDetection.isFrontAttached),
        tostring(siloAssistToolDetection.bladePushDir),
        tostring(siloAssistToolDetection.vehicleType)))
end

---------------------------------------------------------------------
-- Initialize COMPACTOR tool control (separate from primary).
-- Sets up: compactorJointDescIndex, compactorArmToolIndex, etc.
---------------------------------------------------------------------
local function initCompactorTool(vehicle)
    local compactorTool = siloAssistToolDetection.compactorTool
    local compactorControlType = siloAssistToolDetection.compactorControlType

    if compactorTool == nil then
        siloAssistToolDetection.compactorJointDescIndex = nil
        siloAssistToolDetection.compactorArmToolIndex = nil
        siloAssistToolDetection.compactorCylinderedVehicle = nil
        siloAssistToolDetection.compactorControlPath = nil
        return
    end

    local rootVehicle = vehicle.getRootVehicle ~= nil and vehicle:getRootVehicle() or vehicle

    siloAssistToolDetection.compactorControlPath = nil
    siloAssistToolDetection.compactorJointDescIndex = nil
    siloAssistToolDetection.compactorArmToolIndex = nil
    siloAssistToolDetection.compactorCylinderedVehicle = nil

    print(string.format("[SiloAssist] initCompactor: tool=%s ctrl=%s rootVeh=%s",
        tostring(compactorTool.configFileName), tostring(compactorControlType),
        tostring(rootVehicle.configFileName)))

    -- Path 1: Tractor AttacherJointControl (rootVehicle AJC for the joint)
    -- The tractor has AJC and controls the 3-point joint that holds the compactor
    if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        print(string.format("[SiloAssist] initCompactor P1: scanning %d attacherJoints on rootVehicle",
            #rootVehicle.spec_attacherJoints.attacherJoints))
        for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
            print(string.format("[SiloAssist] initCompactor P1: joint moveObj=%s hasAJC=%s",
                tostring(joint.moveAttacherJointObject ~= nil and joint.moveAttacherJointObject.configFileName or "nil"),
                tostring(rootVehicle.spec_attacherJointControl ~= nil)))
            if joint.moveAttacherJointObject == compactorTool then
                if rootVehicle.spec_attacherJointControl ~= nil then
                    siloAssistToolDetection.compactorJointDescIndex = joint.jointDescIndex
                    siloAssistToolDetection.compactorControlPath = "attacherJointControl"
                    print(string.format("[SiloAssist] initCompactor: Tractor AJC path, jointIx=%s",
                        tostring(joint.jointDescIndex)))
                    return
                end
            end
        end
    end
    print("[SiloAssist] initCompactor: P1 (Tractor AJC) not found")

    -- Path 2: Implement AttacherJointControl (compactorTool AJC)
    -- The compactor implement itself has AJC (rare but possible)
    if compactorTool.spec_attacherJointControl ~= nil then
        local spec = compactorTool.spec_attacherJointControl
        if spec.jointDesc ~= nil then
            siloAssistToolDetection.compactorControlPath = "implementAJC"
            print("[SiloAssist] initCompactor: Impl AJC path")
            return
        end
    end
    print(string.format("[SiloAssist] initCompactor: P2 (Impl AJC) not found, spec=%s",
        tostring(compactorTool.spec_attacherJointControl ~= nil)))

    -- Path 3: Cylindered (arm axis) — find compactor-specific indices
    if compactorControlType == "cylindered" or (compactorTool.spec_cylindered ~= nil) then
        local armIndex, cylVehicle = findCompactorCylinderedTools(rootVehicle, compactorTool)
        print(string.format("[SiloAssist] initCompactor P3: cylindered search result armIx=%s cylVeh=%s",
            tostring(armIndex), tostring(cylVehicle ~= nil and cylVehicle.configFileName or "nil")))
        if armIndex ~= nil then
            siloAssistToolDetection.compactorArmToolIndex = armIndex
            siloAssistToolDetection.compactorCylinderedVehicle = cylVehicle
            siloAssistToolDetection.compactorControlPath = "cylindered"
            print(string.format("[SiloAssist] initCompactor: Cylindered path, armIx=%s cylVeh=%s",
                tostring(armIndex), tostring(cylVehicle ~= nil and cylVehicle.configFileName or "nil")))
            return
        end
    end
    print("[SiloAssist] initCompactor: P3 (Cylindered) not found")

    -- Path 4: AttacherJoints direct (3-point hitch without AJC)
    -- The tractor has 3-point joints but no AJC. We set moveAlpha directly.
    -- Don't require lowerAlpha/upperAlpha -- use defaults (0.0/1.0) if missing.
    if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        for _, joint in ipairs(rootVehicle.spec_attacherJoints.attacherJoints) do
            print(string.format("[SiloAssist] initCompactor P4: joint moveObj=%s moveAlpha=%s lowerAlpha=%s upperAlpha=%s",
                tostring(joint.moveAttacherJointObject ~= nil and joint.moveAttacherJointObject.configFileName or "nil"),
                tostring(joint.moveAlpha), tostring(joint.lowerAlpha), tostring(joint.upperAlpha)))
            if joint.moveAttacherJointObject == compactorTool then
                -- Accept this joint even without lowerAlpha/upperAlpha -- use defaults
                siloAssistToolDetection.compactorJointDescIndex = joint.jointDescIndex
                siloAssistToolDetection.compactorControlPath = "attacherJoints"
                -- Store defaults if missing
                siloAssistCompactorController.lowerAlpha = joint.lowerAlpha or 1.0
                siloAssistCompactorController.upperAlpha = joint.upperAlpha or 0.0
                print(string.format("[SiloAssist] initCompactor: AttacherJoints path, jointIx=%s lower=%.3f upper=%.3f",
                    tostring(joint.jointDescIndex),
                    siloAssistCompactorController.lowerAlpha,
                    siloAssistCompactorController.upperAlpha))
                return
            end
        end
    end
    print("[SiloAssist] initCompactor: P4 (AttacherJoints) not found")

    -- Also try: find the joint by implement lookup (some FS25 versions use attacherVehicle instead of moveAttacherJointObject)
    if rootVehicle.spec_attacherJoints ~= nil and rootVehicle.spec_attacherJoints.attacherJoints ~= nil then
        if rootVehicle.getAttachedImplements ~= nil then
            for _, implement in ipairs(rootVehicle:getAttachedImplements()) do
                if implement.object == compactorTool then
                    local jdx = implement.jointDescIndex
                    if jdx ~= nil then
                        local joint = rootVehicle.spec_attacherJoints.attacherJoints[jdx]
                        if joint ~= nil then
                            siloAssistToolDetection.compactorJointDescIndex = jdx
                            siloAssistToolDetection.compactorControlPath = "attacherJoints"
                            siloAssistCompactorController.lowerAlpha = joint.lowerAlpha or 1.0
                            siloAssistCompactorController.upperAlpha = joint.upperAlpha or 0.0
                            print(string.format("[SiloAssist] initCompactor: AttacherJoints via implement lookup, jointIx=%s lower=%.3f upper=%.3f",
                                tostring(jdx),
                                siloAssistCompactorController.lowerAlpha,
                                siloAssistCompactorController.upperAlpha))
                            return
                        end
                    end
                end
            end
        end
    end
    print("[SiloAssist] initCompactor: P4b (AttacherJoints via implement) not found")

    -- No path found -- set "none" to prevent infinite retry in detectControlPath
    siloAssistToolDetection.compactorControlPath = "none"
    print(string.format("[SiloAssist] initCompactor: NO control path found for compactor %s! Setting controlPath='none'",
        tostring(compactorTool.configFileName)))
end

---------------------------------------------------------------------
-- Initialize tool detection for current vehicle.
-- Phase 1: detectTool() — scan vehicle + implements
-- Phase 2: initPrimaryTool() — setup primary control indices
-- Phase 3: initCompactorTool() — setup compactor control indices
---------------------------------------------------------------------
function siloAssistToolDetection.initTool(vehicle)
    local toolType, toolObject, controlType, attachPosition = siloAssistToolDetection.detectTool(vehicle)

    if toolType == nil then
        print("[SiloAssist] detectTool: NO tool found on " .. tostring(vehicle.configFileName))
        return false
    end

    print(string.format("[SiloAssist] initTool: type=%s ctrl=%s pos=%s toolObj=%s compactor=%s vType=%s",
        tostring(toolType), tostring(controlType), tostring(attachPosition),
        tostring(toolObject ~= nil and toolObject.configFileName or "nil"),
        tostring(siloAssistToolDetection.compactorTool ~= nil and siloAssistToolDetection.compactorTool.configFileName or "none"),
        tostring(siloAssistToolDetection.vehicleType)))

    initPrimaryTool(vehicle, toolType, toolObject, controlType, attachPosition)

    initCompactorTool(vehicle)

    siloAssistDebug.log("Tool", string.format(
        "initTool complete: type=%s ctrl=%s pos=%s blade=%s isFront=%s pushDir=%s compactor=%s compPath=%s vType=%s",
        tostring(toolType), tostring(controlType), tostring(attachPosition),
        tostring(siloAssistToolDetection.bladeNode ~= nil),
        tostring(siloAssistToolDetection.isFrontAttached),
        tostring(siloAssistToolDetection.bladePushDir),
        tostring(siloAssistToolDetection.compactorTool ~= nil),
        tostring(siloAssistToolDetection.compactorControlPath),
        tostring(siloAssistToolDetection.vehicleType)
    ))

    return true
end

---------------------------------------------------------------------
-- Detect if tool is attached to the front of the vehicle.
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