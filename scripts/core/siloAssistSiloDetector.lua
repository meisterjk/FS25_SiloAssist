--====================================================================
-- SiloAssist - Silo Detector
-- Responsibility: find silo for vehicle, track position/progress,
-- calculate fill height (staged & smoothed).
--====================================================================

siloAssistSiloDetector = {}

---------------------------------------------------------------------
-- Local helper: extract area delta vectors + length/width
---------------------------------------------------------------------
local function getSiloAreaVectors(area)
    if area == nil then
        return nil
    end
    local dhx, dhz, dwx, dwz
    if area.dhx ~= nil then
        dhx, dhz = area.dhx, area.dhz
        dwx, dwz = area.dwx, area.dwz
    else
        dhx = area.hx - area.sx
        dhz = area.hz - area.sz
        dwx = area.wx - area.sx
        dwz = area.wz - area.sz
    end
    local length = MathUtil.vector3Length(dhx, 0, dhz)
    local width = MathUtil.vector3Length(dwx, 0, dwz)
    return dhx, dhz, dwx, dwz, length, width
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
siloAssistSiloDetector.currentSilo = nil
siloAssistSiloDetector.currentSiloArea = nil
siloAssistSiloDetector.isInSilo = false
siloAssistSiloDetector.progress = 0.0
siloAssistSiloDetector.lateralPos = 0.5
siloAssistSiloDetector.siloLength = 0.0
siloAssistSiloDetector.siloWidth = 0.0
siloAssistSiloDetector.wasAtSiloEnd = false
siloAssistSiloDetector.siloFillLevel = 0
siloAssistSiloDetector.siloCompactedPercent = 0
siloAssistSiloDetector.siloState = 0
siloAssistSiloDetector.siloFillType = 0
siloAssistSiloDetector.siloFillHeightAtVehicle = 0
siloAssistSiloDetector.siloTerrainHeightAtVehicle = 0
siloAssistSiloDetector.siloDensityHeightAtVehicle = 0
siloAssistSiloDetector.siloEstimatedCapacity = 0
siloAssistSiloDetector.estimatedFillHeight = 0
siloAssistSiloDetector.densityFillHeightAtVehicle = 0
siloAssistSiloDetector.smoothedFillHeight = 0
siloAssistSiloDetector.stagedFillHeight = 0
siloAssistSiloDetector.wasInSilo = false
siloAssistSiloDetector.densityFillHeightAtBlade = 0
siloAssistSiloDetector.vehicleSpeed = 0
siloAssistSiloDetector.vehicleX = 0
siloAssistSiloDetector.vehicleY = 0
siloAssistSiloDetector.vehicleZ = 0

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
function siloAssistSiloDetector.reset()
    siloAssistSiloDetector.currentSilo = nil
    siloAssistSiloDetector.currentSiloArea = nil
    siloAssistSiloDetector.isInSilo = false
    siloAssistSiloDetector.progress = 0.0
    siloAssistSiloDetector.lateralPos = 0.5
    siloAssistSiloDetector.siloLength = 0.0
    siloAssistSiloDetector.siloWidth = 0.0
    siloAssistSiloDetector.wasAtSiloEnd = false
    siloAssistSiloDetector.siloFillLevel = 0
    siloAssistSiloDetector.siloCompactedPercent = 0
    siloAssistSiloDetector.siloState = 0
    siloAssistSiloDetector.siloFillType = 0
    siloAssistSiloDetector.siloFillHeightAtVehicle = 0
    siloAssistSiloDetector.siloTerrainHeightAtVehicle = 0
    siloAssistSiloDetector.siloDensityHeightAtVehicle = 0
    siloAssistSiloDetector.siloEstimatedCapacity = 0
    siloAssistSiloDetector.estimatedFillHeight = 0
    siloAssistSiloDetector.smoothedFillHeight = 0
    siloAssistSiloDetector.stagedFillHeight = 0
    siloAssistSiloDetector.wasInSilo = false
    siloAssistSiloDetector.densityFillHeightAtVehicle = 0
    siloAssistSiloDetector.densityFillHeightAtBlade = 0
    siloAssistSiloDetector.vehicleSpeed = 0
    siloAssistSiloDetector.vehicleX = 0
    siloAssistSiloDetector.vehicleY = 0
    siloAssistSiloDetector.vehicleZ = 0
end

---------------------------------------------------------------------
-- Silo area helper
---------------------------------------------------------------------
function siloAssistSiloDetector.getSiloArea(silo)
    if silo == nil or silo.bunkerSiloArea == nil then
        return nil
    end
    local area = silo.bunkerSiloArea
    if area.inner ~= nil then
        return area.inner
    end
    return area
end

---------------------------------------------------------------------
-- Find silo for vehicle
---------------------------------------------------------------------
function siloAssistSiloDetector.findSiloForVehicle(vehicle)
    if g_currentMission == nil then
        return nil
    end

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)

    local silos = g_currentMission.placeableSystem:getBunkerSilos()
    if silos ~= nil then
        for _, placeable in ipairs(silos) do
            if placeable.spec_bunkerSilo ~= nil then
                local silo = placeable.spec_bunkerSilo.bunkerSilo
                if silo ~= nil and silo.vehiclesInRange then
                    if silo.vehiclesInRange[vehicle] then
                        siloAssistDebug.logThrottled("Silo", "findSilo", "found via vehiclesInRange")
                        return silo
                    end
                end
            end
        end

        for _, placeable in ipairs(silos) do
            if placeable.spec_bunkerSilo ~= nil then
                local silo = placeable.spec_bunkerSilo.bunkerSilo
                if silo ~= nil then
                    if siloAssistSiloDetector.isVehicleInSiloArea(vx, vz, silo) then
                        siloAssistDebug.logThrottled("Silo", "findSilo", "found via point-in-area fallback")
                        return silo
                    end
                end
            end
        end
    end

    return nil
end

---------------------------------------------------------------------
-- Point-in-silo check
---------------------------------------------------------------------
function siloAssistSiloDetector.isVehicleInSiloArea(vx, vz, silo)
    local area = siloAssistSiloDetector.getSiloArea(silo)
    if area == nil then
        return false
    end

    local dhx, dhz, dwx, dwz = getSiloAreaVectors(area)
    if dhx == nil then
        return false
    end

    return MathUtil.isPointInParallelogram(vx, vz, area.sx, area.sz, dwx, dwz, dhx, dhz)
end

---------------------------------------------------------------------
-- Near-silo check
---------------------------------------------------------------------
function siloAssistSiloDetector.isNearSilo(vehicle, distance)
    if g_currentMission == nil then
        return false, nil, 999
    end

    local silos = g_currentMission.placeableSystem:getBunkerSilos()
    if silos == nil then
        return false, nil, 999
    end

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)

    for _, placeable in ipairs(silos) do
        if placeable.spec_bunkerSilo ~= nil then
            local silo = placeable.spec_bunkerSilo.bunkerSilo
            if silo ~= nil then
                local area = siloAssistSiloDetector.getSiloArea(silo)
                if area ~= nil then
                    local dhx, dhz, dwx, dwz, length, width = getSiloAreaVectors(area)
                    if dhx ~= nil then
                        local cx = area.sx + dhx * 0.5 + dwx * 0.5
                        local cz = area.sz + dhz * 0.5 + dwz * 0.5
                        local siloDist = MathUtil.vector2Length(vx - cx, vz - cz)
                        local halfDiag = math.max(length, width) * 0.5
                        local distToEdge = siloDist - halfDiag

                        if distToEdge < distance then
                            return true, silo, distToEdge
                        end
                    end
                end
            end
        end
    end

    return false, nil, 999
end

---------------------------------------------------------------------
-- Update: called every frame
---------------------------------------------------------------------
function siloAssistSiloDetector.update(vehicle, dt)
    if vehicle == nil then
        siloAssistSiloDetector.reset()
        return
    end

    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    siloAssistSiloDetector.vehicleX = vx
    siloAssistSiloDetector.vehicleY = vy
    siloAssistSiloDetector.vehicleZ = vz
    siloAssistSiloDetector.vehicleSpeed = vehicle:getLastSpeed()

    local silo = siloAssistSiloDetector.findSiloForVehicle(vehicle)

    if silo == nil then
        siloAssistSiloDetector.currentSilo = nil
        siloAssistSiloDetector.currentSiloArea = nil
        siloAssistSiloDetector.isInSilo = false
        siloAssistSiloDetector.progress = 0.0
        siloAssistSiloDetector.lateralPos = 0.5
        siloAssistSiloDetector.siloFillLevel = 0
        siloAssistSiloDetector.siloCompactedPercent = 0
        siloAssistSiloDetector.siloState = 0
        siloAssistSiloDetector.siloFillType = 0
        siloAssistSiloDetector.siloFillHeightAtVehicle = 0
        siloAssistSiloDetector.siloTerrainHeightAtVehicle = 0
        siloAssistSiloDetector.siloDensityHeightAtVehicle = 0
        siloAssistSiloDetector.siloEstimatedCapacity = 0
        siloAssistSiloDetector.estimatedFillHeight = 0
        siloAssistSiloDetector.stagedFillHeight = 0
        siloAssistSiloDetector.smoothedFillHeight = 0
        siloAssistSiloDetector.densityFillHeightAtVehicle = 0
        siloAssistSiloDetector.densityFillHeightAtBlade = 0
        siloAssistSiloDetector.wasInSilo = false
        return
    end

    local area = siloAssistSiloDetector.getSiloArea(silo)

    siloAssistSiloDetector.currentSilo = silo
    siloAssistSiloDetector.currentSiloArea = area
    siloAssistSiloDetector.isInSilo = true

    siloAssistSiloDetector.progress = siloAssistSiloDetector.getPositionInSilo(vehicle, silo, area)
    siloAssistSiloDetector.lateralPos = siloAssistSiloDetector.getLateralPositionInSilo(vehicle, silo, area)

    local dhx, dhz, dwx, dwz, length, width = getSiloAreaVectors(area)
    siloAssistSiloDetector.siloLength = length or 0
    siloAssistSiloDetector.siloWidth = width or 0

    siloAssistSiloDetector.siloFillLevel = silo.fillLevel or 0
    siloAssistSiloDetector.siloCompactedPercent = silo.compactedPercent or 0
    siloAssistSiloDetector.siloState = silo.state or 0
    siloAssistSiloDetector.siloFillType = silo.inputFillType or 0
    siloAssistSiloDetector.siloEstimatedCapacity = siloAssistSiloDetector.estimateCapacity(silo)
    siloAssistSiloDetector.estimatedFillHeight = siloAssistSiloDetector.getEstimatedFillHeight()

    local terrainHeight, densityHeight = DensityMapHeightUtil.getHeightAtWorldPos(vx, vy, vz)
    siloAssistSiloDetector.siloTerrainHeightAtVehicle = terrainHeight
    siloAssistSiloDetector.siloDensityHeightAtVehicle = densityHeight or terrainHeight
    siloAssistSiloDetector.densityFillHeightAtVehicle = math.max(densityHeight - terrainHeight, 0)

    local bladeNode = siloAssistToolDetection.bladeNode
    if bladeNode ~= nil then
        local bx, by, bz = getWorldTranslation(bladeNode)
        local bTerrainH, bDensityH = DensityMapHeightUtil.getHeightAtWorldPos(bx, by, bz)
        siloAssistSiloDetector.densityFillHeightAtBlade = math.max(bDensityH - bTerrainH, 0)
    else
        siloAssistSiloDetector.densityFillHeightAtBlade = 0
    end

    siloAssistSiloDetector.siloFillHeightAtVehicle = math.max(
        siloAssistSiloDetector.densityFillHeightAtVehicle,
        siloAssistSiloDetector.densityFillHeightAtBlade
    )

    local rawFillHeight = math.max(
        siloAssistSiloDetector.siloFillHeightAtVehicle,
        siloAssistSiloDetector.estimatedFillHeight
    )

    if not siloAssistSiloDetector.wasInSilo then
        siloAssistSiloDetector.smoothedFillHeight = rawFillHeight
        siloAssistSiloDetector.wasInSilo = true
    else
        local smoothing = siloAssistConfig.FILL_HEIGHT_SMOOTHING
        siloAssistSiloDetector.smoothedFillHeight = siloAssistSiloDetector.smoothedFillHeight * smoothing + rawFillHeight * (1 - smoothing)
    end

    siloAssistSiloDetector.stagedFillHeight = siloAssistSiloDetector.getStagedFillHeight()

    siloAssistDebug.logThrottled("Silo", "update", string.format(
        "inSilo=%s prog=%.3f lat=%.3f fillLvl=%d fillH=%.3f stageH=%.3f smoothH=%.3f len=%.1f wid=%.1f",
        tostring(siloAssistSiloDetector.isInSilo),
        siloAssistSiloDetector.progress,
        siloAssistSiloDetector.lateralPos,
        siloAssistSiloDetector.siloFillLevel,
        siloAssistSiloDetector.siloFillHeightAtVehicle,
        siloAssistSiloDetector.stagedFillHeight,
        siloAssistSiloDetector.smoothedFillHeight,
        siloAssistSiloDetector.siloLength,
        siloAssistSiloDetector.siloWidth
    ))
end

---------------------------------------------------------------------
-- Position calculations
---------------------------------------------------------------------
function siloAssistSiloDetector.getPositionInSilo(vehicle, silo, area)
    if area == nil then
        area = siloAssistSiloDetector.getSiloArea(silo)
    end
    if area == nil then
        return 0
    end

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)

    local dhx, dhz = getSiloAreaVectors(area)
    if dhx == nil then
        return 0
    end

    local dx = vx - area.sx
    local dz = vz - area.sz
    local lengthSq = dhx * dhx + dhz * dhz

    if lengthSq < 0.001 then
        return 0
    end

    local dot = dx * dhx + dz * dhz
    return math.clamp(dot / lengthSq, 0, 1)
end

function siloAssistSiloDetector.getLateralPositionInSilo(vehicle, silo, area)
    if area == nil then
        area = siloAssistSiloDetector.getSiloArea(silo)
    end
    if area == nil then
        return 0.5
    end

    local vx, _, vz = getWorldTranslation(vehicle.rootNode)

    local _, _, dwx, dwz = getSiloAreaVectors(area)
    if dwx == nil then
        return 0.5
    end

    local dx = vx - area.sx
    local dz = vz - area.sz
    local widthSq = dwx * dwx + dwz * dwz

    if widthSq < 0.001 then
        return 0.5
    end

    local dot = dx * dwx + dz * dwz
    return math.clamp(dot / widthSq, 0, 1)
end

---------------------------------------------------------------------
-- Fill height calculations
---------------------------------------------------------------------
function siloAssistSiloDetector.getEstimatedFillHeight()
    local length = siloAssistSiloDetector.siloLength
    local width = siloAssistSiloDetector.siloWidth
    local fillLevel = siloAssistSiloDetector.siloFillLevel
    if length <= 0 or width <= 0 then
        return 0
    end
    local volume = fillLevel / siloAssistConfig.DENSITY_LITERS_PER_CBM
    return volume / (length * width)
end

function siloAssistSiloDetector.getStagedFillHeight()
    local step = siloAssistConfig.FILL_LEVEL_STEP
    if step <= 0 then
        return siloAssistSiloDetector.smoothedFillHeight
    end

    local length = siloAssistSiloDetector.siloLength
    local width = siloAssistSiloDetector.siloWidth
    local fillLevel = siloAssistSiloDetector.siloFillLevel

    if length <= 0 or width <= 0 then
        return siloAssistSiloDetector.smoothedFillHeight
    end

    local stage = math.floor(fillLevel / step)
    local stagedFillLevel = (stage + 0.5) * step
    local volume = stagedFillLevel / siloAssistConfig.DENSITY_LITERS_PER_CBM
    return volume / (length * width)
end

function siloAssistSiloDetector.estimateCapacity(silo)
    local area = siloAssistSiloDetector.getSiloArea(silo)
    if area == nil then
        return 0
    end

    local dhx, dhz, dwx, dwz, length, width = getSiloAreaVectors(area)
    if length == nil then
        return 0
    end

    local maxH = siloAssistConfig.SILO_MAX_HEIGHT_M
    local estimatedLiters = length * width * maxH * 0.7 * 1000
    return math.max(estimatedLiters, 1)
end

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------
function siloAssistSiloDetector.getSiloStateName(state)
    if state == 0 then return "FILL"
    elseif state == 1 then return "CLOSED"
    elseif state == 2 then return "FERMENTED"
    elseif state == 3 then return "DRAIN"
    else return "?"
    end
end

function siloAssistSiloDetector.getFillHeightAtPosition(vehicle, silo)
    local vx, vy, vz = getWorldTranslation(vehicle.rootNode)
    local terrainHeight, densityHeight = DensityMapHeightUtil.getHeightAtWorldPos(vx, vy, vz)
    return math.max(densityHeight - terrainHeight, 0)
end

function siloAssistSiloDetector.getFillHeightAtBladePosition(bladeNode)
    if bladeNode == nil then
        return 0
    end
    local bx, by, bz = getWorldTranslation(bladeNode)
    local terrainHeight, densityHeight = DensityMapHeightUtil.getHeightAtWorldPos(bx, by, bz)
    return math.max(densityHeight - terrainHeight, 0)
end