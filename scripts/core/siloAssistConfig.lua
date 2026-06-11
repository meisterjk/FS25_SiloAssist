siloAssistConfig = {}

siloAssistConfig.VERSION = "0.2.0"

-- Debug
siloAssistConfig.DEBUG = false
siloAssistConfig.DEBUG_SHOW_HEIGHT = false

-- Silo mode (default, overridden per-vehicle)
siloAssistConfig.DEFAULT_SILO_MODE = "driveThrough"
siloAssistConfig.MODES = {
    { key = "driveThrough", label = "SA_MODE_DRIVETHROUGH" },
    { key = "wedge",         label = "SA_MODE_WEDGE" },
}

-- Drive-through ramp parameters
siloAssistConfig.RAMP_START_PCT = 0.15
siloAssistConfig.RAMP_END_PCT = 0.85
siloAssistConfig.RAMP_MIN_START_PCT = 0.05
siloAssistConfig.RAMP_MAX_END_PCT = 0.95

-- Height control (default HEIGHT_OFFSET, overridden per-vehicle)
siloAssistConfig.DEFAULT_HEIGHT_OFFSET = 0.05
siloAssistConfig.OFFSET_MIN = -0.5
siloAssistConfig.OFFSET_MAX = 1.0
siloAssistConfig.OFFSET_STEP = 0.10
siloAssistConfig.ALPHA_STEP = 0.04
siloAssistConfig.HEIGHT_THRESHOLD = 0.04
siloAssistConfig.HEIGHT_DEADBAND = 0.05

-- Tilt control
siloAssistConfig.SHIELD_TILT_DEG = 5
siloAssistConfig.SHIELD_TILT_PITCH_FACTOR = -1
siloAssistConfig.SHIELD_TILT_HYSTERESIS_DEG = 1
siloAssistConfig.SHIELD_TILT_MIN = -5
siloAssistConfig.SHIELD_TILT_MAX = 15

-- Vehicle behavior
siloAssistConfig.REVERSE_RAISE_SPEED = 3.0
siloAssistConfig.MIN_SPEED_FOR_CONTROL = 2.0

-- Silo geometry & fill estimation
siloAssistConfig.SILO_MAX_HEIGHT_M = 4.0
siloAssistConfig.DENSITY_LITERS_PER_CBM = 1000
siloAssistConfig.FILL_LEVEL_STEP = 20000
siloAssistConfig.FILL_HEIGHT_SMOOTHING = 0.95

-- Wedge mode
siloAssistConfig.WEDGE_MAX_HEIGHT = 1.5
siloAssistConfig.WEDGE_INCREMENT = 0.02
siloAssistConfig.WEDGE_HEIGHT_M = 0.3

-- Pre-positioning
siloAssistConfig.PRE_ENTRY_DISTANCE = 2.0

-- Shovel/dump mode
siloAssistConfig.DUMP_HEIGHT_OFFSET = 1.5
siloAssistConfig.DUMP_POSITION_PCT = 0.95

-- Stuck detection
siloAssistConfig.STUCK_SPEED_THRESHOLD = 1.0
siloAssistConfig.STUCK_TIME_THRESHOLD = 1.0
siloAssistConfig.STUCK_RAISE_STEP = 0.02

siloAssistConfig.STATE_OFF = "OFF"
siloAssistConfig.STATE_WAITING = "WAITING"
siloAssistConfig.STATE_ACTIVE = "ACTIVE"
siloAssistConfig.STATE_DUMPING = "DUMPING"
siloAssistConfig.STATE_RAISING = "RAISING"

function siloAssistConfig.getModeIndex(modeKey)
    for i, mode in ipairs(siloAssistConfig.MODES) do
        if mode.key == modeKey then
            return i
        end
    end
    return 1
end

function siloAssistConfig.cycleMode()
    local currentMode = siloAssistVehicleState.getSiloMode()
    local currentIndex = siloAssistConfig.getModeIndex(currentMode)
    local nextIndex = (currentIndex % #siloAssistConfig.MODES) + 1
    local newMode = siloAssistConfig.MODES[nextIndex].key
    siloAssistVehicleState.setSiloMode(newMode)
    return newMode
end

function siloAssistConfig.getModeLabel()
    local currentMode = siloAssistVehicleState.getSiloMode()
    local idx = siloAssistConfig.getModeIndex(currentMode)
    return siloAssistConfig.MODES[idx].label
end

function siloAssistConfig.adjustOffset(delta)
    local currentOffset = siloAssistVehicleState.getHeightOffset()
    local newOffset = math.clamp(
        currentOffset + delta,
        siloAssistConfig.OFFSET_MIN,
        siloAssistConfig.OFFSET_MAX)
    siloAssistVehicleState.setHeightOffset(newOffset)
    return newOffset
end