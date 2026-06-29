--====================================================================
-- SiloAssist - Equipment Configuration
-- Loads per-equipment overrides from modDesc.xml <siloAssistEquipment>.
-- Allows overriding toolType, controlMode, attachType, axis names etc.
-- XML config takes priority over automatic detection.
--====================================================================

siloAssistEquipmentConfig = {}

siloAssistEquipmentConfig.configs = {}

---------------------------------------------------------------------
-- Normalize a configFileName for lookup (lowercase, forward slashes)
---------------------------------------------------------------------
local function normalizeKey(key)
    if key == nil then return nil end
    key = string.lower(key)
    key = string.gsub(key, "[/\\]", "/")
    return key
end

---------------------------------------------------------------------
-- Load equipment configs from modDesc.xml
-- Reads <siloAssistEquipment> section with <equipment> entries.
-- Called once in siloAssist:loadMap()
---------------------------------------------------------------------
function siloAssistEquipmentConfig.loadFromModDesc()
    siloAssistEquipmentConfig.configs = {}

    local modDir = siloAssist.modDirectory or g_currentModDirectory
    if modDir == nil then
        print("[SiloAssist/EquipCfg] modDirectory is nil, skipping equipment config")
        return
    end
    local modDescPath = modDir .. "modDesc.xml"
    if not fileExists(modDescPath) then
        print("[SiloAssist/EquipCfg] modDesc.xml not found at " .. tostring(modDescPath))
        return
    end

    local xmlFile = XMLFile.load("siloAssistEquipCfg", modDescPath)
    if xmlFile == nil then
        print("[SiloAssist/EquipCfg] Failed to load modDesc.xml")
        return
    end

    local basePath = "modDesc.siloAssistEquipment"
    if not xmlFile:hasProperty(basePath) then
        print("[SiloAssist/EquipCfg] No <siloAssistEquipment> section in modDesc.xml")
        xmlFile:delete()
        return
    end

    local i = 0
    while true do
        local key = string.format("%s.equipment(%d)", basePath, i)
        if not xmlFile:hasProperty(key) then
            break
        end

        local configFile = xmlFile:getString(key .. "#configFileName") or ""
        if configFile ~= "" then
            local normalized = normalizeKey(configFile)
            if normalized ~= nil then
                local autoEnableStr = xmlFile:getString(key .. "#autoEnable") or "false"
                local entry = {
                    configFileName = normalized,
                    toolType = xmlFile:getString(key .. "#toolType") or nil,
                    controlMode = xmlFile:getString(key .. "#controlMode") or nil,
                    attachType = xmlFile:getString(key .. "#attachType") or nil,
                    autoEnable = (autoEnableStr == "true" or autoEnableStr == "1"),
                    armAxisName = xmlFile:getString(key .. "#armAxisName") or nil,
                    dumpAxisName = xmlFile:getString(key .. "#dumpAxisName") or nil,
                    description = xmlFile:getString(key .. "#description") or "",
                }
                siloAssistEquipmentConfig.configs[normalized] = entry
                print(string.format("[SiloAssist/EquipCfg] Loaded: %s -> type=%s ctrl=%s attach=%s armAxis=%s dumpAxis=%s autoEnable=%s desc=%s",
                    normalized,
                    tostring(entry.toolType),
                    tostring(entry.controlMode),
                    tostring(entry.attachType),
                    tostring(entry.armAxisName),
                    tostring(entry.dumpAxisName),
                    tostring(entry.autoEnable),
                    tostring(entry.description)
                ))
            end
        end

        i = i + 1
    end

    xmlFile:delete()
    local count = 0
    for _ in pairs(siloAssistEquipmentConfig.configs) do count = count + 1 end
    print(string.format("[SiloAssist/EquipCfg] Loaded %d equipment configs", count))
end

---------------------------------------------------------------------
-- Get config entry for a vehicle/implement by its configFileName
-- Returns the config table or nil if not found.
---------------------------------------------------------------------
function siloAssistEquipmentConfig.getConfig(vehicleOrImpl)
    if vehicleOrImpl == nil then return nil end

    local cfgName = vehicleOrImpl.configFileName
    if cfgName == nil then return nil end

    local normalized = normalizeKey(cfgName)
    return siloAssistEquipmentConfig.configs[normalized]
end

---------------------------------------------------------------------
-- Check if any attached implement (or the vehicle itself) has a
-- compactor config entry or spec_bunkerSiloCompacter.
-- Works even when the assist is OFF (independent of initTool).
---------------------------------------------------------------------
function siloAssistEquipmentConfig.hasCompactorAttached(vehicle)
    if vehicle == nil then return false end

    -- Check vehicle itself (self-propelled compactor)
    local vehicleConfig = siloAssistEquipmentConfig.getConfig(vehicle)
    if vehicleConfig ~= nil and vehicleConfig.toolType == "compactor" then
        return true
    end
    if vehicle.spec_bunkerSiloCompacter ~= nil then
        return true
    end

    -- Check attached implements
    if vehicle.getAttachedImplements ~= nil then
        for _, implement in ipairs(vehicle:getAttachedImplements()) do
            local impl = implement.object
            if impl ~= nil then
                local implConfig = siloAssistEquipmentConfig.getConfig(impl)
                if implConfig ~= nil and implConfig.toolType == "compactor" then
                    return true
                end
                if impl.spec_bunkerSiloCompacter ~= nil then
                    return true
                end
            end
        end
    end

    return false
end

---------------------------------------------------------------------
-- Check if any attached implement (or vehicle) has an equipment
-- config entry. Used for HUD display decisions.
---------------------------------------------------------------------
function siloAssistEquipmentConfig.hasEquipmentConfig(vehicle)
    if vehicle == nil then return false end

    local vehicleConfig = siloAssistEquipmentConfig.getConfig(vehicle)
    if vehicleConfig ~= nil then return true end

    if vehicle.getAttachedImplements ~= nil then
        for _, implement in ipairs(vehicle:getAttachedImplements()) do
            local impl = implement.object
            if impl ~= nil then
                local implConfig = siloAssistEquipmentConfig.getConfig(impl)
                if implConfig ~= nil then return true end
            end
        end
    end

    return false
end

---------------------------------------------------------------------
-- Get the effective toolType for an implement/vehicle.
-- Returns the XML config toolType if present, otherwise nil
-- (meaning automatic detection should be used).
---------------------------------------------------------------------
function siloAssistEquipmentConfig.getEffectiveToolType(vehicleOrImpl)
    local cfg = siloAssistEquipmentConfig.getConfig(vehicleOrImpl)
    if cfg ~= nil and cfg.toolType ~= nil then
        return cfg.toolType
    end
    return nil
end

---------------------------------------------------------------------
-- Get the effective controlMode for an implement/vehicle.
-- Returns the XML config controlMode if present, otherwise nil.
---------------------------------------------------------------------
function siloAssistEquipmentConfig.getEffectiveControlMode(vehicleOrImpl)
    local cfg = siloAssistEquipmentConfig.getConfig(vehicleOrImpl)
    if cfg ~= nil and cfg.controlMode ~= nil then
        return cfg.controlMode
    end
    return nil
end

---------------------------------------------------------------------
-- Get the effective attachType for an implement/vehicle.
-- Returns the XML config attachType if present, otherwise nil.
---------------------------------------------------------------------
function siloAssistEquipmentConfig.getEffectiveAttachType(vehicleOrImpl)
    local cfg = siloAssistEquipmentConfig.getConfig(vehicleOrImpl)
    if cfg ~= nil and cfg.attachType ~= nil then
        return cfg.attachType
    end
    return nil
end

---------------------------------------------------------------------
-- Get custom axis names from config.
-- Returns armAxisName, dumpAxisName (both may be nil).
---------------------------------------------------------------------
function siloAssistEquipmentConfig.getAxisNames(vehicleOrImpl)
    local cfg = siloAssistEquipmentConfig.getConfig(vehicleOrImpl)
    if cfg ~= nil then
        return cfg.armAxisName, cfg.dumpAxisName
    end
    return nil, nil
end

---------------------------------------------------------------------
-- Reset configs (called on deleteMap)
---------------------------------------------------------------------
function siloAssistEquipmentConfig.reset()
    siloAssistEquipmentConfig.configs = {}
end