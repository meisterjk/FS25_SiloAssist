--====================================================================
-- SiloAssist - Debug Logging
-- Central debug toggle and per-module logging.
-- Toggle via HUD title bar button or console: siloAssistDebug toggle
--====================================================================

siloAssistDebug = {}

siloAssistDebug.enabled = false
siloAssistDebug.LOG_PREFIX = "[SA-DBG]"

siloAssistDebug.THROTTLE_MS = 200
siloAssistDebug._lastLogTimes = {}

---------------------------------------------------------------------
-- Init: sync with config.DEBUG if already set
---------------------------------------------------------------------
function siloAssistDebug.init()
    if siloAssistConfig.DEBUG then
        siloAssistDebug.enabled = true
    end
end

---------------------------------------------------------------------
-- Toggle debug on/off
---------------------------------------------------------------------
function siloAssistDebug.toggle()
    siloAssistDebug.enabled = not siloAssistDebug.enabled
    local state = siloAssistDebug.enabled and "ON" or "OFF"
    print(siloAssistDebug.LOG_PREFIX .. " Debug logging: " .. state)
    siloAssistHud.showStatusText("Debug: " .. state)
end

---------------------------------------------------------------------
-- Core log function (always prints, no throttle)
---------------------------------------------------------------------
function siloAssistDebug.log(module, msg)
    if not siloAssistDebug.enabled then
        return
    end
    print(siloAssistDebug.LOG_PREFIX .. " [" .. module .. "] " .. msg)
end

---------------------------------------------------------------------
-- Throttled log (max once per THROTTLE_MS per key)
---------------------------------------------------------------------
function siloAssistDebug.logThrottled(module, key, msg)
    if not siloAssistDebug.enabled then
        return
    end
    local now = getTime() * 1000
    local fullKey = module .. "." .. key
    local last = siloAssistDebug._lastLogTimes[fullKey]
    if last ~= nil and (now - last) < siloAssistDebug.THROTTLE_MS then
        return
    end
    siloAssistDebug._lastLogTimes[fullKey] = now
    print(siloAssistDebug.LOG_PREFIX .. " [" .. module .. "] " .. msg)
end

---------------------------------------------------------------------
-- Format helpers
---------------------------------------------------------------------
function siloAssistDebug.fmt(val, decimals)
    if val == nil then
        return "nil"
    end
    if decimals == nil then
        decimals = 3
    end
    if type(val) == "number" then
        return string.format("%." .. decimals .. "f", val)
    end
    return tostring(val)
end

---------------------------------------------------------------------
-- Console command
---------------------------------------------------------------------
function siloAssistDebug.consoleToggle()
    siloAssistDebug.toggle()
end