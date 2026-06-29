siloAssistConfig = {}

siloAssistConfig.VERSION = "0.4.0"

-- Debug
siloAssistConfig.DEBUG = false
siloAssistConfig.DEBUG_SHOW_HEIGHT = false

-- Silo mode (default, overridden per-vehicle)
siloAssistConfig.DEFAULT_SILO_MODE = "push"
siloAssistConfig.MODES = {
    { key = "push",   label = "SA_MODE_PUSH" },
    { key = "smooth", label = "SA_MODE_SMOOTH" },
    { key = "wedge",  label = "SA_MODE_WEDGE" },
}

-- Drive-through ramp lengths in meters (converted to progress % by silo length)
siloAssistConfig.ENTRY_RAMP_METERS = 12.0

-- Exit detection: sensor distance in meters ahead of blade.
-- When this sensor detects no fill material, exit ramp starts.
siloAssistConfig.EXIT_DETECT_DISTANCE = 10.0
siloAssistConfig.EXIT_DETECT_FILL_THRESHOLD = 0.05  -- minimum fill height to count as "in silo"

-- Silo end sensor: checks if a point ahead is still inside the silo area.
-- Used for wedge mode to detect the silo exit (walls), not fill level.
siloAssistConfig.SILO_END_SENSOR_DIST = 5.0

-- Exit ramp: stepped height offset + tilt increase.
-- 3 steps: at 0m (+10cm, 10° tilt), 2m (+20cm, 20° tilt), 4m (+30cm, 30° tilt).
-- Normal height controller runs throughout — only offset is added.
-- Wedge mode uses base tilt (5°) instead of stepped tilt.
siloAssistConfig.EXIT_RAMP_LENGTH = 6.0
siloAssistConfig.EXIT_RAMP_STEPS = {
    { dist = 0, heightAdd = 0.10, tiltDeg = 10 },
    { dist = 2, heightAdd = 0.20, tiltDeg = 20 },
    { dist = 4, heightAdd = 0.30, tiltDeg = 30 },
}

-- Minimum absolute height above fill (always at least 20cm above fill)
siloAssistConfig.MIN_HEIGHT_ABOVE_FILL = 0.20

-- Auto-offset: 5cm per meter of fill height (compensates for vehicle sinking)
siloAssistConfig.AUTO_FILL_OFFSET_FACTOR = 0.05

-- Height control (default HEIGHT_OFFSET, overridden per-vehicle)
siloAssistConfig.DEFAULT_HEIGHT_OFFSET = 0.0
siloAssistConfig.OFFSET_MIN = -0.5
siloAssistConfig.OFFSET_MAX = 1.0
siloAssistConfig.OFFSET_STEP = 0.05
siloAssistConfig.ALPHA_STEP = 0.04
siloAssistConfig.HEIGHT_THRESHOLD = 0.04
siloAssistConfig.HEIGHT_DEADBAND = 0.05

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
siloAssistConfig.SHIELD_TILT_DEG = 10
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

-- Wedge mode (isolated from push/smooth)
siloAssistConfig.WEDGE_MIN_END_HEIGHT = 0.1
siloAssistConfig.WEDGE_MAX_HEIGHT = 4.0
siloAssistConfig.WEDGE_INCREMENT = 0.02
siloAssistConfig.WEDGE_TILT_DEG = 5
siloAssistConfig.WEDGE_END_EXTRA = 0.80  -- zusaetzliche Hoehe am Keil-Ende (m)

-- Pre-positioning
siloAssistConfig.PRE_ENTRY_DISTANCE = 10.0

-- Long-range entry/exit detection (15m ahead)
siloAssistConfig.LONG_RANGE_SAMPLE_DIST = 15.0
siloAssistConfig.LONG_RANGE_FILL_THRESHOLD = 0.05

-- Silo sensor (16th sensor, 15m ahead of blade, center) — separate from longRange
siloAssistConfig.SILO_SENSOR_DIST = 15.0
siloAssistConfig.SILO_SENSOR_FILL_THRESHOLD = 0.05

-- Push mode: full silo scan resolution
siloAssistConfig.PUSH_SCAN_STEP_M = 0.5      -- longitudinal sample step (detailed scan)
siloAssistConfig.PUSH_SCAN_MIN_POINTS = 30    -- minimum points per longitudinal strip
siloAssistConfig.PUSH_SCAN_RAMP_EXCLUDE = true  -- exclude entry/exit ramp zones from average

-- Smooth mode: fixed offset above average of far sensors
siloAssistConfig.SMOOTH_HEIGHT_ADD = 0.10  -- +10cm above average

-- Shovel/dump mode
siloAssistConfig.DUMP_HEIGHT_OFFSET = 1.5
siloAssistConfig.DUMP_POSITION_PCT = 0.95

-- Compactor control (BunkerSiloCompacter): default off, enabled per-vehicle
siloAssistConfig.DEFAULT_COMPACTOR_ENABLED = false

-- Stuck detection: >= 2 wheels with slipRatio > 0.5 for 0.3s, speed < 3 km/h, push direction → stuck
siloAssistConfig.STUCK_TIME_THRESHOLD = 0.3
siloAssistConfig.STUCK_WHEELSLIP_RATIO = 0.5
siloAssistConfig.STUCK_MIN_WHEELS = 2
siloAssistConfig.STUCK_SPEED_THRESHOLD = 3.0
-- Stuck recovery: minimum time in RAISING state before returning to ACTIVE (ms)
siloAssistConfig.STUCK_RAISE_MIN_MS = 1000
-- Stuck recovery: height offset added to target when stuck (meters)
siloAssistConfig.STUCK_HEIGHT_ADD = 0.20
-- Stuck release hysteresis: wheelSlip must be clear for this long before unstuck (ms)
siloAssistConfig.STUCK_RELEASE_MS = 500

-- Anti-bury / anti-dig protection
siloAssistConfig.BURY_VY_THRESHOLD = -0.3       -- m/s, blade downward velocity threshold
siloAssistConfig.BURY_VY_LIFT = 0.05            -- m, lift amount on vy guard
siloAssistConfig.BURY_VY_RELEASE_MARGIN = 0.05   -- m, blade must be this much above target before release
siloAssistConfig.BURY_VY_MIN_DURATION_MS = 500   -- ms, minimum duration for forceTilt before release
siloAssistConfig.BLADE_MIN_GROUND_DIST = 0.05   -- m, below this blade-ground distance, no lowering
siloAssistConfig.LOWER_RATE_LIMIT_FACTOR = 0.5   -- lowering max at half ALPHA_STEP (rate limit)
siloAssistConfig.DYNAMIC_DEADBAND_VAR = 0.1      -- variance threshold for doubling deadband

-- Topography map (used by TopoMap module for coverage tracking)
siloAssistConfig.TOPO_MAP_CELL_SIZE      = 1.0    -- m, grid resolution
siloAssistConfig.TOPO_MAP_COARSE_STEP   = 5.0    -- m, initial coarse scan step
siloAssistConfig.TOPO_MAP_EMA           = 0.3    -- weight of new sample (0..1)
siloAssistConfig.TOPO_MAP_MIN_SAMPLES   = 3      -- min samples before cell contributes
siloAssistConfig.TOPO_MAP_DONE_TOLERANCE = 0.05  -- variance threshold for "eben" (m)
siloAssistConfig.TOPO_MAP_DONE_HOLD_SEC = 3.0    -- seconds variance must hold for "eben"

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

function siloAssistConfig.adjustTilt(delta)
    local currentTilt = siloAssistVehicleState.getTiltOffset()
    local newTilt = math.clamp(
        currentTilt + delta,
        siloAssistConfig.TILT_MIN,
        siloAssistConfig.TILT_MAX)
    siloAssistVehicleState.setTiltOffset(newTilt)
    return newTilt
end