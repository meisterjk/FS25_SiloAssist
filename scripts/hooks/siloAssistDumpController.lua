--====================================================================
-- SiloAssist - Shovel/Dump Controller
-- Handles continuous dumping when reversing with a shovel.
--====================================================================

siloAssistDumpController = {}

siloAssistDumpController.isDumping = false
siloAssistDumpController.dumpProgress = 0.0
siloAssistDumpController.lastProgress = 0.0
siloAssistDumpController.dumpDirection = 1

function siloAssistDumpController.reset()
    siloAssistDumpController.isDumping = false
    siloAssistDumpController.dumpProgress = 0.0
    siloAssistDumpController.lastProgress = 0.0
    siloAssistDumpController.dumpDirection = 1
end

function siloAssistDumpController.update(vehicle, silo, progress, dt)
    if vehicle == nil or siloAssistToolDetection.toolType ~= "shovel" then
        return
    end

    local config = siloAssistConfig

    if not siloAssistState.isReversing then
        if siloAssistDumpController.isDumping then
            siloAssistDumpController.resetDumpTool(vehicle)
            siloAssistDumpController.isDumping = false
        end
        return
    end

    if progress >= config.DUMP_POSITION_PCT then
        if not siloAssistDumpController.isDumping then
            siloAssistDumpController.isDumping = true
            siloAssistDumpController.dumpProgress = 0.0
        end
    end

    if siloAssistDumpController.isDumping then
        siloAssistDumpController.continuousDump(vehicle, dt)
    end
end

function siloAssistDumpController.continuousDump(vehicle, dt)
    local config = siloAssistConfig

    if siloAssistToolDetection.controlType ~= "cylindered" or siloAssistToolDetection.dumpToolIndex == nil then
        return
    end

    local dumpRate = 0.003

    local pitchDeg = siloAssistHeightController.lastPitchDeg
    if pitchDeg ~= nil and pitchDeg < -30 then
        dumpRate = 0.001
    end

    siloAssistDumpController.dumpProgress = math.min(siloAssistDumpController.dumpProgress + dumpRate * (dt / 33), 1.0)

    Cylindered.actionEventInput(siloAssistToolDetection.cylinderedVehicle or vehicle, "", 1, siloAssistToolDetection.dumpToolIndex, false)

    local spec = nil
    if siloAssistToolDetection.toolObject ~= nil and siloAssistToolDetection.toolObject.spec_cylindered ~= nil then
        spec = siloAssistToolDetection.toolObject.spec_cylindered
    elseif vehicle.spec_cylindered ~= nil then
        spec = vehicle.spec_cylindered
    end

    if spec ~= nil and siloAssistToolDetection.dumpToolIndex ~= nil then
        local tool = spec.movingTools[siloAssistToolDetection.dumpToolIndex]
        if tool ~= nil then
            local curRot = tool.curRot[1] or 0
            local rotMax = tool.rotMax[1] or 0
            if curRot >= rotMax * 0.95 then
                siloAssistDumpController.dumpProgress = 1.0
            end
        end
    end
end

function siloAssistDumpController.resetDumpTool(vehicle)
    if siloAssistToolDetection.controlType ~= "cylindered" or siloAssistToolDetection.dumpToolIndex == nil then
        return
    end

    Cylindered.actionEventInput(siloAssistToolDetection.cylinderedVehicle or vehicle, "", -1, siloAssistToolDetection.dumpToolIndex, false)
    siloAssistDumpController.dumpProgress = 0.0
end

function siloAssistDumpController.getDumpHeight(vehicle, fillHeight)
    local config = siloAssistConfig
    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vx, 0, vz)
    return terrainHeight + fillHeight + config.DUMP_HEIGHT_OFFSET
end