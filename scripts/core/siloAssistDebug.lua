--====================================================================
-- SiloAssist - Debug Logging
-- Three independent flags: showLines, showDebug, showLog.
-- Each controls a different aspect of debug output.
--====================================================================

siloAssistDebug = {}

siloAssistDebug.showLines = false  -- 3D surface markers in viewport
siloAssistDebug.showDebug = false  -- Debug HUD page (2nd page values)
siloAssistDebug.showLog = false    -- Console print output

siloAssistDebug.LOG_PREFIX = "[SA-DBG]"

siloAssistDebug.THROTTLE_MS = 200
siloAssistDebug._lastLogTimes = {}

---------------------------------------------------------------------
-- Init: sync with config.DEBUG if already set
---------------------------------------------------------------------
function siloAssistDebug.init()
    if siloAssistConfig.DEBUG then
        siloAssistDebug.showLines = true
        siloAssistDebug.showDebug = true
        siloAssistDebug.showLog = true
    end
end

---------------------------------------------------------------------
-- Toggle helpers
---------------------------------------------------------------------
function siloAssistDebug.toggleLines()
    siloAssistDebug.showLines = not siloAssistDebug.showLines
    local state = siloAssistDebug.showLines and "ON" or "OFF"
    print(siloAssistDebug.LOG_PREFIX .. " Surface lines: " .. state)
end

function siloAssistDebug.toggleDebug()
    siloAssistDebug.showDebug = not siloAssistDebug.showDebug
    local state = siloAssistDebug.showDebug and "ON" or "OFF"
    print(siloAssistDebug.LOG_PREFIX .. " Debug HUD: " .. state)
end

function siloAssistDebug.toggleLog()
    siloAssistDebug.showLog = not siloAssistDebug.showLog
    local state = siloAssistDebug.showLog and "ON" or "OFF"
    print(siloAssistDebug.LOG_PREFIX .. " Console logging: " .. state)
end

---------------------------------------------------------------------
-- Core log function (always prints, no throttle)
---------------------------------------------------------------------
function siloAssistDebug.log(module, ...)
    if not siloAssistDebug.showLog then
        return
    end
    local parts = {...}
    local msg = ""
    for i, v in ipairs(parts) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(v)
    end
    print(siloAssistDebug.LOG_PREFIX .. " [" .. module .. "] " .. msg)
end

---------------------------------------------------------------------
-- Throttled log (max once per THROTTLE_MS per key)
---------------------------------------------------------------------
function siloAssistDebug.logThrottled(module, key, msg)
    if not siloAssistDebug.showLog then
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
-- Console commands
---------------------------------------------------------------------
function siloAssistDebug.consoleToggle()
    siloAssistDebug.toggleLog()
end
