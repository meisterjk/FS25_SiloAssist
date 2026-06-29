siloAssistModPanel = {}

siloAssistModPanel.TAB_ID = "siloAssist"
siloAssistModPanel.PAGE_STATUS = "status"
siloAssistModPanel.PAGE_SETTINGS = "settings"
siloAssistModPanel.PAGE_DEBUG = "debug"

siloAssistModPanel.widgets = {}
siloAssistModPanel.widgetsCached = false
siloAssistModPanel.registered = false

function siloAssistModPanel.getModPanel()
    local ns = FS25_ModPanel_dev
    if ns and ns.ModPanel then
        return ns.ModPanel
    end
    ns = FS25_ModPanel
    if ns and ns.ModPanel then
        return ns.ModPanel
    end
    return nil
end

function siloAssistModPanel.register()
    local ModPanel = siloAssistModPanel.getModPanel()
    print("[SiloAssist/ModPanel] register() called, ModPanel=" .. tostring(ModPanel))
    if ModPanel == nil then
        print("[SiloAssist/ModPanel] ModPanel is nil, skipping registration")
        return
    end

    print("[SiloAssist/ModPanel] ModPanel.isReady=" .. tostring(ModPanel.isReady))

    local TAB = siloAssistModPanel.TAB_ID
    local PS = siloAssistModPanel.PAGE_STATUS
    local PSET = siloAssistModPanel.PAGE_SETTINGS
    local PD = siloAssistModPanel.PAGE_DEBUG

    ModPanel.registerTab({
        id = TAB,
        modName = "FS25_SiloAssist",
        title = "SiloAssist",
    })

    ModPanel.addPage(TAB, { id = PS, title = "Status" })
    ModPanel.addPage(TAB, { id = PSET, title = "Settings" })
    ModPanel.addPage(TAB, { id = PD, title = "Debug" })

    ModPanel.addElement(TAB, {
        id = "stateLabel", type = "text", pageId = PS,
        text = "State:", row = 1, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "stateValue", type = "text", pageId = PS,
        text = "OFF", row = 1, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "modeLabel", type = "text", pageId = PS,
        text = "Mode:", row = 2, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "modeValue", type = "clickableText", pageId = PS,
        text = "Drive Through", row = 2, col = 2,
        onClick = function() siloAssist:cycleSettings() end,
    })
    ModPanel.addElement(TAB, {
        id = "fillLabel", type = "text", pageId = PS,
        text = "Fill:", row = 3, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "fillValue", type = "text", pageId = PS,
        text = "--", row = 3, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "progressLabel", type = "text", pageId = PS,
        text = "Progress:", row = 4, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "progressValue", type = "text", pageId = PS,
        text = "--", row = 4, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "speedLabel", type = "text", pageId = PS,
        text = "Speed:", row = 5, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "speedValue", type = "text", pageId = PS,
        text = "--", row = 5, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "toolLabel", type = "text", pageId = PS,
        text = "Tool:", row = 6, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "toolValue", type = "text", pageId = PS,
        text = "--", row = 6, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "siloStateLabel", type = "text", pageId = PS,
        text = "Silo:", row = 7, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "siloStateValue", type = "text", pageId = PS,
        text = "--", row = 7, col = 2,
    })

    ModPanel.addElement(TAB, {
        id = "settingsModeLabel", type = "text", pageId = PSET,
        text = "Mode:", row = 1, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "settingsModeValue", type = "clickableText", pageId = PSET,
        text = "Drive Through", row = 1, col = 2,
        onClick = function() siloAssist:cycleSettings() end,
    })
    ModPanel.addElement(TAB, {
        id = "offsetLabel", type = "text", pageId = PSET,
        text = "Offset:", row = 2, col = 1,
    })
    ModPanel.addElement(TAB, {
        id = "offsetValue", type = "text", pageId = PSET,
        text = "+0.05m", row = 2, col = 2,
    })
    ModPanel.addElement(TAB, {
        id = "offsetMinus", type = "iconButton", pageId = PSET,
        fallbackText = "-", row = 3, col = 1,
        onClick = function() siloAssistConfig.adjustOffset(-siloAssistConfig.OFFSET_STEP) end,
    })
    ModPanel.addElement(TAB, {
        id = "offsetPlus", type = "iconButton", pageId = PSET,
        fallbackText = "+", row = 3, col = 2,
        onClick = function() siloAssistConfig.adjustOffset(siloAssistConfig.OFFSET_STEP) end,
    })
    ModPanel.addElement(TAB, {
        id = "debugToggle", type = "changeIcon", pageId = PSET,
        fallbackTextActive = "V", fallbackTextInactive = "X",
        text = "Debug", row = 4, col = 1, colSpan = 2,
        active = false,
        onChange = function(active)
            siloAssistDebug.showDebug = active
            siloAssistModPanel.updateDebugVisibility()
        end,
    })

    ModPanel.addElement(TAB, {
        id = "debugStateLabel", type = "text", pageId = PD,
        text = "State:", row = 1, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "debugStateValue", type = "text", pageId = PD,
        text = "--", row = 1, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgOffsetLabel", type = "text", pageId = PD,
        text = "Offset:", row = 2, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgOffsetValue", type = "text", pageId = PD,
        text = "--", row = 2, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgRampLabel", type = "text", pageId = PD,
        text = "Ramp:", row = 3, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgRampValue", type = "text", pageId = PD,
        text = "--", row = 3, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgFillLabel", type = "text", pageId = PD,
        text = "FillH:", row = 4, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgFillValue", type = "text", pageId = PD,
        text = "--", row = 4, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgPitchLabel", type = "text", pageId = PD,
        text = "Pitch:", row = 5, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgPitchValue", type = "text", pageId = PD,
        text = "--", row = 5, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgStuckLabel", type = "text", pageId = PD,
        text = "Stuck:", row = 6, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgStuckValue", type = "text", pageId = PD,
        text = "--", row = 6, col = 2, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgToolLabel", type = "text", pageId = PD,
        text = "Tool:", row = 7, col = 1, visible = false,
    })
    ModPanel.addElement(TAB, {
        id = "dbgToolValue", type = "text", pageId = PD,
        text = "--", row = 7, col = 2, visible = false,
    })

    siloAssistModPanel.widgetsCached = false
    siloAssistModPanel.registered = true
    print("[SiloAssist/ModPanel] registration complete, all elements queued")
end

function siloAssistModPanel.ensureWidgetCache()
    if siloAssistModPanel.widgetsCached then
        return true
    end
    local ModPanel = siloAssistModPanel.getModPanel()
    if ModPanel == nil or not ModPanel.isReady then
        print("[SiloAssist/ModPanel] ensureWidgetCache: ModPanel not ready yet")
        return false
    end

    print("[SiloAssist/ModPanel] ensureWidgetCache: caching widget refs...")

    local W = {}
    local TAB = siloAssistModPanel.TAB_ID
    local PS = siloAssistModPanel.PAGE_STATUS
    local PSET = siloAssistModPanel.PAGE_SETTINGS
    local PD = siloAssistModPanel.PAGE_DEBUG

    W.stateValue = ModPanel.getWidget(TAB, PS, "stateValue")
    W.modeValue = ModPanel.getWidget(TAB, PS, "modeValue")
    W.fillValue = ModPanel.getWidget(TAB, PS, "fillValue")
    W.progressValue = ModPanel.getWidget(TAB, PS, "progressValue")
    W.speedValue = ModPanel.getWidget(TAB, PS, "speedValue")
    W.toolValue = ModPanel.getWidget(TAB, PS, "toolValue")
    W.siloStateValue = ModPanel.getWidget(TAB, PS, "siloStateValue")

    W.settingsModeValue = ModPanel.getWidget(TAB, PSET, "settingsModeValue")
    W.offsetValue = ModPanel.getWidget(TAB, PSET, "offsetValue")
    W.debugToggle = ModPanel.getWidget(TAB, PSET, "debugToggle")

    W.debugStateValue = ModPanel.getWidget(TAB, PD, "debugStateValue")
    W.dbgOffsetValue = ModPanel.getWidget(TAB, PD, "dbgOffsetValue")
    W.dbgRampValue = ModPanel.getWidget(TAB, PD, "dbgRampValue")
    W.dbgFillValue = ModPanel.getWidget(TAB, PD, "dbgFillValue")
    W.dbgPitchValue = ModPanel.getWidget(TAB, PD, "dbgPitchValue")
    W.dbgStuckValue = ModPanel.getWidget(TAB, PD, "dbgStuckValue")
    W.dbgToolValue = ModPanel.getWidget(TAB, PD, "dbgToolValue")

    siloAssistModPanel.widgets = W
    siloAssistModPanel.widgetsCached = true
    print("[SiloAssist/ModPanel] ensureWidgetCache: cached widget refs successfully")
    return true
end

function siloAssistModPanel.updateDebugVisibility()
    local ModPanel = siloAssistModPanel.getModPanel()
    if ModPanel == nil then
        return
    end
    local TAB = siloAssistModPanel.TAB_ID
    local PD = siloAssistModPanel.PAGE_DEBUG
    local debugOn = siloAssistDebug.showDebug

    local debugWidgetIds = {
        "debugStateLabel", "debugStateValue",
        "dbgOffsetLabel", "dbgOffsetValue",
        "dbgRampLabel", "dbgRampValue",
        "dbgFillLabel", "dbgFillValue",
        "dbgPitchLabel", "dbgPitchValue",
        "dbgStuckLabel", "dbgStuckValue",
        "dbgToolLabel", "dbgToolValue",
    }

    for _, widgetId in ipairs(debugWidgetIds) do
        ModPanel.setWidgetVisible(TAB, PD, widgetId, debugOn)
    end
end

function siloAssistModPanel.update()
    local ModPanel = siloAssistModPanel.getModPanel()
    if ModPanel == nil then
        return
    end

    if not siloAssistModPanel.registered and ModPanel.isReady then
        siloAssistModPanel.register()
    end

    if not siloAssistModPanel.ensureWidgetCache() then
        return
    end

    local W = siloAssistModPanel.widgets
    local TAB = siloAssistModPanel.TAB_ID
    local PS = siloAssistModPanel.PAGE_STATUS
    local PSET = siloAssistModPanel.PAGE_SETTINGS

    local state = siloAssistVehicleState.getState()
    local isActive = state == siloAssistConfig.STATE_ACTIVE
        or state == siloAssistConfig.STATE_DUMPING
        or state == siloAssistConfig.STATE_RAISING

    if W.stateValue ~= nil then
        if isActive then
            ModPanel.setWidgetText(TAB, PS, "stateValue", state)
            ModPanel.setWidgetActive(TAB, PS, "stateValue", true)
        else
            ModPanel.setWidgetText(TAB, PS, "stateValue", state)
            ModPanel.setWidgetActive(TAB, PS, "stateValue", false)
        end
    end

    local modeLabel = g_i18n:getText(siloAssistConfig.getModeLabel())
    if W.modeValue ~= nil then
        ModPanel.setWidgetText(TAB, PS, "modeValue", modeLabel)
    end
    if W.settingsModeValue ~= nil then
        ModPanel.setWidgetText(TAB, PSET, "settingsModeValue", modeLabel)
    end

    if siloAssistSiloDetector.isInSilo and siloAssistSiloDetector.currentSilo ~= nil then
        local fillLevel = siloAssistSiloDetector.siloFillLevel or 0
        local capacity = siloAssistSiloDetector.siloEstimatedCapacity or 1
        local fillPct = 0
        if capacity > 0 then
            fillPct = math.min(fillLevel / capacity * 100, 100)
        end
        local fillText = string.format("%s L (%.0f%%)", siloAssistHud.formatNumber(fillLevel), fillPct)
        if W.fillValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "fillValue", fillText)
        end

        local progressText = string.format("%.0f%%", (siloAssistSiloDetector.progress or 0) * 100)
        if W.progressValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "progressValue", progressText)
        end

        local stateName = siloAssistSiloDetector.getSiloStateName(siloAssistSiloDetector.siloState)
        if W.siloStateValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "siloStateValue", stateName)
        end
    else
        if W.fillValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "fillValue", "--")
        end
        if W.progressValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "progressValue", "--")
        end
        if W.siloStateValue ~= nil then
            ModPanel.setWidgetText(TAB, PS, "siloStateValue", "--")
        end
    end

    local speed = siloAssistSiloDetector.vehicleSpeed or 0
    local dirStr = siloAssistState.isReversing and "<<<" or ">>>"
    if W.speedValue ~= nil then
        ModPanel.setWidgetText(TAB, PS, "speedValue",
            string.format("%.1f km/h %s", speed, dirStr))
    end

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
    if W.toolValue ~= nil then
        ModPanel.setWidgetText(TAB, PS, "toolValue", toolLabel)
    end

    local offsetSign = siloAssistVehicleState.getHeightOffset() >= 0 and "+" or ""
    local offsetValStr = string.format("%s%.2fm", offsetSign, siloAssistVehicleState.getHeightOffset())
    if W.offsetValue ~= nil then
        ModPanel.setWidgetText(TAB, PSET, "offsetValue", offsetValStr)
    end

    if W.debugToggle ~= nil then
        ModPanel.setWidgetActive(TAB, PSET, "debugToggle", siloAssistDebug.showDebug)
    end

    if siloAssistDebug.showDebug then
        siloAssistModPanel.updateDebugData()
    end
end

function siloAssistModPanel.updateDebugData()
    local ModPanel = siloAssistModPanel.getModPanel()
    if ModPanel == nil then
        return
    end
    local W = siloAssistModPanel.widgets
    local TAB = siloAssistModPanel.TAB_ID
    local PD = siloAssistModPanel.PAGE_DEBUG

    local state = siloAssistVehicleState.getState()
    if W.debugStateValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "debugStateValue", state)
    end

    local offsetStr = string.format("%.3f | AlphaStep: %.3f",
        siloAssistVehicleState.getHeightOffset(), siloAssistConfig.ALPHA_STEP)
    if W.dbgOffsetValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgOffsetValue", offsetStr)
    end

    local rampStr = string.format("Einf:%.1fm Ausf:%.1fm",
        siloAssistConfig.ENTRY_RAMP_METERS, siloAssistConfig.EXIT_RAMP_LENGTH)
    if W.dbgRampValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgRampValue", rampStr)
    end

    local fillStr = "--"
    if siloAssistSiloDetector.isInSilo then
        fillStr = string.format("%.3f", siloAssistSiloDetector.stagedFillHeight or 0)
    end
    if W.dbgFillValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgFillValue", fillStr)
    end

    local pitchStr = "--"
    if siloAssistHeightController.lastPitchDeg ~= nil then
        pitchStr = string.format("%.1f deg", siloAssistHeightController.lastPitchDeg)
    end
    if W.dbgPitchValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgPitchValue", pitchStr)
    end

    local stuckStr = string.format("%s | Rev: %s",
        tostring(siloAssistState.isStuck),
        tostring(siloAssistState.isReversing))
    if W.dbgStuckValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgStuckValue", stuckStr)
    end

    local toolStr = string.format("%s | %s | Blade: %s | Front: %s",
        tostring(siloAssistToolDetection.toolType),
        tostring(siloAssistToolDetection.controlType),
        tostring(siloAssistToolDetection.bladeNode ~= nil),
        tostring(siloAssistToolDetection.isFrontAttached))
    if W.dbgToolValue ~= nil then
        ModPanel.setWidgetText(TAB, PD, "dbgToolValue", toolStr)
    end
end

function siloAssistModPanel.deleteMap()
    siloAssistModPanel.widgets = {}
    siloAssistModPanel.widgetsCached = false
    siloAssistModPanel.registered = false
end