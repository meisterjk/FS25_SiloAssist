--====================================================================
-- SiloAssist - Per-Vehicle State Manager
-- Stores hudVisible, siloMode, heightOffset per vehicle.
-- Persisted to savegame via XML. Runtime state (isStuck etc.)
-- is NOT persisted.
--====================================================================

siloAssistVehicleState = {}

siloAssistVehicleState.vehicleStates = {}
siloAssistVehicleState.currentVehicle = nil
siloAssistVehicleState.currentState = nil

siloAssistVehicleState.xmlSchema = XMLSchema.new("siloAssistVehicles")
siloAssistVehicleState.xmlSchema:register(XMLValueType.STRING, "siloAssistVehicles.vehicle(?)#configFile", "")
siloAssistVehicleState.xmlSchema:register(XMLValueType.STRING, "siloAssistVehicles.vehicle(?)#siloMode", "driveThrough")
siloAssistVehicleState.xmlSchema:register(XMLValueType.FLOAT, "siloAssistVehicles.vehicle(?)#heightOffset", 0.0)
siloAssistVehicleState.xmlSchema:register(XMLValueType.FLOAT, "siloAssistVehicles.vehicle(?)#tiltOffset", 0)
siloAssistVehicleState.xmlSchema:register(XMLValueType.FLOAT, "siloAssistVehicles.vehicle(?)#followFactor", 0.5)
siloAssistVehicleState.xmlSchema:register(XMLValueType.FLOAT, "siloAssistVehicles.vehicle(?)#lookaheadTime", 1.5)
siloAssistVehicleState.xmlSchema:register(XMLValueType.FLOAT, "siloAssistVehicles.vehicle(?)#topoGain", 0.0)
siloAssistVehicleState.xmlSchema:register(XMLValueType.BOOL, "siloAssistVehicles.vehicle(?)#hudVisible", false)

---------------------------------------------------------------------
-- Get a stable key for a vehicle (based on configFileName)
---------------------------------------------------------------------
function siloAssistVehicleState.getVehicleKey(vehicle)
    if vehicle == nil then
        return nil
    end
    local key = vehicle.configFileName
    if key == nil then
        return nil
    end
    key = string.lower(key)
    key = string.gsub(key, "[/\\]", "/")
    return key
end

---------------------------------------------------------------------
-- Create a default state table
---------------------------------------------------------------------
function siloAssistVehicleState.createDefaultState()
    return {
        state = siloAssistConfig.STATE_OFF,
        hudVisible = false,
        siloMode = siloAssistConfig.DEFAULT_SILO_MODE,
        heightOffset = siloAssistConfig.DEFAULT_HEIGHT_OFFSET,
        tiltOffset = siloAssistConfig.DEFAULT_TILT_OFFSET,
        followFactor = siloAssistConfig.FOLLOW_FACTOR,
        lookaheadTime = siloAssistConfig.LOOKAHEAD_TIME,
        topoGain = siloAssistConfig.TOPO_MAP_CORRECTION_GAIN,
    }
end

---------------------------------------------------------------------
-- Get or create state for a vehicle
---------------------------------------------------------------------
function siloAssistVehicleState.getForVehicle(vehicle)
    local key = siloAssistVehicleState.getVehicleKey(vehicle)
    if key == nil then
        return siloAssistVehicleState.createDefaultState()
    end
    local state = siloAssistVehicleState.vehicleStates[key]
    if state == nil then
        state = siloAssistVehicleState.createDefaultState()
        siloAssistVehicleState.vehicleStates[key] = state
    end
    return state
end

---------------------------------------------------------------------
-- Switch to a different vehicle
-- Saves current state, loads new vehicle's state.
-- Returns true if the vehicle actually changed.
---------------------------------------------------------------------
function siloAssistVehicleState.switchVehicle(newVehicle)
    if newVehicle == siloAssistVehicleState.currentVehicle then
        return false
    end

    siloAssistVehicleState.saveCurrentVehicleState()

    siloAssistVehicleState.currentVehicle = newVehicle

    if newVehicle ~= nil then
        siloAssistVehicleState.currentState = siloAssistVehicleState.getForVehicle(newVehicle)
    else
        siloAssistVehicleState.currentState = nil
    end

    return true
end

---------------------------------------------------------------------
-- Save current vehicle's persistent settings back to the table
---------------------------------------------------------------------
function siloAssistVehicleState.saveCurrentVehicleState()
    if siloAssistVehicleState.currentVehicle == nil or siloAssistVehicleState.currentState == nil then
        return
    end
    local key = siloAssistVehicleState.getVehicleKey(siloAssistVehicleState.currentVehicle)
    if key == nil then
        return
    end
    siloAssistVehicleState.vehicleStates[key] = siloAssistVehicleState.currentState
end

---------------------------------------------------------------------
-- Convenience: get current state value or default
---------------------------------------------------------------------
function siloAssistVehicleState.getState()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.state
    end
    return siloAssistConfig.STATE_OFF
end

function siloAssistVehicleState.setState(newState)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.state = newState
    end
end

function siloAssistVehicleState.isHudVisible()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.hudVisible
    end
    return false
end

function siloAssistVehicleState.setHudVisible(visible)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.hudVisible = visible
    end
end

function siloAssistVehicleState.getSiloMode()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.siloMode
    end
    return siloAssistConfig.DEFAULT_SILO_MODE
end

function siloAssistVehicleState.setSiloMode(mode)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.siloMode = mode
    end
end

function siloAssistVehicleState.getHeightOffset()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.heightOffset
    end
    return siloAssistConfig.DEFAULT_HEIGHT_OFFSET
end

function siloAssistVehicleState.setHeightOffset(offset)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.heightOffset = math.clamp(
            offset,
            siloAssistConfig.OFFSET_MIN,
            siloAssistConfig.OFFSET_MAX
        )
    end
end

function siloAssistVehicleState.getTiltOffset()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.tiltOffset
    end
    return siloAssistConfig.DEFAULT_TILT_OFFSET
end

function siloAssistVehicleState.getFollowFactor()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.followFactor
    end
    return siloAssistConfig.FOLLOW_FACTOR
end

function siloAssistVehicleState.setFollowFactor(factor)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.followFactor = math.clamp(
            factor,
            siloAssistConfig.FOLLOW_MIN,
            siloAssistConfig.FOLLOW_MAX
        )
    end
end

function siloAssistVehicleState.getLookaheadTime()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.lookaheadTime
    end
    return siloAssistConfig.LOOKAHEAD_TIME
end

function siloAssistVehicleState.setLookaheadTime(time)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.lookaheadTime = math.clamp(
            time,
            siloAssistConfig.LOOKAHEAD_MIN,
            siloAssistConfig.LOOKAHEAD_MAX
        )
    end
end

function siloAssistVehicleState.setTiltOffset(offset)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.tiltOffset = math.clamp(
            offset,
            siloAssistConfig.TILT_MIN,
            siloAssistConfig.TILT_MAX
        )
    end
end

function siloAssistVehicleState.getTopoGain()
    if siloAssistVehicleState.currentState ~= nil then
        return siloAssistVehicleState.currentState.topoGain
    end
    return siloAssistConfig.TOPO_MAP_CORRECTION_GAIN
end

function siloAssistVehicleState.setTopoGain(gain)
    if siloAssistVehicleState.currentState ~= nil then
        siloAssistVehicleState.currentState.topoGain = math.clamp(
            gain, 0, siloAssistConfig.TOPO_MAP_CORRECTION_MAX)
    end
end

---------------------------------------------------------------------
-- Reset runtime state (called when deactivating or switching vehicles)
---------------------------------------------------------------------
function siloAssistVehicleState.resetRuntimeState()
    siloAssistState.isStuck = false
    siloAssistState.stuckTimer = 0
    siloAssistState.isReversing = false
    siloAssistState.wasReversing = false
    siloAssistState.wasInSilo = false
end

---------------------------------------------------------------------
-- Reset all states (called on loadMap)
---------------------------------------------------------------------
function siloAssistVehicleState.resetAll()
    siloAssistVehicleState.vehicleStates = {}
    siloAssistVehicleState.currentVehicle = nil
    siloAssistVehicleState.currentState = nil
    siloAssistVehicleState.resetRuntimeState()
end

---------------------------------------------------------------------
-- Save to XML (called on saveToXMLFile event)
---------------------------------------------------------------------
function siloAssistVehicleState.saveToXML()
    siloAssistVehicleState.saveCurrentVehicleState()

    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return
    end
    local saveDir = g_currentMission.missionInfo.savegameDirectory
    if saveDir == nil then
        return
    end
    local filePath = saveDir .. "/siloAssist.xml"
    local xmlFile = XMLFile.create("siloAssistState", filePath, "siloAssistVehicles", siloAssistVehicleState.xmlSchema)
    if xmlFile == nil then
        return
    end

    local i = 0
    for key, state in pairs(siloAssistVehicleState.vehicleStates) do
        local vKey = string.format("siloAssistVehicles.vehicle(%d)", i)
        xmlFile:setString(vKey .. "#configFile", key)
        xmlFile:setString(vKey .. "#siloMode", state.siloMode or siloAssistConfig.DEFAULT_SILO_MODE)
        xmlFile:setFloat(vKey .. "#heightOffset", state.heightOffset or siloAssistConfig.DEFAULT_HEIGHT_OFFSET)
        xmlFile:setFloat(vKey .. "#tiltOffset", state.tiltOffset or siloAssistConfig.DEFAULT_TILT_OFFSET)
        xmlFile:setFloat(vKey .. "#followFactor", state.followFactor or siloAssistConfig.FOLLOW_FACTOR)
        xmlFile:setFloat(vKey .. "#lookaheadTime", state.lookaheadTime or siloAssistConfig.LOOKAHEAD_TIME)
        xmlFile:setFloat(vKey .. "#topoGain", state.topoGain or siloAssistConfig.TOPO_MAP_CORRECTION_GAIN)
        xmlFile:setBool(vKey .. "#hudVisible", state.hudVisible or false)
        i = i + 1
    end

    xmlFile:save()
    xmlFile:delete()
end

---------------------------------------------------------------------
-- Load from XML (called on loadMap, after savegame is available)
---------------------------------------------------------------------
function siloAssistVehicleState.loadFromXML()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return
    end
    local saveDir = g_currentMission.missionInfo.savegameDirectory
    if saveDir == nil then
        return
    end
    local filePath = saveDir .. "/siloAssist.xml"
    if not fileExists(filePath) then
        return
    end

    local xmlFile = XMLFile.loadIfExists("siloAssistLoad", filePath, siloAssistVehicleState.xmlSchema)
    if xmlFile == nil then
        return
    end

    local i = 0
    while true do
        local vKey = string.format("siloAssistVehicles.vehicle(%d)", i)
        if not xmlFile:hasProperty(vKey) then
            break
        end

        local configFile = xmlFile:getString(vKey .. "#configFile") or ""
        local siloMode = xmlFile:getString(vKey .. "#siloMode") or siloAssistConfig.DEFAULT_SILO_MODE
        local heightOffset = xmlFile:getFloat(vKey .. "#heightOffset") or siloAssistConfig.DEFAULT_HEIGHT_OFFSET
        local tiltOffset = xmlFile:getFloat(vKey .. "#tiltOffset") or siloAssistConfig.DEFAULT_TILT_OFFSET
        local followFactor = xmlFile:getFloat(vKey .. "#followFactor") or siloAssistConfig.FOLLOW_FACTOR
        local lookaheadTime = xmlFile:getFloat(vKey .. "#lookaheadTime") or siloAssistConfig.LOOKAHEAD_TIME
        local topoGain = xmlFile:getFloat(vKey .. "#topoGain") or siloAssistConfig.TOPO_MAP_CORRECTION_GAIN
        local hudVisible = xmlFile:getBool(vKey .. "#hudVisible") or false

        if configFile ~= "" then
            local normalizedKey = string.lower(configFile)
            normalizedKey = string.gsub(normalizedKey, "[/\\]", "/")

            local state = siloAssistVehicleState.createDefaultState()
            state.siloMode = siloMode
            state.heightOffset = heightOffset
            state.tiltOffset = tiltOffset
            state.followFactor = followFactor
            state.lookaheadTime = lookaheadTime
            state.topoGain = topoGain
            state.hudVisible = hudVisible
            state.state = siloAssistConfig.STATE_OFF
            siloAssistVehicleState.vehicleStates[normalizedKey] = state
        end

        i = i + 1
    end

    xmlFile:delete()
end