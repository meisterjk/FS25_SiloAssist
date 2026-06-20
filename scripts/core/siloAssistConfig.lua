siloAssistConfig = {}

siloAssistConfig.VERSION = "0.3.2"

-- Debug
siloAssistConfig.DEBUG = false
siloAssistConfig.DEBUG_SHOW_HEIGHT = false

-- Silo mode (default, overridden per-vehicle)
siloAssistConfig.DEFAULT_SILO_MODE = "driveThrough"
siloAssistConfig.MODES = {
    { key = "driveThrough", label = "SA_MODE_DRIVETHROUGH" },
    { key = "wedge",         label = "SA_MODE_WEDGE" },
}

-- Drive-through ramp lengths in meters (converted to progress % by silo length)
siloAssistConfig.ENTRY_RAMP_METERS = 12.0
siloAssistConfig.EXIT_RAMP_METERS = 8.0

-- Exit ramp: raise blade + tilt backward to empty material before leaving silo
siloAssistConfig.EXIT_RAMP_HEIGHT_ADD = 0.3
siloAssistConfig.EXIT_RAMP_HEIGHT_FILL_FACTOR = 0.5
siloAssistConfig.EXIT_RAMP_TILT_MAX_DEG = 20

-- Minimum absolute height above fill (always at least 20cm above fill)
siloAssistConfig.MIN_HEIGHT_ABOVE_FILL = 0.20

-- Auto-offset: 5cm per meter of fill height (compensates for vehicle sinking)
siloAssistConfig.AUTO_FILL_OFFSET_FACTOR = 0.05

-- Height control (default HEIGHT_OFFSET, overridden per-vehicle)
siloAssistConfig.DEFAULT_HEIGHT_OFFSET = 0.0
siloAssistConfig.OFFSET_MIN = -0.5
siloAssistConfig.OFFSET_MAX = 1.0
siloAssistConfig.OFFSET_STEP = 0.10
siloAssistConfig.ALPHA_STEP = 0.04
siloAssistConfig.HEIGHT_THRESHOLD = 0.04
siloAssistConfig.HEIGHT_DEADBAND = 0.05

-- Surface sampling / follow factor
siloAssistConfig.FOLLOW_FACTOR = 0.5
siloAssistConfig.FOLLOW_STEP = 0.1
siloAssistConfig.FOLLOW_MIN = 0.0
siloAssistConfig.FOLLOW_MAX = 1.0

-- Lookahead time: how many seconds ahead to sample surface
siloAssistConfig.LOOKAHEAD_TIME = 1.5
siloAssistConfig.LOOKAHEAD_STEP = 0.25
siloAssistConfig.LOOKAHEAD_MIN = 0.5
siloAssistConfig.LOOKAHEAD_MAX = 5.0

-- Profile-based preemptive adjustment (0 = disabled)
siloAssistConfig.PROFILE_GAIN = 0.3

-- Auto-tilt: degrees per meter of fill height
siloAssistConfig.AUTO_TILT_FACTOR = 2.5
-- Tilt as height range-extender: degrees per meter of height error when alpha is saturated
siloAssistConfig.TILT_HEIGHT_GAIN = 10
siloAssistConfig.SATURATION_MAX = 6  -- max ±6° saturation tilt
siloAssistConfig.SATURATION_DECAY_RATE = 5  -- degrees per second decay back to autoTilt

-- Tilt control (default TILT_OFFSET, overridden per-vehicle)
siloAssistConfig.DEFAULT_TILT_OFFSET = 0
siloAssistConfig.TILT_STEP = 1
siloAssistConfig.TILT_MIN = -10
siloAssistConfig.TILT_MAX = 20
siloAssistConfig.SHIELD_TILT_DEG = 5
siloAssistConfig.SHIELD_TILT_PITCH_FACTOR = -1
siloAssistConfig.SHIELD_TILT_HYSTERESIS_DEG = 1

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
siloAssistConfig.PRE_ENTRY_DISTANCE = 10.0

-- Long-range entry/exit detection (10m ahead)
siloAssistConfig.LONG_RANGE_SAMPLE_DIST = 10.0
siloAssistConfig.LONG_RANGE_FILL_THRESHOLD = 0.05
siloAssistConfig.EXIT_RAMP_DIST = 10.0

-- Shovel/dump mode
siloAssistConfig.DUMP_HEIGHT_OFFSET = 1.5
siloAssistConfig.DUMP_POSITION_PCT = 0.95

-- Stuck detection: speed < 1 km/h for 2 seconds in push direction → stuck
siloAssistConfig.STUCK_SPEED_THRESHOLD = 1.0
siloAssistConfig.STUCK_TIME_THRESHOLD = 2.0

-- Topography map (Phase 1+: persistent fill-height grid over silo)
siloAssistConfig.TOPO_MAP_CELL_SIZE      = 1.0    -- m, grid resolution
siloAssistConfig.TOPO_MAP_COARSE_STEP   = 5.0    -- m, initial coarse scan step
siloAssistConfig.TOPO_MAP_EMA           = 0.3    -- weight of new sample (0..1)
siloAssistConfig.TOPO_MAP_MIN_SAMPLES   = 3      -- min samples before cell contributes
siloAssistConfig.TOPO_MAP_CORRECTION_GAIN = 0.0  -- start OFF, raise to test map influence
siloAssistConfig.TOPO_MAP_CORRECTION_MAX = 0.7   -- max gain (cap)
siloAssistConfig.TOPO_MAP_RAMP_DAMPING  = 0.3    -- gain multiplier in ramp zone (legacy ramp dominates there)
siloAssistConfig.TOPO_MAP_DONE_TOLERANCE = 0.05  -- variance threshold for "eben" (m)
siloAssistConfig.TOPO_MAP_DONE_HOLD_SEC = 3.0    -- seconds variance must hold for "eben"

-- Anti-bury / anti-dig protection (Block D)
siloAssistConfig.TOPO_MAX_CORRECTION = 0.30     -- TopoMap darf Legacy-Ziel max um 30cm verschieben
siloAssistConfig.BURY_VY_THRESHOLD = -0.3       -- m/s, Schild-Abwärts-Geschwindigkeit ab der prophylaktisch angehoben wird
siloAssistConfig.BURY_VY_LIFT = 0.05            -- m, Anhebung bei vy-Schutz
siloAssistConfig.BURY_VY_RELEASE_MARGIN = 0.05  -- m, Schild muss so viel ueber Ziel sein bevor forceTilt aufgehoben wird
siloAssistConfig.BURY_VY_MIN_DURATION_MS = 500  -- ms, Mindestdauer fuer forceTilt bevor Release erlaubt
siloAssistConfig.PITCH_NO_LOWER_DEG = -8.0      -- Fahrzeug-Pitch unter dem keine weitere Absenkung erfolgt
siloAssistConfig.BLADE_MIN_GROUND_DIST = 0.05   -- m, unter diesem Schild-Bodenabstand kein Absenken
siloAssistConfig.LOWER_RATE_LIMIT_FACTOR = 0.5  -- Absenken max mit halbem ALPHA_STEP (Rate-Limit)
siloAssistConfig.DYNAMIC_DEADBAND_VAR = 0.1      -- Varianz ab der Deadband verdoppelt wird

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

function siloAssistConfig.adjustFollow(delta)
    local currentFollow = siloAssistVehicleState.getFollowFactor()
    local newFollow = math.clamp(
        currentFollow + delta,
        siloAssistConfig.FOLLOW_MIN,
        siloAssistConfig.FOLLOW_MAX)
    siloAssistVehicleState.setFollowFactor(math.floor(newFollow * 10 + 0.5) / 10)
    return siloAssistVehicleState.getFollowFactor()
end

function siloAssistConfig.adjustTilt(delta)
    local currentTilt = siloAssistVehicleState.getTiltOffset()
    local newTilt = math.clamp(
        currentTilt + delta,
        siloAssistConfig.TILT_MIN,
        siloAssistConfig.TILT_MAX)
    siloAssistVehicleState.setTiltOffset(newTilt)
    return newTilt
end

function siloAssistConfig.adjustLookahead(delta)
    local currentLookahead = siloAssistVehicleState.getLookaheadTime()
    local newLookahead = math.clamp(
        currentLookahead + delta,
        siloAssistConfig.LOOKAHEAD_MIN,
        siloAssistConfig.LOOKAHEAD_MAX)
    siloAssistVehicleState.setLookaheadTime(math.floor(newLookahead * 4 + 0.5) / 4)
    return siloAssistVehicleState.getLookaheadTime()
end

function siloAssistConfig.adjustTopoGain(delta)
    local currentGain = siloAssistVehicleState.getTopoGain()
    local newGain = math.clamp(
        currentGain + delta,
        0,
        siloAssistConfig.TOPO_MAP_CORRECTION_MAX)
    siloAssistVehicleState.setTopoGain(math.floor(newGain * 10 + 0.5) / 10)
    return siloAssistVehicleState.getTopoGain()
end