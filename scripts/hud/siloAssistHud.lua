--====================================================================
-- SiloAssist - HUD (AdvancedHelper-style layout)
--====================================================================

siloAssistHud = {}

siloAssistHud.POS_X = 810
siloAssistHud.POS_Y = 60
siloAssistHud.WIDTH = 320

siloAssistHud.HEADER_H = 20
siloAssistHud.FOOTER_H = 18
siloAssistHud.LINE_H = 20
siloAssistHud.MARGIN = 6

siloAssistHud.FONT_TITLE = 0.014
siloAssistHud.FONT_DEFAULT = 0.011
siloAssistHud.FONT_SMALL = 0.009
siloAssistHud.FONT_FOOTER = 0.009

siloAssistHud.BG_COLOR = {0.0, 0.0, 0.0, 0.75}
siloAssistHud.HEADER_COLOR = {0.18, 0.35, 0.003, 1.0}
siloAssistHud.FOOTER_COLOR = {0.05, 0.05, 0.05, 0.5}
siloAssistHud.COLOR_ACTIVE = {0.1, 0.7, 0.1, 0.95}
siloAssistHud.COLOR_OFF = {0.85, 0.15, 0.15, 0.95}
siloAssistHud.COLOR_BTN = {1, 1, 1, 0.85}
siloAssistHud.COLOR_BTN_HOVER = {0.4, 0.7, 1.0, 0.95}
siloAssistHud.COLOR_WARN = {0.95, 0.75, 0.0, 0.9}
siloAssistHud.COLOR_CLOSE = {1.0, 1.0, 1.0, 0.9}
siloAssistHud.ROW_EVEN = {0.05, 0.05, 0.05, 0.5}
siloAssistHud.ROW_ODD = {0.0, 0.0, 0.0, 0.35}
siloAssistHud.COLOR_LABEL = {0.7, 0.7, 0.7, 0.9}
siloAssistHud.COLOR_VALUE = {1, 1, 1, 0.95}
siloAssistHud.COLOR_SWITCH_ON = {0.3, 0.6, 1.0, 0.95}
siloAssistHud.COLOR_SWITCH_ON_HOVER = {0.5, 0.75, 1.0, 1.0}

siloAssistHud.PAGES = {"setup", "debug", "profile"}
siloAssistHud.PAGE_INDEX = 1

siloAssistHud.FALLBACK_UVS = {0, 0, 1, 0, 1, 1, 0, 1}
siloAssistHud.isInitialized = false

siloAssistHud.OVERLAY_PREFIX = "siloAssistIcons"

siloAssistHud.CLOSE_PX = 12
siloAssistHud.CHECK_PX = 12
siloAssistHud.NAV_BTN_PX = 12
siloAssistHud.OFFSET_BTN_PX = 12
siloAssistHud.TILT_BTN_PX = 12
siloAssistHud.FOLLOW_BTN_PX = 12
siloAssistHud.SWITCH_W_PX = 24
siloAssistHud.SWITCH_H_PX = 12

-- Overlays
siloAssistHud.bgOverlay = nil
siloAssistHud.headerOverlay = nil
siloAssistHud.footerOverlay = nil
siloAssistHud.closeOv = nil
siloAssistHud.prevOv = nil
siloAssistHud.nextOv = nil
siloAssistHud.plusOv = nil
siloAssistHud.minusOv = nil
siloAssistHud.tiltPlusOv = nil
siloAssistHud.tiltMinusOv = nil
siloAssistHud.followPlusOv = nil
siloAssistHud.followMinusOv = nil
siloAssistHud.checkOvUnchecked = nil
siloAssistHud.checkOvChecked = nil
siloAssistHud.switchOffOv = nil
siloAssistHud.switchOnOv = nil
siloAssistHud.dividerOv = nil
siloAssistHud.rowOverlays = {}

siloAssistHud.maxRowOverlays = 22
siloAssistHud.lineCount = 0

siloAssistHud.mouseX = 0
siloAssistHud.mouseY = 0
siloAssistHud.isDragging = false
siloAssistHud.dragOffsetX = 0
siloAssistHud.dragOffsetY = 0

siloAssistHud.hudPosX = nil
siloAssistHud.hudPosY = nil
siloAssistHud.hudWidth = nil
siloAssistHud.hudHeight = nil

siloAssistHud.savedHudX = nil
siloAssistHud.savedHudY = nil

-- Interactive element bounds (set each frame, used by mouseEvent)
siloAssistHud._closeBtn = nil
-- Debug checkboxes
siloAssistHud._prevBtn = nil
siloAssistHud._nextBtn = nil
siloAssistHud._modeDtBtn = nil
siloAssistHud._modeWedgeBtn = nil
siloAssistHud._minusBtn = nil
siloAssistHud._plusBtn = nil
siloAssistHud._tiltMinusBtn = nil
siloAssistHud._tiltPlusBtn = nil
siloAssistHud._followMinusBtn = nil
siloAssistHud._followPlusBtn = nil
siloAssistHud._lookaheadMinusBtn = nil
siloAssistHud._lookaheadPlusBtn = nil
siloAssistHud._topoGainMinusBtn = nil
siloAssistHud._topoGainPlusBtn = nil
siloAssistHud._toggleBtn = nil

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function siloAssistHud:init()
    if siloAssistHud.isInitialized then return end

    local P = siloAssistHud.OVERLAY_PREFIX
    local tex = g_baseUIFilename
    if tex == nil then tex = "dataS/menu/base/graph_pixel.png" end
    local uvs = g_colorBgUVs or siloAssistHud.FALLBACK_UVS

    if siloAssistHud.savedHudX ~= nil then
        siloAssistHud.x = siloAssistHud.savedHudX
        siloAssistHud.y = siloAssistHud.savedHudY
    else
        siloAssistHud.x, siloAssistHud.y = getNormalizedScreenValues(
            siloAssistHud.POS_X, siloAssistHud.POS_Y)
    end

    local function makeOv(id)
        return g_overlayManager:createOverlay(id, 0, 0, 1, 1)
    end

    siloAssistHud.bgOverlay = makeOv(P .. ".panel")
    siloAssistHud.bgOverlay:setColor(unpack(siloAssistHud.BG_COLOR))

    siloAssistHud.headerOverlay = makeOv(P .. ".titleBar")
    siloAssistHud.headerOverlay:setColor(unpack(siloAssistHud.HEADER_COLOR))

    siloAssistHud.footerOverlay = makeOv(P .. ".bottomBar")
    siloAssistHud.footerOverlay:setColor(unpack(siloAssistHud.FOOTER_COLOR))

    siloAssistHud.closeOv = makeOv(P .. ".close")
    siloAssistHud.prevOv = makeOv(P .. ".prev")
    siloAssistHud.nextOv = makeOv(P .. ".next")
    siloAssistHud.plusOv = makeOv(P .. ".iconPlus")
    siloAssistHud.minusOv = makeOv(P .. ".iconMinus")
    siloAssistHud.tiltPlusOv = makeOv(P .. ".iconPlus")
    siloAssistHud.tiltMinusOv = makeOv(P .. ".iconMinus")
    siloAssistHud.followPlusOv = makeOv(P .. ".iconPlus")
    siloAssistHud.followMinusOv = makeOv(P .. ".iconMinus")
    siloAssistHud.lookaheadPlusOv = makeOv(P .. ".iconPlus")
    siloAssistHud.lookaheadMinusOv = makeOv(P .. ".iconMinus")
    siloAssistHud.topoGainPlusOv = makeOv(P .. ".iconPlus")
    siloAssistHud.topoGainMinusOv = makeOv(P .. ".iconMinus")
    siloAssistHud.checkOvUnchecked = makeOv(P .. ".checkboxUnchecked")
    siloAssistHud.checkOvChecked = makeOv(P .. ".checkboxChecked")
    siloAssistHud.switchOffOv = makeOv(P .. ".switchOff")
    siloAssistHud.switchOnOv = makeOv(P .. ".switchOn")
    siloAssistHud.dividerOv = makeOv(P .. ".dividerHorizontal")

    for i = 1, siloAssistHud.maxRowOverlays do
        local ov = Overlay.new(tex, 0, 0, 0, 0)
        ov:setUVs(uvs)
        ov:setColor(unpack(siloAssistHud.ROW_ODD))
        siloAssistHud.rowOverlays[i] = ov
    end

    siloAssistHud.profileBars = {}
    siloAssistHud.profileTargetLine = Overlay.new(tex, 0, 0, 0, 0)
    siloAssistHud.profileTargetLine:setUVs(uvs)
    siloAssistHud.profileBladeLine = Overlay.new(tex, 0, 0, 0, 0)
    siloAssistHud.profileBladeLine:setUVs(uvs)
    siloAssistHud.profileLrBar = Overlay.new(tex, 0, 0, 0, 0)
    siloAssistHud.profileLrBar:setUVs(uvs)
    for i = 1, 15 do
        local ov = Overlay.new(tex, 0, 0, 0, 0)
        ov:setUVs(uvs)
        siloAssistHud.profileBars[i] = ov
    end

    siloAssistHud.isInitialized = true
end

---------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------
function siloAssistHud:toggle()
    siloAssistVehicleState.setHudVisible(not siloAssistVehicleState.isHudVisible())
end

function siloAssistHud.showStatusText(text)
end

---------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------
if g_overlayManager ~= nil and g_overlayManager.addTextureConfigFile ~= nil then
    g_overlayManager:addTextureConfigFile(
        Utils.getFilename("textures/iconSprite.xml", g_currentModDirectory),
        "siloAssistIcons")
end
siloAssistHud:init()

function siloAssistHud:centerY(containerH, fontSize)
    return (containerH - fontSize * 0.8) * 0.5
end

function siloAssistHud:draw()
    if not siloAssistVehicleState.isHudVisible() then return end
    if g_currentMission == nil then return end
    if not siloAssistHud.isInitialized then return end
    if siloAssistHud.mouseX == nil then siloAssistHud.mouseX = 0 end
    if siloAssistHud.mouseY == nil then siloAssistHud.mouseY = 0 end

    siloAssistHud._closeBtn = nil
    siloAssistHud._checkBtn = nil
    siloAssistHud._prevBtn = nil
    siloAssistHud._nextBtn = nil
    siloAssistHud._modeDtBtn = nil
    siloAssistHud._modeWedgeBtn = nil
    siloAssistHud._minusBtn = nil
    siloAssistHud._plusBtn = nil
    siloAssistHud._tiltMinusBtn = nil
    siloAssistHud._tiltPlusBtn = nil
    siloAssistHud._followMinusBtn = nil
    siloAssistHud._followPlusBtn = nil
    siloAssistHud._topoGainMinusBtn = nil
    siloAssistHud._topoGainPlusBtn = nil
siloAssistHud._toggleBtn = nil
siloAssistHud._debugLinesBtn = nil
siloAssistHud._debugDebugBtn = nil
siloAssistHud._debugLogBtn = nil

    local w, _ = getNormalizedScreenValues(siloAssistHud.WIDTH, 1)
    local m, _ = getNormalizedScreenValues(siloAssistHud.MARGIN, 1)
    local _, hH = getNormalizedScreenValues(1, siloAssistHud.HEADER_H)
    local _, fH = getNormalizedScreenValues(1, siloAssistHud.FOOTER_H)
    local _, lH = getNormalizedScreenValues(1, siloAssistHud.LINE_H)

    local closeW, closeH = getNormalizedScreenValues(siloAssistHud.CLOSE_PX, siloAssistHud.CLOSE_PX)
    local checkW, checkH = getNormalizedScreenValues(siloAssistHud.CHECK_PX, siloAssistHud.CHECK_PX)
    local navBtnW, navBtnH = getNormalizedScreenValues(siloAssistHud.NAV_BTN_PX, siloAssistHud.NAV_BTN_PX)
    local offBtnW, offBtnH = getNormalizedScreenValues(siloAssistHud.OFFSET_BTN_PX, siloAssistHud.OFFSET_BTN_PX)
    local tiltBtnW, tiltBtnH = getNormalizedScreenValues(siloAssistHud.TILT_BTN_PX, siloAssistHud.TILT_BTN_PX)
    local followBtnW, followBtnH = getNormalizedScreenValues(siloAssistHud.FOLLOW_BTN_PX, siloAssistHud.FOLLOW_BTN_PX)
    local switchW, switchH = getNormalizedScreenValues(siloAssistHud.SWITCH_W_PX, siloAssistHud.SWITCH_H_PX)

    local uiScale = g_gameSettings:getValue("uiScale") or 1.0
    local fTitle = getCorrectTextSize(siloAssistHud.FONT_TITLE * uiScale)
    local fDefault = getCorrectTextSize(siloAssistHud.FONT_DEFAULT * uiScale)
    local fSmall = getCorrectTextSize(siloAssistHud.FONT_SMALL * uiScale)
    local fFooter = getCorrectTextSize(siloAssistHud.FONT_FOOTER * uiScale)

    local lines = siloAssistHud.buildContent()
    local contentH = #lines * lH
    local totalH = hH + contentH + fH

    local x = siloAssistHud.x
    local y = siloAssistHud.y

    siloAssistHud.hudPosX = x
    siloAssistHud.hudPosY = y
    siloAssistHud.hudWidth = w
    siloAssistHud.hudHeight = totalH

    ---------------------------------------------------------------
    -- Background
    ---------------------------------------------------------------
    siloAssistHud.bgOverlay:setPosition(x, y)
    siloAssistHud.bgOverlay:setDimension(w, totalH)
    siloAssistHud.bgOverlay:render()

    ---------------------------------------------------------------
    -- Header (titleBar sprite, green)
    ---------------------------------------------------------------
    local headerY = y + totalH - hH
    siloAssistHud.headerOverlay:setPosition(x, headerY)
    siloAssistHud.headerOverlay:setDimension(w, hH)
    siloAssistHud.headerOverlay:render()

    -- Title text (vertically centered in header)
    local titleY = headerY + siloAssistHud:centerY(hH, fTitle)
    setTextColor(1, 1, 1, 0.95)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(x + m, titleY, fTitle, g_i18n:getText("sa_title"))

    -- Close button (right side of header)
    local closeBtnX = x + w - m - closeW
    local closeBtnY = headerY + siloAssistHud:centerY(hH, closeH)
    siloAssistHud._closeBtn = {x = closeBtnX, y = closeBtnY, w = closeW, h = closeH}
    local isHoverClose = siloAssistHud.mouseX >= closeBtnX
        and siloAssistHud.mouseX <= closeBtnX + closeW
        and siloAssistHud.mouseY >= closeBtnY
        and siloAssistHud.mouseY <= closeBtnY + closeH
    siloAssistHud.closeOv:setPosition(closeBtnX, closeBtnY)
    siloAssistHud.closeOv:setDimension(closeW, closeH)
    siloAssistHud.closeOv:setColor(unpack(isHoverClose and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_CLOSE))
    siloAssistHud.closeOv:render()

    -- Toggle switch (left of close button)
    local state = siloAssistVehicleState.getState()
    local isActive = state ~= siloAssistConfig.STATE_OFF
    local toggleOv = isActive and siloAssistHud.switchOnOv or siloAssistHud.switchOffOv
    local toggleX = closeBtnX - m - switchW
    local toggleY = headerY + siloAssistHud:centerY(hH, switchH)
    siloAssistHud._toggleBtn = {x = toggleX, y = toggleY, w = switchW, h = switchH}
    local isHoverToggle = siloAssistHud.mouseX >= toggleX
        and siloAssistHud.mouseX <= toggleX + switchW
        and siloAssistHud.mouseY >= toggleY
        and siloAssistHud.mouseY <= toggleY + switchH
    toggleOv:setPosition(toggleX, toggleY)
    toggleOv:setDimension(switchW, switchH)
    if isActive then
        if isHoverToggle then
            toggleOv:setColor(unpack(siloAssistHud.COLOR_SWITCH_ON_HOVER))
        else
            toggleOv:setColor(unpack(siloAssistHud.COLOR_SWITCH_ON))
        end
    else
        if isHoverToggle then
            toggleOv:setColor(unpack(siloAssistHud.COLOR_BTN_HOVER))
        else
            toggleOv:setColor(1, 1, 1, 0.95)
        end
    end
    toggleOv:render()

    ---------------------------------------------------------------
    -- Content rows
    ---------------------------------------------------------------
    siloAssistHud.lineCount = #lines
    local contentTop = y + totalH - hH

    for i, line in ipairs(lines) do
        local rowY = contentTop - lH * i
        local textY = rowY + siloAssistHud:centerY(lH, fDefault)

        if i <= siloAssistHud.maxRowOverlays then
            local rowOv = siloAssistHud.rowOverlays[i]
            rowOv:setPosition(x, rowY)
            rowOv:setDimension(w, lH)
            local rc = (i % 2 == 0) and siloAssistHud.ROW_EVEN or siloAssistHud.ROW_ODD
            rowOv:setColor(unpack(rc))
            rowOv:render()
        end

        if line.type == "checkboxes" then
            local currentMode = siloAssistVehicleState.getSiloMode()
            local isDriveThrough = currentMode == "driveThrough"
            local cbY = rowY + siloAssistHud:centerY(lH, checkH)
            local textOfsY = rowY + siloAssistHud:centerY(lH, fDefault)

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textOfsY, fDefault, g_i18n:getText("sa_mode") .. ":")

            local wedgeText = g_i18n:getText("SA_MODE_WEDGE")
            local dtText = g_i18n:getText("SA_MODE_DRIVETHROUGH")
            local dtCbX = x + w - m - checkW - m - getTextWidth(fDefault, wedgeText) - m - checkW - m - getTextWidth(fDefault, dtText)
            local dtLabelX = dtCbX + checkW + m
            local wedgeCbX = x + w - m - checkW - m - getTextWidth(fDefault, wedgeText)
            local wedgeLabelX = wedgeCbX + checkW + m

            local dtOv = isDriveThrough and siloAssistHud.checkOvChecked or siloAssistHud.checkOvUnchecked
            dtOv:setPosition(dtCbX, cbY)
            dtOv:setDimension(checkW, checkH)
            dtOv:setColor(1, 1, 1, 0.95)
            dtOv:render()
            siloAssistHud._modeDtBtn = {x = dtCbX, y = rowY, w = checkW + m + getTextWidth(fDefault, dtText), h = lH}

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(dtLabelX, textOfsY, fDefault, dtText)

            local wOv = (not isDriveThrough) and siloAssistHud.checkOvChecked or siloAssistHud.checkOvUnchecked
            wOv:setPosition(wedgeCbX, cbY)
            wOv:setDimension(checkW, checkH)
            wOv:setColor(1, 1, 1, 0.95)
            wOv:render()
            siloAssistHud._modeWedgeBtn = {x = wedgeCbX, y = rowY, w = checkW + m + getTextWidth(fDefault, wedgeText), h = lH}

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(wedgeLabelX, textOfsY, fDefault, wedgeText)

        elseif line.type == "debugCheckboxes" then
            local cbY = rowY + siloAssistHud:centerY(lH, checkH)
            local textOfsY = rowY + siloAssistHud:centerY(lH, fDefault)

            setTextColor(0.7, 0.7, 0.7, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textOfsY, fDefault, "Debug:")

            local chkNames = {"Lines", "Values", "Log"}
            local chkStates = {
                siloAssistDebug.showLines,
                siloAssistDebug.showDebug,
                siloAssistDebug.showLog
            }
            local margin = getTextWidth(fDefault, "  ")
            local curX = x + w - m
            for idx = 3, 1, -1 do
                local labelW = getTextWidth(fDefault, chkNames[idx])
                local cbPosX = curX - checkW - m - labelW
                local ov = chkStates[idx] and siloAssistHud.checkOvChecked or siloAssistHud.checkOvUnchecked
                ov:setPosition(cbPosX, cbY)
                ov:setDimension(checkW, checkH)
                ov:setColor(1, 1, 1, 0.95)
                ov:render()

                setTextColor(1, 1, 1, 0.9)
                setTextAlignment(RenderText.ALIGN_LEFT)
                renderText(cbPosX + checkW + m, textOfsY, fDefault, chkNames[idx])

                local btn = {x = cbPosX, y = rowY, w = checkW + m + labelW, h = lH}
                if idx == 1 then siloAssistHud._debugLinesBtn = btn
                elseif idx == 2 then siloAssistHud._debugDebugBtn = btn
                elseif idx == 3 then siloAssistHud._debugLogBtn = btn end

                curX = cbPosX - margin
            end

        elseif line.type == "offset" then
            local labelStr = line.text
            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, labelStr)

            local offsetSign = siloAssistVehicleState.getHeightOffset() >= 0 and "+" or ""
            local offsetStr = string.format("%s%.2fm", offsetSign, siloAssistVehicleState.getHeightOffset())
            local offsetTextW = getTextWidth(fDefault, offsetStr)

            local plusX = x + w - m - offBtnW
            local valX = plusX - m - offsetTextW
            local minusX = valX - m - offBtnW

            siloAssistHud._minusBtn = {x = minusX, y = rowY, w = offBtnW, h = lH}
            siloAssistHud._plusBtn = {x = plusX, y = rowY, w = offBtnW, h = lH}

            local hovMinus = siloAssistHud.mouseX >= minusX
                and siloAssistHud.mouseX <= minusX + offBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH
            local hovPlus = siloAssistHud.mouseX >= plusX
                and siloAssistHud.mouseX <= plusX + offBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH

            local colMinus = hovMinus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN
            local colPlus = hovPlus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN

            local btnY = rowY + siloAssistHud:centerY(lH, offBtnH)
            siloAssistHud.minusOv:setPosition(minusX, btnY)
            siloAssistHud.minusOv:setDimension(offBtnW, offBtnH)
            siloAssistHud.minusOv:setColor(unpack(colMinus))
            siloAssistHud.minusOv:render()

            siloAssistHud.plusOv:setPosition(plusX, btnY)
            siloAssistHud.plusOv:setDimension(offBtnW, offBtnH)
            siloAssistHud.plusOv:setColor(unpack(colPlus))
            siloAssistHud.plusOv:render()

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(valX, textY, fDefault, offsetStr)

        elseif line.type == "tilt" then
            local labelStr = line.text
            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, labelStr)

            local tiltSign = siloAssistVehicleState.getTiltOffset() >= 0 and "+" or ""
            local tiltStr = string.format("%s%d°", tiltSign, math.floor(siloAssistVehicleState.getTiltOffset() + 0.5))
            local tiltTextW = getTextWidth(fDefault, tiltStr)

            local plusX = x + w - m - tiltBtnW
            local valX = plusX - m - tiltTextW
            local minusX = valX - m - tiltBtnW

            siloAssistHud._tiltMinusBtn = {x = minusX, y = rowY, w = tiltBtnW, h = lH}
            siloAssistHud._tiltPlusBtn = {x = plusX, y = rowY, w = tiltBtnW, h = lH}

            local hovMinus = siloAssistHud.mouseX >= minusX
                and siloAssistHud.mouseX <= minusX + tiltBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH
            local hovPlus = siloAssistHud.mouseX >= plusX
                and siloAssistHud.mouseX <= plusX + tiltBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH

            local colMinus = hovMinus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN
            local colPlus = hovPlus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN

            local btnY = rowY + siloAssistHud:centerY(lH, tiltBtnH)
            siloAssistHud.tiltMinusOv:setPosition(minusX, btnY)
            siloAssistHud.tiltMinusOv:setDimension(tiltBtnW, tiltBtnH)
            siloAssistHud.tiltMinusOv:setColor(unpack(colMinus))
            siloAssistHud.tiltMinusOv:render()

            siloAssistHud.tiltPlusOv:setPosition(plusX, btnY)
            siloAssistHud.tiltPlusOv:setDimension(tiltBtnW, tiltBtnH)
            siloAssistHud.tiltPlusOv:setColor(unpack(colPlus))
            siloAssistHud.tiltPlusOv:render()

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(valX, textY, fDefault, tiltStr)

        elseif line.type == "follow" then
            local labelStr = line.text
            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, labelStr)

            local followVal = siloAssistVehicleState.getFollowFactor()
            local followStr = string.format("%.1f", followVal)
            local followTextW = getTextWidth(fDefault, followStr)

            local plusX = x + w - m - followBtnW
            local valX = plusX - m - followTextW
            local minusX = valX - m - followBtnW

            siloAssistHud._followMinusBtn = {x = minusX, y = rowY, w = followBtnW, h = lH}
            siloAssistHud._followPlusBtn = {x = plusX, y = rowY, w = followBtnW, h = lH}

            local hovMinus = siloAssistHud.mouseX >= minusX
                and siloAssistHud.mouseX <= minusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH
            local hovPlus = siloAssistHud.mouseX >= plusX
                and siloAssistHud.mouseX <= plusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH

            local colMinus = hovMinus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN
            local colPlus = hovPlus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN

            local btnY = rowY + siloAssistHud:centerY(lH, followBtnH)
            siloAssistHud.followMinusOv:setPosition(minusX, btnY)
            siloAssistHud.followMinusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.followMinusOv:setColor(unpack(colMinus))
            siloAssistHud.followMinusOv:render()

            siloAssistHud.followPlusOv:setPosition(plusX, btnY)
            siloAssistHud.followPlusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.followPlusOv:setColor(unpack(colPlus))
            siloAssistHud.followPlusOv:render()

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(valX, textY, fDefault, followStr)

        elseif line.type == "lookahead" then
            local labelStr = line.text
            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, labelStr)

            local lookVal = siloAssistVehicleState.getLookaheadTime()
            local lookStr = string.format("%.1fs", lookVal)
            local lookTextW = getTextWidth(fDefault, lookStr)

            local plusX = x + w - m - followBtnW
            local valX = plusX - m - lookTextW
            local minusX = valX - m - followBtnW

            siloAssistHud._lookaheadMinusBtn = {x = minusX, y = rowY, w = followBtnW, h = lH}
            siloAssistHud._lookaheadPlusBtn = {x = plusX, y = rowY, w = followBtnW, h = lH}

            local hovMinus = siloAssistHud.mouseX >= minusX
                and siloAssistHud.mouseX <= minusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH
            local hovPlus = siloAssistHud.mouseX >= plusX
                and siloAssistHud.mouseX <= plusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH

            local colMinus = hovMinus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN
            local colPlus = hovPlus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN

            local btnY = rowY + siloAssistHud:centerY(lH, followBtnH)
            siloAssistHud.lookaheadMinusOv:setPosition(minusX, btnY)
            siloAssistHud.lookaheadMinusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.lookaheadMinusOv:setColor(unpack(colMinus))
            siloAssistHud.lookaheadMinusOv:render()

            siloAssistHud.lookaheadPlusOv:setPosition(plusX, btnY)
            siloAssistHud.lookaheadPlusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.lookaheadPlusOv:setColor(unpack(colPlus))
            siloAssistHud.lookaheadPlusOv:render()

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(valX, textY, fDefault, lookStr)

        elseif line.type == "topoGain" then
            local labelStr = line.text
            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, labelStr)

            local gainVal = siloAssistVehicleState.getTopoGain()
            local gainStr = string.format("%.1f", gainVal)
            local gainTextW = getTextWidth(fDefault, gainStr)

            local plusX = x + w - m - followBtnW
            local valX = plusX - m - gainTextW
            local minusX = valX - m - followBtnW

            siloAssistHud._topoGainMinusBtn = {x = minusX, y = rowY, w = followBtnW, h = lH}
            siloAssistHud._topoGainPlusBtn = {x = plusX, y = rowY, w = followBtnW, h = lH}

            local hovMinus = siloAssistHud.mouseX >= minusX
                and siloAssistHud.mouseX <= minusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH
            local hovPlus = siloAssistHud.mouseX >= plusX
                and siloAssistHud.mouseX <= plusX + followBtnW
                and siloAssistHud.mouseY >= rowY
                and siloAssistHud.mouseY <= rowY + lH

            local colMinus = hovMinus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN
            local colPlus = hovPlus and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN

            local btnY = rowY + siloAssistHud:centerY(lH, followBtnH)
            siloAssistHud.topoGainMinusOv:setPosition(minusX, btnY)
            siloAssistHud.topoGainMinusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.topoGainMinusOv:setColor(unpack(colMinus))
            siloAssistHud.topoGainMinusOv:render()

            siloAssistHud.topoGainPlusOv:setPosition(plusX, btnY)
            siloAssistHud.topoGainPlusOv:setDimension(followBtnW, followBtnH)
            siloAssistHud.topoGainPlusOv:setColor(unpack(colPlus))
            siloAssistHud.topoGainPlusOv:render()

            setTextColor(1, 1, 1, 0.9)
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(valX, textY, fDefault, gainStr)

        elseif line.type == "miniProfile" then
            local hc = siloAssistHeightController
            -- Build 5-point profile from CL+CR means (same as analyzeSurfaceProfile)
            local ch = hc.collisionSampleHeights
            local s = {}
            if ch ~= nil and #ch >= 5 then
                for i = 1, 5 do
                    if ch[i] ~= nil and ch[i].leftFill ~= nil and ch[i].rightFill ~= nil then
                        s[i] = (ch[i].leftFill + ch[i].rightFill) * 0.5
                    end
                end
            end
            if s[1] ~= nil then
                local function cm(v)
                    if v == nil or v <= 0 then return " 0" end
                    return string.format("%2.0f", v * 100)
                end
                local profileStr = string.format("%s %s %s %s %scm",
                    cm(s[1]), cm(s[2]), cm(s[3]), cm(s[4]), cm(s[5]))
                setTextColor(0.3, 0.8, 0.3, 0.9)
                setTextAlignment(RenderText.ALIGN_LEFT)
                renderText(x + m, textY, fSmall, "P: " .. profileStr)
            end

        elseif line.type == "valuePair" then
            if line.color then
                setTextColor(unpack(line.color))
            else
                setTextColor(unpack(siloAssistHud.COLOR_LABEL))
            end
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, line.label)

            if line.valueColor then
                setTextColor(unpack(line.valueColor))
            else
                setTextColor(unpack(siloAssistHud.COLOR_VALUE))
            end
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(x + w - m, textY, fDefault, line.value)

        elseif line.type == "value" then
            if line.color then
                setTextColor(unpack(line.color))
            else
                setTextColor(1, 1, 1, 0.9)
            end
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + m, textY, fDefault, line.text)

        elseif line.type == "divider" then
            siloAssistHud.dividerOv:setPosition(x + m, rowY + lH * 0.5)
            siloAssistHud.dividerOv:setDimension(w - 2 * m, 0.002)
            siloAssistHud.dividerOv:setColor(1, 1, 1, 0.2)
            siloAssistHud.dividerOv:render()
        end
    end

    ---------------------------------------------------------------
    -- Footer
    ---------------------------------------------------------------
    siloAssistHud.footerOverlay:setPosition(x, y)
    siloAssistHud.footerOverlay:setDimension(w, fH)
    siloAssistHud.footerOverlay:render()

    -- Profile chart overlay (fills content area when on profile page)
    if siloAssistHud.PAGES[siloAssistHud.PAGE_INDEX] == "profile" then
        siloAssistHud:renderProfileChart(x, y, w, m, hH, fH, lH, contentH, fFooter, fSmall)
    end

    local prevX = x + m
    local prevY = y + siloAssistHud:centerY(fH, navBtnH)
    siloAssistHud._prevBtn = {x = prevX, y = prevY, w = navBtnW, h = navBtnH}
    local isHoverPrev = siloAssistHud.mouseX >= prevX and siloAssistHud.mouseX <= prevX + navBtnW
        and siloAssistHud.mouseY >= prevY and siloAssistHud.mouseY <= prevY + navBtnH
    siloAssistHud.prevOv:setPosition(prevX, prevY)
    siloAssistHud.prevOv:setDimension(navBtnW, navBtnH)
    siloAssistHud.prevOv:setColor(unpack(isHoverPrev and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN))
    siloAssistHud.prevOv:render()

    local nextX = x + w - m - navBtnW
    local nextY = y + siloAssistHud:centerY(fH, navBtnH)
    siloAssistHud._nextBtn = {x = nextX, y = nextY, w = navBtnW, h = navBtnH}
    local isHoverNext = siloAssistHud.mouseX >= nextX and siloAssistHud.mouseX <= nextX + navBtnW
        and siloAssistHud.mouseY >= nextY and siloAssistHud.mouseY <= nextY + navBtnH
    siloAssistHud.nextOv:setPosition(nextX, nextY)
    siloAssistHud.nextOv:setDimension(navBtnW, navBtnH)
    siloAssistHud.nextOv:setColor(unpack(isHoverNext and siloAssistHud.COLOR_BTN_HOVER or siloAssistHud.COLOR_BTN))
    siloAssistHud.nextOv:render()

    local pageTitle = siloAssistHud.PAGES[siloAssistHud.PAGE_INDEX]
    local titleLabel
    if pageTitle == "setup" then
        titleLabel = g_i18n:getText("sa_mode")
    elseif pageTitle == "debug" then
        titleLabel = g_i18n:getText("sa_debugTab")
    else
        titleLabel = g_i18n:getText("sa_profileTab")
    end
    setTextColor(0.65, 0.65, 0.65, 0.9)
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(x + w * 0.5, y + siloAssistHud:centerY(fH, fFooter), fFooter, titleLabel)

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

---------------------------------------------------------------------
-- Build content lines per page
---------------------------------------------------------------------
function siloAssistHud.buildContent()
    local lines = {}
    local page = siloAssistHud.PAGES[siloAssistHud.PAGE_INDEX]

    if page == "setup" then
        siloAssistHud.buildSetupPage(lines)
    elseif page == "debug" then
        siloAssistHud.buildDebugPage(lines)
    elseif page == "profile" then
        siloAssistHud.buildProfilePage(lines)
    end

    return lines
end

function siloAssistHud.buildSetupPage(lines)
    local config = siloAssistConfig
    local inSilo = siloAssistSiloDetector.isInSilo and siloAssistSiloDetector.currentSilo ~= nil

    table.insert(lines, { type = "checkboxes" })
    table.insert(lines, { type = "debugCheckboxes" })
    table.insert(lines, { type = "offset", text = g_i18n:getText("sa_height") .. ":" })
    table.insert(lines, { type = "tilt", text = g_i18n:getText("sa_tilt") .. ":" })
    table.insert(lines, { type = "follow", text = g_i18n:getText("sa_follow") .. ":" })
    table.insert(lines, { type = "lookahead", text = g_i18n:getText("sa_lookahead") .. ":" })
    table.insert(lines, { type = "topoGain", text = "Map:" })
    table.insert(lines, { type = "miniProfile" })

    -- Fill level (always shown)
    if inSilo then
        local fillLevel = siloAssistSiloDetector.siloFillLevel or 0
        local capacity = siloAssistSiloDetector.siloEstimatedCapacity or 1
        local fillPct = 0
        if capacity > 0 then
            fillPct = math.min(fillLevel / capacity * 100, 100)
        end
        table.insert(lines, { type = "valuePair",
            label = g_i18n:getText("sa_fill") .. ":",
            value = string.format("%s L (%.0f%%)", siloAssistHud.formatNumber(fillLevel), fillPct) })
    else
        table.insert(lines, { type = "valuePair",
            label = g_i18n:getText("sa_fill") .. ":",
            value = "--" })
    end

    -- Compaction (always shown)
    if inSilo then
        local compactedPct = siloAssistSiloDetector.siloCompactedPercent
        if compactedPct and compactedPct > 0 then
            table.insert(lines, { type = "valuePair",
                label = g_i18n:getText("sa_compact") .. ":",
                value = string.format("%d%%", compactedPct) })
        else
            table.insert(lines, { type = "valuePair",
                label = g_i18n:getText("sa_compact") .. ":",
                value = "--" })
        end
    else
        table.insert(lines, { type = "valuePair",
            label = g_i18n:getText("sa_compact") .. ":",
            value = "--" })
    end

    -- Soll/Ist (always shown)
    if inSilo then
        local bladeH = siloAssistHeightController.lastRaycastGroundDistance
        local targetH = siloAssistHeightController.lastTargetHeightAboveGround
        local bladeHStr = bladeH ~= nil and string.format("%.2fm", bladeH) or "--"
        local targetHStr = targetH ~= nil and string.format("%.2fm", targetH) or "--"
        table.insert(lines, { type = "valuePair",
            label = "Soll/Ist:",
            value = targetHStr .. " | " .. bladeHStr })
    else
        table.insert(lines, { type = "valuePair",
            label = "Soll/Ist:",
            value = "--" })
    end

    -- Speed (always shown)
    local speed = siloAssistSiloDetector.vehicleSpeed or 0
    local dirStr = siloAssistState.isReversing and "<<<" or ">>>"
    table.insert(lines, { type = "valuePair",
        label = g_i18n:getText("sa_speed") .. ":",
        value = string.format("%.1f km/h %s", speed, dirStr) })

    -- DUMPING/STUCK warning
    if siloAssistVehicleState.getState() == config.STATE_DUMPING then
        table.insert(lines, { type = "value",
            text = g_i18n:getText("sa_dumping"), color = siloAssistHud.COLOR_WARN })
    elseif siloAssistVehicleState.getState() == config.STATE_RAISING then
        table.insert(lines, { type = "value",
            text = g_i18n:getText("sa_stuck"), color = siloAssistHud.COLOR_WARN })
    end

    -- "Silo eben!" confirmation (TopoMap done state)
    if siloAssistTopoMap.doneConfirmed then
        table.insert(lines, { type = "value",
            text = "Silo eben!", color = siloAssistHud.COLOR_ACTIVE })
    end
end

function siloAssistHud.buildProfilePage(lines)
    for i = 1, 8 do
        table.insert(lines, { type = "empty" })
    end
end

function siloAssistHud.buildDebugPage(lines)
    if not siloAssistDebug.showDebug then
        table.insert(lines, { type = "value",
            text = g_i18n:getText("sa_debugInactive"), color = siloAssistHud.COLOR_WARN })
        return
    end

    local hc = siloAssistHeightController
    local sd = siloAssistSiloDetector
    local st = siloAssistState
    local function jn(v) return v and "J" or "N" end

    -- Geschwindigkeit | Festgefahren | Schlupf | Rückwärts
    local speed = sd.vehicleSpeed or 0
    local dirStr = st.isReversing and "<<" or ">>"
    table.insert(lines, { type = "value",
        text = string.format("Geschw: %.1f %s | Stuck: %s",
            speed, dirStr, jn(st.isStuck)) })

    -- Soll-Ist Differenz | Regelrichtung | Im Silo
    table.insert(lines, { type = "value",
        text = string.format("Soll-Ist: %+.3fm | Richtg: %+d | ImSilo: %s",
            hc.lastHeightDiff or 0,
            hc.lastAlphaDirection or 0,
            jn(sd.isInSilo)) })

    -- CL/CR Stichproben (Füllhöhe an Schildkanten, 5 Distanzen: 1/3/5/8/10m)
    -- S1-S5 Center-Punkte wurden entfernt, nur CL+CR bleibt
    local ch = hc.collisionSampleHeights
    local function cf(side, i)
        if ch ~= nil and ch[i] ~= nil and ch[i][side] ~= nil then
            return string.format("%.2f", ch[i][side])
        end
        return "--"
    end
    -- Zeile 1: CL1/CR1 (1m) + CL2/CR2 (3m)
    table.insert(lines, { type = "value",
        text = string.format("CL1:%s CR1:%s | CL2:%s CR2:%s",
            cf("leftFill", 1), cf("rightFill", 1),
            cf("leftFill", 2), cf("rightFill", 2)) })
    -- Zeile 2: CL3/CR3 (5m) + CL4/CR4 (8m)
    table.insert(lines, { type = "value",
        text = string.format("CL3:%s CR3:%s | CL4:%s CR4:%s",
            cf("leftFill", 3), cf("rightFill", 3),
            cf("leftFill", 4), cf("rightFill", 4)) })
    -- Zeile 3: CL5/CR5 (10m) + Kollisionshöhe unterm Schild + Median
    local colH = hc.lastRaycastGroundDistance
    local colStr = colH ~= nil and string.format("%.2fm", colH) or "--"
    local medStr = hc.lastSurfaceTarget ~= nil and string.format("%.2f", hc.lastSurfaceTarget) or "--"
    table.insert(lines, { type = "value",
        text = string.format("CL5:%s CR5:%s | Koll:%s Med:%s",
            cf("leftFill", 5), cf("rightFill", 5), colStr, medStr) })

    -- Profil-Typ + Vorhalt + LR + Silo
    local lrVal = hc.longRangeFillHeight
    local lrStr = lrVal ~= nil and string.format("%.2fm", lrVal) or "--"
    local lrDetected = hc.longRangeFillDetected and "J" or "N"
    local sd = siloAssistSiloDetector
    local siloStr = "--"
    if sd.currentSilo ~= nil then
        siloStr = string.format("%.1fx%.1fm", sd.siloLength, sd.siloWidth)
    end
    local profileStr = string.format("%s | Vorhalt: %+.0fmm | LR: %s (%s) | %s",
        hc._profileType or "?",
        (hc._preemptiveHeightDiff or 0) * 1000,
        lrStr, lrDetected, siloStr)
    table.insert(lines, { type = "value", text = profileStr })

    -- Vorderachse | Hinterachse Bodenabstand | Nickwinkel
    local function gv(v)
        return v ~= nil and string.format("%.2fm", v) or "--"
    end
    table.insert(lines, { type = "value",
        text = string.format("VoAchs: %s | HiAchs: %s | Nick: %.1f°",
            gv(hc.vehicleFrontGroundHeight),
            gv(hc.vehicleRearGroundHeight),
            hc.vehiclePitchDeg or 0) })

    -- (Alte absolute-SurfaceY CL/CR-Zeilen entfernt — Füllhöhen oben schon angezeigt)

    -- TopoMap stats
    local tm = siloAssistTopoMap
    local ts = tm.lastStats or {}
    local tmStr
    if tm.rows == 0 then
        tmStr = "-- (kein Silo)"
    else
        local doneMark = ts.done and " [eben]" or ""
        tmStr = string.format("avgP=%.2f avgR=%.2f cov=%.0f%% varP=%.3f cellsP=%d cellsR=%d%s",
            ts.avgPlateau or 0, ts.avgRamp or 0,
            ts.coveragePct or 0, ts.variancePlateau or 0,
            ts.cellsPlateau or 0, ts.cellsRamp or 0, doneMark)
    end
    table.insert(lines, { type = "value",
        text = "Map: " .. tmStr,
        color = (ts.done == true) and siloAssistHud.COLOR_ACTIVE or siloAssistHud.COLOR_LABEL })
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

---------------------------------------------------------------------
-- Mouse events
---------------------------------------------------------------------
function siloAssistHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not siloAssistVehicleState.isHudVisible() then return false end
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
        if siloAssistHud:isInButton(posX, posY, siloAssistHud._closeBtn) then
            siloAssistVehicleState.setHudVisible(false)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._toggleBtn) then
            siloAssist:toggleAssist()
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._debugLinesBtn) then
            siloAssistDebug.toggleLines()
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._debugDebugBtn) then
            siloAssistDebug.toggleDebug()
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._debugLogBtn) then
            siloAssistDebug.toggleLog()
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._prevBtn) then
            siloAssistHud.PAGE_INDEX = siloAssistHud.PAGE_INDEX - 1
            if siloAssistHud.PAGE_INDEX < 1 then
                siloAssistHud.PAGE_INDEX = #siloAssistHud.PAGES
            end
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._nextBtn) then
            siloAssistHud.PAGE_INDEX = siloAssistHud.PAGE_INDEX + 1
            if siloAssistHud.PAGE_INDEX > #siloAssistHud.PAGES then
                siloAssistHud.PAGE_INDEX = 1
            end
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._modeDtBtn) then
            if siloAssistVehicleState.getSiloMode() ~= "driveThrough" then
                siloAssistVehicleState.setSiloMode("driveThrough")
            end
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._modeWedgeBtn) then
            if siloAssistVehicleState.getSiloMode() ~= "wedge" then
                siloAssistVehicleState.setSiloMode("wedge")
            end
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._minusBtn) then
            siloAssistConfig.adjustOffset(-siloAssistConfig.OFFSET_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._plusBtn) then
            siloAssistConfig.adjustOffset(siloAssistConfig.OFFSET_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._tiltMinusBtn) then
            siloAssistConfig.adjustTilt(-siloAssistConfig.TILT_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._tiltPlusBtn) then
            siloAssistConfig.adjustTilt(siloAssistConfig.TILT_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._followMinusBtn) then
            siloAssistConfig.adjustFollow(-siloAssistConfig.FOLLOW_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._followPlusBtn) then
            siloAssistConfig.adjustFollow(siloAssistConfig.FOLLOW_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._lookaheadMinusBtn) then
            siloAssistConfig.adjustLookahead(-siloAssistConfig.LOOKAHEAD_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._lookaheadPlusBtn) then
            siloAssistConfig.adjustLookahead(siloAssistConfig.LOOKAHEAD_STEP)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._topoGainMinusBtn) then
            siloAssistConfig.adjustTopoGain(-0.1)
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._topoGainPlusBtn) then
            siloAssistConfig.adjustTopoGain(0.1)
            return true
        end

        -- Drag from header (but not on buttons)
        if siloAssistHud.hudPosX ~= nil and siloAssistHud.hudWidth ~= nil then
            local _, hH = getNormalizedScreenValues(1, siloAssistHud.HEADER_H)
            local hdrBot = siloAssistHud.y + siloAssistHud.hudHeight - hH
            local hdrTop = siloAssistHud.y + siloAssistHud.hudHeight
            if posX >= siloAssistHud.hudPosX and posX <= siloAssistHud.hudPosX + siloAssistHud.hudWidth
                and posY >= hdrBot and posY <= hdrTop then
                siloAssistHud.isDragging = true
                siloAssistHud.dragOffsetX = posX - siloAssistHud.x
                siloAssistHud.dragOffsetY = posY - siloAssistHud.y
                return true
            end
        end
    end

    if siloAssistHud:isMouseOverHud(posX, posY) then
        return true
    end
    return false
end

---------------------------------------------------------------------
-- Hit testing
---------------------------------------------------------------------
function siloAssistHud:isInButton(posX, posY, btn)
    if btn == nil then return false end
    return posX >= btn.x and posX <= btn.x + btn.w
        and posY >= btn.y and posY <= btn.y + btn.h
end

function siloAssistHud:isMouseOverHud(posX, posY)
    if siloAssistHud.hudPosX == nil then return false end
    return posX >= siloAssistHud.hudPosX
        and posX <= siloAssistHud.hudPosX + siloAssistHud.hudWidth
        and posY >= siloAssistHud.hudPosY
        and posY <= siloAssistHud.hudPosY + siloAssistHud.hudHeight
end

function siloAssistHud:clampPosition()
    if siloAssistHud.x == nil or siloAssistHud.y == nil then return end
    local w = siloAssistHud.hudWidth or 0
    local h = siloAssistHud.hudHeight or 0
    if w > 0 and h > 0 then
        siloAssistHud.x = math.clamp(siloAssistHud.x, 0, 1 - w)
        siloAssistHud.y = math.clamp(siloAssistHud.y, 0, 1 - h)
    end
end

---------------------------------------------------------------------
-- Draw 3D surface sample markers (debug mode only)
-- CL/CR edge spheres + LR sphere. Uses i3D drawing (siloAssistDrawing).
---------------------------------------------------------------------
function siloAssistHud:drawSurfaceSamples()
    local cSamples = siloAssistHeightController.collisionSamples
    local lrPos = siloAssistHeightController.longRangeWorldPos
    if (cSamples == nil or #cSamples == 0) and lrPos == nil then
        return
    end

    local vizOffset = 2.0
    local LINE_SCALE = 1.0
    local SPHERE_SCALE = 0.15
    local LR_SPHERE_SCALE = 0.25
    local ok, err = pcall(function()
        -- C1-C5 edge points (cyan=left, orange=right)
        local lastCenterX, lastCenterY, lastCenterZ
        local cHeights = siloAssistHeightController.collisionSampleHeights
        if cSamples ~= nil and cHeights ~= nil then
            local prevLeftX, prevLeftY, prevLeftZ
            local prevRightX, prevRightY, prevRightZ
            for i = 1, math.min(#cSamples, #cHeights) do
                local entry = cSamples[i]
                local hEntry = cHeights[i]
                if entry ~= nil and hEntry ~= nil then
                    local lVizY, rVizY

                    -- Left edge (cyan)
                    local lx, ly, lz = entry.left[1], entry.left[2], entry.left[3]
                    local lCollY = hEntry.left
                    if lCollY ~= nil then
                        lVizY = lCollY + vizOffset
                        if prevLeftX ~= nil then
                            siloAssistDrawing:addLine(prevLeftX, prevLeftY, prevLeftZ,
                                lx, lVizY, lz, 0, 1, 1, LINE_SCALE)
                        end
                        prevLeftX, prevLeftY, prevLeftZ = lx, lVizY, lz
                        siloAssistDrawing:addSmallSphere(lx, lVizY, lz, 0, 1, 1)
                        siloAssistDrawing:addLine(lx, lCollY, lz, lx, lVizY, lz, 0, 0.6, 0.6, LINE_SCALE)
                    end

                    -- Right edge (orange)
                    local rx, ry, rz = entry.right[1], entry.right[2], entry.right[3]
                    local rCollY = hEntry.right
                    if rCollY ~= nil then
                        rVizY = rCollY + vizOffset
                        if prevRightX ~= nil then
                            siloAssistDrawing:addLine(prevRightX, prevRightY, prevRightZ,
                                rx, rVizY, rz, 1, 0.6, 0, LINE_SCALE)
                        end
                        prevRightX, prevRightY, prevRightZ = rx, rVizY, rz
                        siloAssistDrawing:addSmallSphere(rx, rVizY, rz, 1, 0.6, 0)
                        siloAssistDrawing:addLine(rx, rCollY, rz, rx, rVizY, rz, 0.7, 0.3, 0, LINE_SCALE)

                        -- Track last center point for LR connection line
                        if lCollY ~= nil and lVizY ~= nil then
                            lastCenterX = (lx + rx) * 0.5
                            lastCenterY = (lVizY + rVizY) * 0.5
                            lastCenterZ = (lz + rz) * 0.5
                        end
                    end
                end
            end
        end

        -- LR point (gold, bigger sphere)
        local lrPos = siloAssistHeightController.longRangeWorldPos
        if lrPos ~= nil then
            local lx, ly, lz = lrPos[1], lrPos[2], lrPos[3]
            local lrSurfaceY = DensityMapHeightUtil.getHeightAtWorldPos(lx, ly, lz)
            local lrVizY = lrSurfaceY + vizOffset

            -- Connect from last C center to LR
            if lastCenterX ~= nil then
                siloAssistDrawing:addLine(lastCenterX, lastCenterY, lastCenterZ, lx, lrVizY, lz, 1, 0.8, 0, LINE_SCALE)
            end

            -- Sphere marker, bigger than C spheres
            siloAssistDrawing:addSphere(lx, lrVizY, lz, LR_SPHERE_SCALE, 1, 0.8, 0, 1)

            -- Vertical line
            siloAssistDrawing:addLine(lx, lrSurfaceY, lz, lx, lrVizY, lz, 0.6, 0.5, 0, LINE_SCALE)
        end
    end)
    if not ok then
        siloAssistDebug.log("HUD", "drawSurfaceSamples error: " .. tostring(err))
    end
end

---------------------------------------------------------------------
-- Draw 3D TopoMap grid (debug mode only)
-- Cells colored by deviation: green=avg, red=too high,
-- blue=too low. Small sphere at each cell center.
---------------------------------------------------------------------
function siloAssistHud:drawTopoMap()
    if siloAssistTopoMap.rows == 0 then
        return
    end

    local tm = siloAssistTopoMap
    local stats = tm.lastStats or {}
    local avg = stats.avg or 0
    local tolerance = siloAssistConfig.TOPO_MAP_DONE_TOLERANCE
    local vizOffset = 0.5
    local LINE_SCALE = 1.0

    local ok, err = pcall(function()
        for r = 1, tm.rows do
            for c = 1, tm.cols do
                local cell = tm.grid[r][c]
                if cell.fillHeight ~= nil then
                    local u = (r - 0.5) * tm.cellSize
                    local v = (c - 0.5) * tm.cellSize
                    local x = tm.origin.x + tm.axisH.x * u + tm.axisW.x * v
                    local z = tm.origin.z + tm.axisH.z * u + tm.axisW.z * v

                    local surfaceY = DensityMapHeightUtil.getHeightAtWorldPos(x, 0, z)
                    if surfaceY == nil then
                        surfaceY = 0
                    end
                    local vizY = surfaceY + vizOffset

                    -- Color by deviation: red = too high, blue = too low, green = avg
                    local dev = cell.fillHeight - avg
                    local cr, cg, cb
                    if math.abs(dev) < tolerance then
                        cr, cg, cb = 0.2, 0.8, 0.2
                    elseif dev > 0 then
                        local intensity = math.min(math.abs(dev) / (tolerance * 4), 1)
                        cr = 0.9
                        cg = 0.5 * (1 - intensity)
                        cb = 0.2
                    else
                        local intensity = math.min(math.abs(dev) / (tolerance * 4), 1)
                        cr = 0.2
                        cg = 0.5 * (1 - intensity)
                        cb = 0.9
                    end

                    siloAssistDrawing:addSmallSphere(x, vizY, z, cr, cg, cb)

                    siloAssistDrawing:addLine(x, surfaceY, z, x, vizY, z,
                        cr * 0.5, cg * 0.5, cb * 0.5, LINE_SCALE)
                end
            end
        end
    end)
    if not ok then
        siloAssistDebug.log("HUD", "drawTopoMap error: " .. tostring(err))
    end
end

---------------------------------------------------------------------
-- Profile chart page
---------------------------------------------------------------------
function siloAssistHud:renderProfileChart(x, y, w, m, hH, fH, lH, contentH, fFooter, fSmall)
    local hc = siloAssistHeightController
    if hc == nil then return end
    local ch = hc.collisionSampleHeights
    if ch == nil or ch[1] == nil then return end

    local s = {}
    for i = 1, 5 do
        if ch[i] ~= nil and ch[i].leftFill ~= nil and ch[i].rightFill ~= nil then
            s[i] = (ch[i].leftFill + ch[i].rightFill) * 0.5
        end
    end
    if s[1] == nil then return end

    local chartW = w - 2 * m
    local profileW = chartW * 0.80
    local lrW = chartW * 0.15
    local gap = chartW * 0.05
    local chartX = x + m

    local barW = profileW / 5
    local subW = barW / 3
    local lrBarW = lrW

    local chartBottom = y + fH + lH * 0.5
    local chartTop = y + fH + contentH - lH * 0.5
    local chartH = chartTop - chartBottom
    if chartH <= 2 * lH then return end

    local target = hc.lastTargetHeightAboveGround
    local hasTarget = target ~= nil
    target = target or 0
    local maxH = math.max(siloAssistConfig.SILO_MAX_HEIGHT_M, 0.1)
    local deadband = siloAssistConfig.HEIGHT_DEADBAND or 0.05

    local function barColor(val)
        if not hasTarget then return 0.2, 0.8, 0.2 end
        if val > target + deadband then return 1, 0.2, 0.2 end
        if val < target - deadband then return 0.2, 0.3, 1 end
        return 0.2, 0.8, 0.2
    end

    for i = 1, 5 do
        local baseX = chartX + (i - 1) * barW
        local centerVal = s[i] or 0
        local leftVal = (ch[i] and ch[i].leftFill) or 0
        local rightVal = (ch[i] and ch[i].rightFill) or 0

        for sub = 1, 3 do
            local val = sub == 1 and leftVal or (sub == 2 and centerVal or rightVal)
            local ratio = math.min(val / maxH, 1)
            local barHeight = ratio * chartH
            local r, g, b = barColor(val)
            local idx = (i - 1) * 3 + sub
            local ov = siloAssistHud.profileBars[idx]
            ov:setPosition(baseX + (sub - 1) * subW, chartBottom)
            ov:setDimension(subW, barHeight)
            ov:setColor(r, g, b, 0.8)
            ov:render()
        end
    end

    -- LR bar (6th, separated)
    local lrX = chartX + profileW + gap
    local lrVal = hc.longRangeFillHeight or 0
    local lrRatio = math.min(lrVal / maxH, 1)
    local lrBarHeight = lrRatio * chartH
    local lrDetected = hc.longRangeFillDetected
    siloAssistHud.profileLrBar:setPosition(lrX, chartBottom)
    siloAssistHud.profileLrBar:setDimension(lrBarW, lrBarHeight)
    siloAssistHud.profileLrBar:setColor(lrDetected and 0.2 or 0.3, lrDetected and 0.3 or 0.3, lrDetected and 0.8 or 0.3, 0.8)
    siloAssistHud.profileLrBar:render()

    -- Target line (white)
    if hasTarget then
        local targetRatio = math.min(target / maxH, 1)
        local targetY = chartBottom + targetRatio * chartH
        siloAssistHud.profileTargetLine:setPosition(chartX, targetY)
        siloAssistHud.profileTargetLine:setDimension(profileW, 0.003)
        siloAssistHud.profileTargetLine:setColor(1, 1, 1, 0.6)
        siloAssistHud.profileTargetLine:render()
    end

    -- Blade height line (green)
    local bladeH = hc.lastRaycastGroundDistance
    if bladeH ~= nil then
        local bladeRatio = math.min(bladeH / maxH, 1)
        local bladeY = chartBottom + bladeRatio * chartH
        siloAssistHud.profileBladeLine:setPosition(chartX, bladeY)
        siloAssistHud.profileBladeLine:setDimension(profileW, 0.002)
        siloAssistHud.profileBladeLine:setColor(0, 1, 0, 0.8)
        siloAssistHud.profileBladeLine:render()
    end

    -- Center values text (CL+CR mean in cm)
    local function cm(v)
        if v == nil or v <= 0 then return " 0" end
        return string.format("%2.0f", v * 100)
    end
    local valStr = string.format("%s %s %s %s %s",
        cm(s[1]), cm(s[2]), cm(s[3]), cm(s[4]), cm(s[5]))

    local valY = y + fH + lH * 0.25
    setTextColor(0.7, 0.7, 0.7, 0.9)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(chartX, valY, fSmall, valStr .. " cm")

    -- LR label
    local lrLabel = lrDetected and "LR: J" or "LR: N"
    setTextColor(lrDetected and 0.2 or 0.5, lrDetected and 0.3 or 0.5, lrDetected and 0.8 or 0.5, 0.9)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(lrX, valY, fSmall, lrLabel)
end

---------------------------------------------------------------------
-- Status text timer (stub - no longer rendered)
---------------------------------------------------------------------
function siloAssistHud:updateStatusText(dt)
end

---------------------------------------------------------------------
-- Save / load HUD position
---------------------------------------------------------------------
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