extends Node

const PetThrowProfile = preload("res://scripts/core/PetThrowProfile.gd")

const SETTINGS_PATH := "user://crazy_naiwa.cfg"
const SECTION := "pet"

enum LongPressMode { MOVE, TOSS }
enum ThrowTuning { DAMPING, GRAVITY_SCALE, BOUNCE }

var settings_path := SETTINGS_PATH
var always_on_top := true
var antics_enabled := true
var sound_enabled := true
var sfx_volume := 0.5
var long_press_mode := LongPressMode.MOVE
var throw_style := PetThrowProfile.DEFAULT_STYLE
var throw_duration_seconds := PetThrowProfile.DEFAULT_DURATION
var throw_strength: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["strength"]
var throw_damping: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["damping"]
var throw_gravity_scale: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["gravity_scale"]
var throw_bounce: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["bounce"]
var frog_size := 320
var collisions_enabled := true
var collision_strength := 1.0
var frog_instances: Array[Dictionary] = []
var window_position := Vector2i.ZERO
var has_window_position := false

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	always_on_top = bool(config.get_value(SECTION, "always_on_top", always_on_top))
	antics_enabled = bool(config.get_value(SECTION, "antics_enabled", antics_enabled))
	sound_enabled = bool(config.get_value(SECTION, "sound_enabled", sound_enabled))
	sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	long_press_mode = clampi(int(config.get_value(SECTION, "long_press_mode", long_press_mode)), LongPressMode.MOVE, LongPressMode.TOSS)
	throw_style = clampi(
		int(config.get_value(SECTION, "throw_style", throw_style)),
		PetThrowProfile.Style.STANDARD,
		PetThrowProfile.Style.MADNESS
	)
	var stored_throw_duration := int(
		config.get_value(SECTION, "throw_duration_seconds", throw_duration_seconds)
	)
	throw_duration_seconds = (
		stored_throw_duration
		if PetThrowProfile.is_valid_duration(stored_throw_duration)
		else PetThrowProfile.DEFAULT_DURATION
	)
	throw_strength = _read_option(
		float(config.get_value(SECTION, "throw_strength", throw_strength)),
		PetThrowProfile.STRENGTH_OPTIONS,
		PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["strength"]
	)
	throw_damping = _read_option(
		config.get_value(SECTION, "throw_damping", throw_damping),
		PetThrowProfile.DAMPING_OPTIONS,
		PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["damping"]
	)
	throw_gravity_scale = _read_option(
		config.get_value(SECTION, "throw_gravity_scale", throw_gravity_scale),
		PetThrowProfile.GRAVITY_SCALE_OPTIONS,
		PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["gravity_scale"]
	)
	throw_bounce = _read_option(
		config.get_value(SECTION, "throw_bounce", throw_bounce),
		PetThrowProfile.BOUNCE_OPTIONS,
		PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["bounce"]
	)
	frog_size = clampi(int(config.get_value(SECTION, "frog_size", frog_size)), 48, 640)
	collisions_enabled = bool(config.get_value(SECTION, "collisions_enabled", collisions_enabled))
	collision_strength = clampf(float(config.get_value(SECTION, "collision_strength", collision_strength)), 0.5, 1.25)
	var stored_instances: Variant = config.get_value(SECTION, "frog_instances", [])
	frog_instances.clear()
	if stored_instances is Array:
		for item in stored_instances:
			if item is Dictionary:
				frog_instances.append(item)
	if config.has_section_key(SECTION, "window_position"):
		var stored_position: Variant = config.get_value(SECTION, "window_position")
		if stored_position is Vector2i:
			window_position = stored_position
			has_window_position = true

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "always_on_top", always_on_top)
	config.set_value(SECTION, "antics_enabled", antics_enabled)
	config.set_value(SECTION, "sound_enabled", sound_enabled)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "long_press_mode", long_press_mode)
	config.set_value(SECTION, "throw_style", throw_style)
	config.set_value(SECTION, "throw_duration_seconds", throw_duration_seconds)
	config.set_value(SECTION, "throw_strength", throw_strength)
	config.set_value(SECTION, "throw_damping", throw_damping)
	config.set_value(SECTION, "throw_gravity_scale", throw_gravity_scale)
	config.set_value(SECTION, "throw_bounce", throw_bounce)
	config.set_value(SECTION, "frog_size", frog_size)
	config.set_value(SECTION, "collisions_enabled", collisions_enabled)
	config.set_value(SECTION, "collision_strength", collision_strength)
	config.set_value(SECTION, "frog_instances", frog_instances)
	if has_window_position:
		config.set_value(SECTION, "window_position", window_position)
	config.save(settings_path)

func set_throw_style(style: int) -> void:
	throw_style = clampi(style, PetThrowProfile.Style.STANDARD, PetThrowProfile.Style.MADNESS)
	var preset := PetThrowProfile.get_preset(throw_style)
	throw_strength = float(preset["strength"])
	throw_damping = float(preset["damping"])
	throw_gravity_scale = float(preset["gravity_scale"])
	throw_bounce = float(preset["bounce"])

func set_throw_duration(seconds: int) -> void:
	if PetThrowProfile.is_valid_duration(seconds):
		throw_duration_seconds = seconds

func _read_option(value: Variant, options: Array, fallback: float) -> float:
	var nearest := fallback
	var nearest_distance := INF
	for option in options:
		var distance := absf(float(option) - float(value))
		if distance < nearest_distance:
			nearest = float(option)
			nearest_distance = distance
	return nearest
