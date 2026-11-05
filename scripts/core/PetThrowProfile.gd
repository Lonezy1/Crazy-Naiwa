extends RefCounted

enum Style { STANDARD, BOUNCY, MADNESS }
enum Duration { CONTINUOUS = 0, TEN_SECONDS = 10, THIRTY_SECONDS = 30 }

const DEFAULT_STYLE := Style.STANDARD
const DEFAULT_DURATION := Duration.TEN_SECONDS
const MAX_SPEED := 6000.0

const STRENGTH_OPTIONS := [0.8, 1.0, 1.25, 1.5, 1.8, 2.0, 2.5, 4.0, 6.0]
const DAMPING_OPTIONS := [0.0, 0.1, 0.2, 0.5, 1.0, 1.5, 3.0, 4.5, 8.0]
const GRAVITY_SCALE_OPTIONS := [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
const BOUNCE_OPTIONS := [0.0, 0.35, 0.6, 0.82, 0.95, 1.0]
const DURATION_OPTIONS := [Duration.CONTINUOUS, Duration.TEN_SECONDS, Duration.THIRTY_SECONDS]

const PRESETS := {
	Style.STANDARD: {
		"strength": 1.5,
		"damping": 4.5,
		"gravity_scale": 1.0,
		"bounce": 1.0,
		"floor_bounce": 0.48,
		"duration_seconds": 5,
	},
	Style.BOUNCY: {
		"strength": 2.5,
		"damping": 0.5,
		"gravity_scale": 0.75,
		"bounce": 0.95,
		"floor_bounce": 1.0,
		"duration_seconds": 30,
	},
	Style.MADNESS: {
		"strength": 6.0,
		"damping": 0.0,
		"gravity_scale": 0.5,
		"bounce": 1.0,
		"floor_bounce": 1.0,
		"duration_seconds": 10,
	},
}

static func get_preset(style: int) -> Dictionary:
	return PRESETS.get(style, PRESETS[Style.STANDARD]).duplicate()

static func is_valid_duration(seconds: int) -> bool:
	return seconds in DURATION_OPTIONS
