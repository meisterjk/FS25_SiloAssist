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

siloAssistHud.PAGES = {"setup", "debug"}
siloAssistHud.PAGE_INDEX = 1

siloAssistHud.FALLBACK_UVS = {0, 0, 1, 0, 1, 1, 0, 1}
siloAssistHud.isInitialized = false

siloAssistHud.OVERLAY_PREFIX = "siloAssistIcons"

siloAssistHud.CLOSE_PX = 12
siloAssistHud.CHECK_PX = 12
siloAssistHud.NAV_BTN_PX = 12
siloAssistHud.OFFSET_BTN_PX = 12
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
siloAssistHud._checkBtn = nil
siloAssistHud._prevBtn = nil
siloAssistHud._nextBtn = nil
siloAssistHud._modeDtBtn = nil
siloAssistHud._modeWedgeBtn = nil
siloAssistHud._minusBtn = nil
siloAssistHud._plusBtn = nil
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
    siloAssistHud._toggleBtn = nil

    local w, _ = getNormalizedScreenValues(siloAssistHud.WIDTH, 1)
    local m, _ = getNormalizedScreenValues(siloAssistHud.MARGIN, 1)
    local _, hH = getNormalizedScreenValues(1, siloAssistHud.HEADER_H)
    local _, fH = getNormalizedScreenValues(1, siloAssistHud.FOOTER_H)
    local _, lH = getNormalizedScreenValues(1, siloAssistHud.LINE_H)

    local closeW, closeH = getNormalizedScreenValues(siloAssistHud.CLOSE_PX, siloAssistHud.CLOSE_PX)
    local checkW, checkH = getNormalizedScreenValues(siloAssistHud.CHECK_PX, siloAssistHud.CHECK_PX)
    local navBtnW, navBtnH = getNormalizedScreenValues(siloAssistHud.NAV_BTN_PX, siloAssistHud.NAV_BTN_PX)
    local offBtnW, offBtnH = getNormalizedScreenValues(siloAssistHud.OFFSET_BTN_PX, siloAssistHud.OFFSET_BTN_PX)
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

    -- Debug checkbox (left of close button)
    local checkX = closeBtnX - m - checkW
    local checkY = headerY + siloAssistHud:centerY(hH, checkH)
    siloAssistHud._checkBtn = {x = checkX, y = checkY, w = checkW, h = checkH}
    local checkOv = siloAssistDebug.enabled and siloAssistHud.checkOvChecked or siloAssistHud.checkOvUnchecked
    checkOv:setPosition(checkX, checkY)
    checkOv:setDimension(checkW, checkH)
    checkOv:setColor(1, 1, 1, 0.95)
    checkOv:render()

    -- "debug" label left of checkbox
    setTextColor(1, 1, 1, 0.7)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(checkX - m, headerY + siloAssistHud:centerY(hH, fSmall), fSmall, "debug")

    -- "|" separator left of debug
    local debugTextW = getTextWidth(fSmall, "debug")
    local sepX = checkX - m - debugTextW - m
    setTextColor(1, 1, 1, 0.4)
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(sepX, headerY + siloAssistHud:centerY(hH, fSmall), fSmall, "|")

    -- Toggle switch (left of separator)
    local state = siloAssistVehicleState.getState()
    local isActive = state ~= siloAssistConfig.STATE_OFF
    local toggleOv = isActive and siloAssistHud.switchOnOv or siloAssistHud.switchOffOv
    local toggleX = sepX - m - switchW
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
    local titleLabel = pageTitle == "setup" and g_i18n:getText("sa_mode") or g_i18n:getText("sa_debugTab")
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
    end

    return lines
end

function siloAssistHud.buildSetupPage(lines)
    local config = siloAssistConfig
    local inSilo = siloAssistSiloDetector.isInSilo and siloAssistSiloDetector.currentSilo ~= nil

    table.insert(lines, { type = "checkboxes" })
    table.insert(lines, { type = "offset", text = g_i18n:getText("sa_offset") .. ":" })

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
end

function siloAssistHud.buildDebugPage(lines)
    if not siloAssistDebug.enabled then
        table.insert(lines, { type = "value",
            text = g_i18n:getText("sa_debugInactive"), color = siloAssistHud.COLOR_WARN })
        return
    end

    local config = siloAssistConfig

    table.insert(lines, { type = "value",
        text = string.format("%s: %s", g_i18n:getText("sa_state"),
            siloAssistVehicleState.getState()) })

    table.insert(lines, { type = "value",
        text = string.format("Offset: %.3f | AlphaStep: %.3f",
            siloAssistVehicleState.getHeightOffset(), config.ALPHA_STEP) })

    table.insert(lines, { type = "value",
        text = string.format("RampS: %.2f->%.2f | RampE: %.2f->%.2f",
            config.RAMP_START_PCT, config.RAMP_MIN_START_PCT,
            config.RAMP_END_PCT, config.RAMP_MAX_END_PCT) })

    if siloAssistSiloDetector.isInSilo then
        table.insert(lines, { type = "value",
            text = string.format("FillH@Veh: %.3f | FillH@Blade: %.3f",
                siloAssistSiloDetector.densityFillHeightAtVehicle or 0,
                siloAssistSiloDetector.densityFillHeightAtBlade or 0) })

        table.insert(lines, { type = "value",
            text = string.format("TerrH: %.3f | StageH: %.3f",
                siloAssistSiloDetector.siloTerrainHeightAtVehicle or 0,
                siloAssistSiloDetector.stagedFillHeight or 0) })
    end

    if siloAssistHeightController.lastRaycastGroundDistance ~= nil then
        table.insert(lines, { type = "value",
            text = string.format("RayH: %.3fm", siloAssistHeightController.lastRaycastGroundDistance) })
    end

    table.insert(lines, { type = "value",
        text = string.format("Speed: %.1f | Stuck: %s | Slip: %s | Rev: %s",
            siloAssistSiloDetector.vehicleSpeed or 0,
            tostring(siloAssistState.isStuck),
            tostring(siloAssistState.wheelSlipDetected),
            tostring(siloAssistState.isReversing)) })

    table.insert(lines, { type = "value",
        text = string.format("hDiff: %.3f | InSilo: %s | Pitch: %.1f",
            siloAssistHeightController.lastHeightDiff or 0,
            tostring(siloAssistSiloDetector.isInSilo),
            siloAssistHeightController.vehiclePitchDeg or 0) })

    table.insert(lines, { type = "value",
        text = string.format("Tool: %s | Ctrl: %s | Front: %s",
            tostring(siloAssistToolDetection.toolType),
            tostring(siloAssistToolDetection.controlType),
            tostring(siloAssistToolDetection.isFrontAttached)) })

    table.insert(lines, { type = "value",
        text = string.format("Tilt: %.1f | Pitch: %.1f | WedgePass: %d",
            siloAssistTiltController.lastAppliedTiltDeg or 0,
            siloAssistHeightController.lastPitchDeg or 0,
            siloAssistHeightController.wedgePassCount or 0) })
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

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._checkBtn) then
            siloAssistDebug.toggle()
            return true
        end

        if siloAssistHud:isInButton(posX, posY, siloAssistHud._toggleBtn) then
            siloAssist:toggleAssist()
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