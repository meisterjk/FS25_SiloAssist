--====================================================================
-- SiloAssist - HUD
--====================================================================

siloAssistHud = {}

siloAssistHud.POS_X = 810
siloAssistHud.POS_Y = 60
siloAssistHud.WIDTH = 320
siloAssistHud.LINE_HEIGHT_PX = 20
siloAssistHud.HEADER_HEIGHT_PX = 22
siloAssistHud.MARGIN_PX = 6
siloAssistHud.CLOSE_SIZE_PX = 13
siloAssistHud.BTN_SIZE_PX = 16

siloAssistHud.FONT_SIZE_TITLE = 0.013
siloAssistHud.FONT_SIZE_DEFAULT = 0.011
siloAssistHud.FONT_SIZE_SMALL = 0.009

siloAssistHud.BG_COLOR = {0.0, 0.0, 0.0, 0.75}
siloAssistHud.HEADER_COLOR = {0.18, 0.35, 0.003, 1.0}
siloAssistHud.ROW_EVEN = {0.05, 0.05, 0.05, 0.5}
siloAssistHud.ROW_ODD = {0.0, 0.0, 0.0, 0.35}
siloAssistHud.COLOR_ACTIVE = {0.1, 0.7, 0.1, 0.95}
siloAssistHud.COLOR_OFF = {0.85, 0.15, 0.15, 0.95}
siloAssistHud.COLOR_CLOSE = {0.85, 0.2, 0.2, 0.9}
siloAssistHud.COLOR_WARN = {0.95, 0.75, 0.0, 0.9}
siloAssistHud.COLOR_CLICKABLE = {0.3, 0.85, 1.0, 0.95}
siloAssistHud.COLOR_CLICKABLE_HOVER = {0.5, 0.95, 1.0, 1.0}

siloAssistHud.FALLBACK_UVS = {0, 0, 1, 0, 1, 1, 0, 1}

siloAssistHud.isInitialized = false
siloAssistHud.x = nil
siloAssistHud.y = nil
siloAssistHud.hudWidth = nil
siloAssistHud.hudHeight = nil
siloAssistHud.hudPosX = nil
siloAssistHud.hudPosY = nil
siloAssistHud.isDragging = false
siloAssistHud.dragOffsetX = 0
siloAssistHud.dragOffsetY = 0

siloAssistHud.bgOverlay = nil
siloAssistHud.headerOverlay = nil
siloAssistHud.rowOverlays = {}
siloAssistHud.closeOverlay = nil
siloAssistHud.maxRowOverlays = 22

siloAssistHud.statusText = ""
siloAssistHud.statusTextTimer = 0
siloAssistHud.STATUS_TEXT_DURATION = 2000

siloAssistHud.mouseX = 0
siloAssistHud.mouseY = 0

siloAssistHud.modeLineY = nil
siloAssistHud.modeLineH = nil
siloAssistHud.offsetMinusBtn = nil
siloAssistHud.offsetPlusBtn = nil
siloAssistHud.debugBtnX = nil
siloAssistHud.debugBtnY = nil
siloAssistHud.debugBtnW = nil
siloAssistHud.debugBtnH = nil

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function siloAssistHud:init()
    if siloAssistHud.isInitialized then
        return
    end

    local texture = g_baseUIFilename
    if texture == nil then
        texture = 'dataS/menu/base/graph_pixel.png'
    end

    local uvs = g_colorBgUVs
    if uvs == nil then
        uvs = siloAssistHud.FALLBACK_UVS
    end

    if siloAssistHud.savedHudX ~= nil and siloAssistHud.savedHudY ~= nil then
        siloAssistHud.x = siloAssistHud.savedHudX
        siloAssistHud.y = siloAssistHud.savedHudY
    else
        siloAssistHud.x, siloAssistHud.y = getNormalizedScreenValues(siloAssistHud.POS_X, siloAssistHud.POS_Y)
    end

    siloAssistHud.bgOverlay = Overlay.new(texture, 0, 0, 0, 0)
    siloAssistHud.bgOverlay:setUVs(uvs)
    siloAssistHud.bgOverlay:setColor(unpack(siloAssistHud.BG_COLOR))

    siloAssistHud.headerOverlay = Overlay.new(texture, 0, 0, 0, 0)
    siloAssistHud.headerOverlay:setUVs(uvs)
    siloAssistHud.headerOverlay:setColor(unpack(siloAssistHud.HEADER_COLOR))

    for i = 1, siloAssistHud.maxRowOverlays do
        local ov = Overlay.new(texture, 0, 0, 0, 0)
        ov:setUVs(uvs)
        ov:setColor(unpack(siloAssistHud.ROW_ODD))
        siloAssistHud.rowOverlays[i] = ov
    end

    local closeW, closeH = getNormalizedScreenValues(siloAssistHud.CLOSE_SIZE_PX, siloAssistHud.CLOSE_SIZE_PX)
    siloAssistHud.closeOverlay = Overlay.new(texture, 0, 0, closeW, closeH)
    siloAssistHud.closeOverlay:setUVs(uvs)
    siloAssistHud.closeOverlay:setColor(unpack(siloAssistHud.COLOR_CLOSE))

    siloAssistHud.isInitialized = true
end

function siloAssistHud:toggle()
    siloAssistVehicleState.setHudVisible(not siloAssistVehicleState.isHudVisible())
end

function siloAssistHud.showStatusText(text)
    siloAssistHud.statusText = text
    siloAssistHud.statusTextTimer = siloAssistHud.STATUS_TEXT_DURATION
end

---------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------
function siloAssistHud:draw()
    if not siloAssistVehicleState.isHudVisible() then
        return
    end
    if g_currentMission == nil then
        return
    end

    siloAssistHud:init()
    if not siloAssistHud.isInitialized then
        return
    end

    siloAssistHud.modeLineY = nil
    siloAssistHud.modeLineH = nil
    siloAssistHud.offsetMinusBtn = nil
    siloAssistHud.offsetPlusBtn = nil
    siloAssistHud.debugBtnX = nil
    siloAssistHud.debugBtnY = nil
    siloAssistHud.debugBtnW = nil
    siloAssistHud.debugBtnH = nil

    local w, _ = getNormalizedScreenValues(siloAssistHud.WIDTH, 1)
    local m, _ = getNormalizedScreenValues(siloAssistHud.MARGIN_PX, 1)
    local _, hH = getNormalizedScreenValues(1, siloAssistHud.HEADER_HEIGHT_PX)
    local _, lH = getNormalizedScreenValues(1, siloAssistHud.LINE_HEIGHT_PX)
    local closeSzW, closeSzH = getNormalizedScreenValues(siloAssistHud.CLOSE_SIZE_PX, siloAssistHud.CLOSE_SIZE_PX)

    local uiScale = g_gameSettings:getValue("uiScale") or 1.0
    local fTitle = getCorrectTextSize(siloAssistHud.FONT_SIZE_TITLE * uiScale)
    local fDefault = getCorrectTextSize(siloAssistHud.FONT_SIZE_DEFAULT * uiScale)
    local fSmall = getCorrectTextSize(siloAssistHud.FONT_SIZE_SMALL * uiScale)

    local lines = siloAssistHud.buildLines()
    local numLines = #lines

    local totalH = hH + lH * numLines
    local x = siloAssistHud.x
    local y = siloAssistHud.y

    siloAssistHud.hudPosX = x
    siloAssistHud.hudPosY = y
    siloAssistHud.hudWidth = w
    siloAssistHud.hudHeight = totalH

    siloAssistHud.bgOverlay:setPosition(x, y)
    siloAssistHud.bgOverlay:setDimension(w, totalH)
    siloAssistHud.bgOverlay:render()

    siloAssistHud.headerOverlay:setPosition(x, y + totalH - hH)
    siloAssistHud.headerOverlay:setDimension(w, hH)
    siloAssistHud.headerOverlay:render()

    local isActive = siloAssistVehicleState.getState() == siloAssistConfig.STATE_ACTIVE
        or siloAssistVehicleState.getState() == siloAssistConfig.STATE_DUMPING
        or siloAssistVehicleState.getState() == siloAssistConfig.STATE_RAISING

    setTextColor(1, 1, 1, 0.95)
    setTextAlignment(RenderText.ALIGN_LEFT)
    local titleText = g_i18n:getText("sa_title")
    renderText(x + m, y + totalH - hH + hH * 0.2, fTitle, titleText)

    local statusColor = isActive and siloAssistHud.COLOR_ACTIVE or siloAssistHud.COLOR_OFF
    local statusLabel = isActive and g_i18n:getText("sa_statusActive") or g_i18n:getText("sa_statusOff")
    setTextColor(unpack(statusColor))
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(x + w - m - closeSzW - m - closeSzW - m, y + totalH - hH + hH * 0.2, fDefault, statusLabel)

    local debugLabel = "DBG"
    local debugColor = siloAssistDebug.enabled and {0.1, 0.85, 0.1, 0.95} or {0.8, 0.8, 0.8, 0.8}
    local debugBtnX = x + w - m - closeSzW - m
    local debugBtnY = y + totalH - hH + (hH - closeSzH) * 0.5
    siloAssistHud.debugBtnX = debugBtnX
    siloAssistHud.debugBtnY = debugBtnY
    siloAssistHud.debugBtnW = closeSzW
    siloAssistHud.debugBtnH = closeSzH

    setTextColor(unpack(debugColor))
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(debugBtnX + closeSzW * 0.5, y + totalH - hH + hH * 0.2, fSmall, debugLabel)

    local closeBtnX = x + w - m - closeSzW
    local closeBtnY = y + totalH - hH + (hH - closeSzH) * 0.5
    siloAssistHud.closeOverlay:setPosition(closeBtnX, closeBtnY)
    siloAssistHud.closeOverlay:setDimension(closeSzW, closeSzH)
    siloAssistHud.closeOverlay:render()

    for i, line in ipairs(lines) do
        local rowY = y + totalH - hH - lH * i
        local rowColor = (i % 2 == 0) and siloAssistHud.ROW_EVEN or siloAssistHud.ROW_ODD

        if i <= siloAssistHud.maxRowOverlays then
            local rowOv = siloAssistHud.rowOverlays[i]
            rowOv:setPosition(x, rowY)
            rowOv:setDimension(w, lH)
            rowOv:setColor(unpack(rowColor))
            rowOv:render()
        end

        local textY = rowY + lH * 0.15
        setTextColor(1, 1, 1, 0.9)
        setTextAlignment(RenderText.ALIGN_LEFT)

        if line.clickable then
            siloAssistHud.modeLineY = rowY
            siloAssistHud.modeLineH = lH
            local isHover = siloAssistHud.mouseX >= x and siloAssistHud.mouseX <= x + w
                and siloAssistHud.mouseY >= rowY and siloAssistHud.mouseY <= rowY + lH
            if isHover then
                setTextColor(unpack(siloAssistHud.COLOR_CLICKABLE_HOVER))
            else
                setTextColor(unpack(siloAssistHud.COLOR_CLICKABLE))
            end
        elseif line.offsetLine then
            local offsetSign = siloAssistVehicleState.getHeightOffset() >= 0 and "+" or ""
            local offsetValStr = string.format("%s%.2fm", offsetSign, siloAssistVehicleState.getHeightOffset())
            local labelStr = g_i18n:getText("sa_offset") .. ": "

            renderText(x + m, textY, fDefault, labelStr)

            local labelWidth = getTextWidth(fDefault, labelStr)
            setTextColor(1, 1, 1, 0.9)
            renderText(x + m + labelWidth, textY, fDefault, offsetValStr)

            local btnAreaW, btnAreaH = getNormalizedScreenValues(siloAssistHud.BTN_SIZE_PX, siloAssistHud.LINE_HEIGHT_PX)
            local minusBtnX = x + w - m - btnAreaW * 2 - m
            local plusBtnX = x + w - m - btnAreaW

            local hoverMinus = siloAssistHud.mouseX >= minusBtnX and siloAssistHud.mouseX <= minusBtnX + btnAreaW
                and siloAssistHud.mouseY >= rowY and siloAssistHud.mouseY <= rowY + lH
            local hoverPlus = siloAssistHud.mouseX >= plusBtnX and siloAssistHud.mouseX <= plusBtnX + btnAreaW
                and siloAssistHud.mouseY >= rowY and siloAssistHud.mouseY <= rowY + lH

            siloAssistHud.offsetMinusBtn = { x = minusBtnX, y = rowY, w = btnAreaW, h = lH }
            siloAssistHud.offsetPlusBtn = { x = plusBtnX, y = rowY, w = btnAreaW, h = lH }

            setTextColor(unpack(hoverMinus and siloAssistHud.COLOR_CLICKABLE_HOVER or siloAssistHud.COLOR_CLICKABLE))
            setTextAlignment(RenderText.ALIGN_CENTER)
            renderText(minusBtnX + btnAreaW * 0.5, textY, fDefault, "-")

            setTextColor(unpack(hoverPlus and siloAssistHud.COLOR_CLICKABLE_HOVER or siloAssistHud.COLOR_CLICKABLE))
            renderText(plusBtnX + btnAreaW * 0.5, textY, fDefault, "+")

            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(1, 1, 1, 1)
        elseif line.color then
            setTextColor(unpack(line.color))
        end

        if not line.offsetLine then
            renderText(x + m, textY, fDefault, line.text)
        end

        setTextColor(1, 1, 1, 1)
    end

    if siloAssistHud.statusTextTimer > 0 then
        setTextColor(unpack(siloAssistHud.COLOR_WARN))
        setTextAlignment(RenderText.ALIGN_CENTER)
        renderText(x + w * 0.5, y - lH * 0.5, fDefault, siloAssistHud.statusText)
        setTextColor(1, 1, 1, 1)
    end
end

---------------------------------------------------------------------
-- Build HUD lines
---------------------------------------------------------------------
function siloAssistHud.buildLines()
    local lines = {}
    local config = siloAssistConfig
    local isActive = siloAssistVehicleState.getState() == config.STATE_ACTIVE
        or siloAssistVehicleState.getState() == config.STATE_DUMPING
        or siloAssistVehicleState.getState() == config.STATE_RAISING

    local isWaiting = siloAssistVehicleState.getState() == config.STATE_WAITING

    local modeLabel = g_i18n:getText(config.getModeLabel())
    table.insert(lines, { text = string.format("%s: %s >>", g_i18n:getText("sa_mode"), modeLabel), clickable = true })

    table.insert(lines, { text = "", offsetLine = true })

    if (isActive or isWaiting) and siloAssistSiloDetector.isInSilo then
        if siloAssistSiloDetector.currentSilo ~= nil then
            local fillLevel = siloAssistSiloDetector.siloFillLevel
            local capacity = siloAssistSiloDetector.siloEstimatedCapacity
            local fillPct = 0
            if capacity > 0 then
                fillPct = math.min(fillLevel / capacity * 100, 100)
            end
            table.insert(lines, { text = string.format("%s: %s L (%.0f%%)", g_i18n:getText("sa_fill"), siloAssistHud.formatNumber(fillLevel), fillPct) })

            local compactedPct = siloAssistSiloDetector.siloCompactedPercent
            if compactedPct > 0 then
                table.insert(lines, { text = string.format("%s: %d%%", g_i18n:getText("sa_compact"), compactedPct) })
            end

            local stateName = siloAssistSiloDetector.getSiloStateName(siloAssistSiloDetector.siloState)
            table.insert(lines, { text = string.format("%s: %s", g_i18n:getText("sa_siloState"), stateName) })

            table.insert(lines, { text = string.format("%s: %.1f x %.1fm", g_i18n:getText("sa_siloSize"), siloAssistSiloDetector.siloLength, siloAssistSiloDetector.siloWidth) })

            table.insert(lines, { text = string.format("%s: %.2fm", g_i18n:getText("sa_fillH"), siloAssistSiloDetector.stagedFillHeight) })
        end

        local bladeH = siloAssistHeightController.lastRaycastGroundDistance
        local targetH = siloAssistHeightController.lastTargetHeightAboveGround
        local pitch = siloAssistHeightController.lastPitchDeg

        local bladeHStr = bladeH ~= nil and string.format("%.2fm", bladeH) or "--"
        local targetHStr = targetH ~= nil and string.format("%.2fm", targetH) or "--"
        local pitchStr = pitch ~= nil and string.format("%.1f", pitch) or "--"

        table.insert(lines, { text = string.format("Soll: %s | Ist: %s", targetHStr, bladeHStr) })

        local toolLabel = g_i18n:getText("sa_toolNone")
        if siloAssistToolDetection.toolType == "leveler" then
            if siloAssistToolDetection.controlType == "attacherJointControl" then
                toolLabel = g_i18n:getText("sa_toolLeveler3P")
            elseif siloAssistToolDetection.controlType == "cylindered" then
                toolLabel = g_i18n:getText("sa_toolLevelerWL")
            else
                toolLabel = g_i18n:getText("sa_toolLeveler")
            end
        elseif siloAssistToolDetection.toolType == "shovel" then
            toolLabel = g_i18n:getText("sa_toolShovel")
        end
        table.insert(lines, { text = string.format("%s: %s", g_i18n:getText("sa_tool"), toolLabel) })

        table.insert(lines, { text = string.format("%s: %.0f%% | %s: %.2f", g_i18n:getText("sa_progress"), siloAssistSiloDetector.progress * 100, g_i18n:getText("sa_lateral"), siloAssistSiloDetector.lateralPos) })

        table.insert(lines, { text = string.format("%s: %s %s", g_i18n:getText("sa_pitch"), pitchStr, "deg") })

        local speed = siloAssistSiloDetector.vehicleSpeed
        local directionStr = siloAssistState.isReversing and "<<<" or ">>>"
        table.insert(lines, { text = string.format("%s: %.1f km/h %s", g_i18n:getText("sa_speed"), speed, directionStr) })

        if siloAssistVehicleState.getState() == config.STATE_DUMPING then
            table.insert(lines, { text = g_i18n:getText("sa_dumping"), color = siloAssistHud.COLOR_WARN })
        elseif siloAssistVehicleState.getState() == config.STATE_RAISING then
            table.insert(lines, { text = g_i18n:getText("sa_stuck"), color = siloAssistHud.COLOR_WARN })
        end
    else
        table.insert(lines, { text = g_i18n:getText("sa_notInSilo") })
        local speed = siloAssistSiloDetector.vehicleSpeed
        local directionStr = siloAssistState.isReversing and "<<<" or ">>>"
        table.insert(lines, { text = string.format("%s: %.1f km/h %s", g_i18n:getText("sa_speed"), speed, directionStr) })
    end

    table.insert(lines, { text = string.format("%s: %s", g_i18n:getText("sa_state"), siloAssistVehicleState.getState()) })

    -- DEBUG section
    if siloAssistDebug.enabled then
        table.insert(lines, { text = string.format("Offset: %.3f | AlphaStep: %.3f | DBG ON", siloAssistVehicleState.getHeightOffset(), config.ALPHA_STEP), color = {0.1, 0.85, 0.1, 0.95} })
        table.insert(lines, { text = string.format("RampS: %.2f->%.2f | RampE: %.2f->%.2f | MaxH: %.1f", config.RAMP_START_PCT, config.RAMP_MIN_START_PCT, config.RAMP_END_PCT, config.RAMP_MAX_END_PCT, config.SILO_MAX_HEIGHT_M) })
        table.insert(lines, { text = string.format("EffRampS: %.2f | EffRampE: %.2f | Dens: %d", siloAssistHeightController.lastEffectiveRampStart, siloAssistHeightController.lastEffectiveRampEnd, config.DENSITY_LITERS_PER_CBM) })
        table.insert(lines, { text = string.format("WedgeH: %.2f | WedgePass: %d | WedgeMax: %.2f", config.WEDGE_HEIGHT_M, siloAssistHeightController.wedgePassCount, config.WEDGE_MAX_HEIGHT) })
        if siloAssistSiloDetector.isInSilo then
            table.insert(lines, { text = string.format("VehPos: %.1f, %.1f, %.1f", siloAssistSiloDetector.vehicleX, siloAssistSiloDetector.vehicleY, siloAssistSiloDetector.vehicleZ) })
            table.insert(lines, { text = string.format("TerrH: %.3f | DensH: %.3f | EstH: %.3f | StageH: %.3f", siloAssistSiloDetector.siloTerrainHeightAtVehicle, siloAssistSiloDetector.siloDensityHeightAtVehicle, siloAssistSiloDetector.estimatedFillHeight, siloAssistSiloDetector.stagedFillHeight) })
            table.insert(lines, { text = string.format("FillH@Veh: %.3f | FillH@Blade: %.3f", siloAssistSiloDetector.densityFillHeightAtVehicle, siloAssistSiloDetector.densityFillHeightAtBlade) })
        end
        if siloAssistHeightController.lastRaycastGroundDistance ~= nil then
            table.insert(lines, { text = string.format("RayH: %.3fm", siloAssistHeightController.lastRaycastGroundDistance) })
        end
        if siloAssistHeightController.lastPitchDeg ~= nil then
            table.insert(lines, { text = string.format("Pitch: %.1f deg", siloAssistHeightController.lastPitchDeg) })
        end
        if siloAssistToolDetection.controlType == "attacherJointControl" then
            local toolObj = siloAssistToolDetection.toolObject
            if toolObj and toolObj.spec_attacherJointControl then
                local alpha = toolObj.spec_attacherJointControl.heightController.moveAlpha
                local jointDesc = toolObj.spec_attacherJointControl.jointDesc
                table.insert(lines, { text = string.format("Alpha: %.4f [%.3f..%.3f]", alpha, jointDesc.upperAlpha, jointDesc.lowerAlpha) })
            end
        elseif siloAssistToolDetection.controlType == "cylindered" then
            local cylVeh = siloAssistToolDetection.cylinderedVehicle
            if cylVeh and cylVeh.spec_cylindered and siloAssistToolDetection.armToolIndex then
                local tool = cylVeh.spec_cylindered.movingTools[siloAssistToolDetection.armToolIndex]
                if tool then
                    local curRot = tool.curRot and tool.curRot[1] or 0
                    local rotMin = tool.rotMin and tool.rotMin[1] or 0
                    local rotMax = tool.rotMax and tool.rotMax[1] or 0
                    table.insert(lines, { text = string.format("ArmRot: %.3f [%.3f..%.3f]", curRot, rotMin, rotMax) })
                end
            end
        end
        table.insert(lines, { text = string.format("Speed: %.1f km/h | Stuck: %s | Slip: %s | Rev: %s", siloAssistSiloDetector.vehicleSpeed, tostring(siloAssistState.isStuck), tostring(siloAssistState.wheelSlipDetected), tostring(siloAssistState.isReversing)) })
        table.insert(lines, { text = string.format("hDiff: %.3f | aDir: %d | Pitch: %.1f | InSilo: %s", siloAssistHeightController.lastHeightDiff, siloAssistHeightController.lastAlphaDirection, siloAssistHeightController.vehiclePitchDeg, tostring(siloAssistSiloDetector.isInSilo)) })
        table.insert(lines, { text = string.format("ToolType: %s | Ctrl: %s | Blade: %s | Front: %s", tostring(siloAssistToolDetection.toolType), tostring(siloAssistToolDetection.controlType), tostring(siloAssistToolDetection.bladeNode ~= nil), tostring(siloAssistToolDetection.isFrontAttached)) })
        table.insert(lines, { text = string.format("ArmIx: %s | DumpIx: %s | CylVeh: %s", tostring(siloAssistToolDetection.armToolIndex), tostring(siloAssistToolDetection.dumpToolIndex), tostring(siloAssistToolDetection.cylinderedVehicle ~= nil)) })
        table.insert(lines, { text = string.format("Tilt: last=%.2f deg | vehPitch=%.1f | pitchFac=%d | front=%s", siloAssistTiltController.lastAppliedTiltDeg, siloAssistHeightController.vehiclePitchDeg, siloAssistToolDetection.isFrontAttached and 1 or -1, tostring(siloAssistToolDetection.isFrontAttached)) })
    end

    return lines
end

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------
function siloAssistHud.formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k = 0
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

function siloAssistHud:isInButton(posX, posY, btn)
    if btn == nil then
        return false
    end
    return posX >= btn.x and posX <= btn.x + btn.w
        and posY >= btn.y and posY <= btn.y + btn.h
end

---------------------------------------------------------------------
-- Mouse events
---------------------------------------------------------------------
function siloAssistHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not siloAssistVehicleState.isHudVisible() then
        return false
    end

    if g_gui ~= nil and g_gui.getIsGuiVisible ~= nil and g_gui:getIsGuiVisible() then
        return false
    end

    siloAssistHud.mouseX = posX
    siloAssistHud.mouseY = posY

    if siloAssistHud.isDragging then
        if button == 1 and isUp then
            siloAssistHud.isDragging = false
            return true
        end
        siloAssistHud.x = posX - siloAssistHud.dragOffsetX
        siloAssistHud.y = posY - siloAssistHud.dragOffsetY
        siloAssistHud:clampPosition()
        return true
    end

    if button == 1 and isDown then
        if siloAssistHud:isInButton(posX, posY, siloAssistHud.offsetMinusBtn) then
            siloAssistConfig.adjustOffset(-siloAssistConfig.OFFSET_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud.offsetPlusBtn) then
            siloAssistConfig.adjustOffset(siloAssistConfig.OFFSET_STEP)
            return true
        end

        if siloAssistHud.debugBtnX ~= nil and posX >= siloAssistHud.debugBtnX and posX <= siloAssistHud.debugBtnX + siloAssistHud.debugBtnW
            and posY >= siloAssistHud.debugBtnY and posY <= siloAssistHud.debugBtnY + siloAssistHud.debugBtnH then
            siloAssistDebug.toggle()
            return true
        end

        if siloAssistHud.modeLineY ~= nil
            and posX >= siloAssistHud.hudPosX and posX <= siloAssistHud.hudPosX + siloAssistHud.hudWidth
            and posY >= siloAssistHud.modeLineY and posY <= siloAssistHud.modeLineY + siloAssistHud.modeLineH then
            siloAssistConfig.cycleMode()
            local label = g_i18n:getText(siloAssistConfig.getModeLabel())
            siloAssistHud.showStatusText(label)
            return true
        end

        if siloAssistHud.hudPosX ~= nil then
            local closeSzW2, closeSzH2 = getNormalizedScreenValues(siloAssistHud.CLOSE_SIZE_PX, siloAssistHud.CLOSE_SIZE_PX)
            local m2 = getNormalizedScreenValues(siloAssistHud.MARGIN_PX, 1)
            local closeBtnX2 = siloAssistHud.hudPosX + siloAssistHud.hudWidth - m2 - closeSzW2 - m2
            local _, hH2 = getNormalizedScreenValues(1, siloAssistHud.HEADER_HEIGHT_PX)
            local closeBtnY2 = siloAssistHud.hudPosY + siloAssistHud.hudHeight - hH2 + (hH2 - closeSzH2) * 0.5

            if posX >= closeBtnX2 and posX <= closeBtnX2 + closeSzW2
                and posY >= closeBtnY2 and posY <= closeBtnY2 + closeSzH2 then
                siloAssistVehicleState.setHudVisible(false)
                return true
            end
        end

        local _, hH3 = getNormalizedScreenValues(1, siloAssistHud.HEADER_HEIGHT_PX)
        local headerY = siloAssistHud.hudPosY + siloAssistHud.hudHeight - hH3
        if posX >= siloAssistHud.hudPosX and posX <= siloAssistHud.hudPosX + siloAssistHud.hudWidth
            and posY >= headerY and posY <= siloAssistHud.hudPosY + siloAssistHud.hudHeight then
            siloAssistHud.isDragging = true
            siloAssistHud.dragOffsetX = posX - siloAssistHud.x
            siloAssistHud.dragOffsetY = posY - siloAssistHud.y
            return true
        end
    end

    if siloAssistHud:isMouseOverHud(posX, posY) then
        return true
    end

    return false
end

function siloAssistHud:isMouseOverHud(posX, posY)
    if siloAssistHud.hudPosX == nil then
        return false
    end
    return posX >= siloAssistHud.hudPosX and posX <= siloAssistHud.hudPosX + siloAssistHud.hudWidth
        and posY >= siloAssistHud.hudPosY and posY <= siloAssistHud.hudPosY + siloAssistHud.hudHeight
end

function siloAssistHud:clampPosition()
    if siloAssistHud.x == nil or siloAssistHud.y == nil then
        return
    end
    local w = siloAssistHud.hudWidth or 0
    local h = siloAssistHud.hudHeight or 0
    if w > 0 and h > 0 then
        siloAssistHud.x = math.clamp(siloAssistHud.x, 0, 1 - w)
        siloAssistHud.y = math.clamp(siloAssistHud.y, 0, 1 - h)
    end
end

---------------------------------------------------------------------
-- Status text timer
---------------------------------------------------------------------
function siloAssistHud:updateStatusText(dt)
    if siloAssistHud.statusTextTimer > 0 then
        siloAssistHud.statusTextTimer = siloAssistHud.statusTextTimer - dt
        if siloAssistHud.statusTextTimer <= 0 then
            siloAssistHud.statusTextTimer = 0
            siloAssistHud.statusText = ""
        end
    end
end

---------------------------------------------------------------------
-- Save / load HUD position
---------------------------------------------------------------------
siloAssistHud.savedHudX = nil
siloAssistHud.savedHudY = nil

function siloAssistHud.saveToXML(xmlFile, baseKey)
    if siloAssistHud.x ~= nil then
        xmlFile:setFloat(baseKey .. "#hudX", siloAssistHud.x)
    end
    if siloAssistHud.y ~= nil then
        xmlFile:setFloat(baseKey .. "#hudY", siloAssistHud.y)
    end
end

function siloAssistHud.loadFromXML(xmlFile, baseKey)
    local hudX = xmlFile:getFloat(baseKey .. "#hudX")
    local hudY = xmlFile:getFloat(baseKey .. "#hudY")
    if hudX ~= nil then
        siloAssistHud.savedHudX = hudX
    end
    if hudY ~= nil then
        siloAssistHud.savedHudY = hudY
    end
end