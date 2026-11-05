extends Node

const SETTINGS_PATH := "user://crazy_naiwa.cfg"
const SECTION := "pet"
const THROW_STRENGTH_OPTIONS := [0.8, 1.0, 1.25, 1.5, 1.8]
const DEFAULT_THROW_STRENGTH := 1.5
const THROW_DAMPING_OPTIONS := [1.5, 3.0, 4.5, 6.0, 8.0]
const DEFAULT_THROW_DAMPING := 4.5
const THROW_GRAVITY_SCALE_OPTIONS := [0.5, 0.75, 1.0, 1.25, 1.5]
const DEFAULT_THROW_GRAVITY_SCALE := 1.0
const THROW_BOUNCE_OPTIONS := [0.0, 0.35, 0.6, 0.82, 1.0]
const DEFAULT_THROW_BOUNCE := 1.0

enum LongPressMode { MOVE, TOSS }
enum ThrowTuning { DAMPING, GRAVITY_SCALE, BOUNCE }

var settings_path := SETTINGS_PATH
var always_on_top := true
var antics_enabled := true
var sound_enabled := true
var sfx_volume := 0.5
var long_press_mode := LongPressMode.MOVE
var throw_strength := DEFAULT_THROW_STRENGTH
var throw_damping := DEFAULT_THROW_DAMPING
var throw_gravity_scale := DEFAULT_THROW_GRAVITY_SCALE
var throw_bounce := DEFAULT_THROW_BOUNCE
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
	throw_strength = clampf(
		float(config.get_value(SECTION, "throw_strength", throw_strength)),
		THROW_STRENGTH_OPTIONS[0],
		THROW_STRENGTH_OPTIONS[-1]
	)
	throw_damping = _read_option(
		config.get_value(SECTION, "throw_damping", throw_damping),
		THROW_DAMPING_OPTIONS,
		DEFAULT_THROW_DAMPING
	)
	throw_gravity_scale = _read_option(
		config.get_value(SECTION, "throw_gravity_scale", throw_gravity_scale),
		THROW_GRAVITY_SCALE_OPTIONS,
		DEFAULT_THROW_GRAVITY_SCALE
	)
	throw_bounce = _read_option(
		config.get_value(SECTION, "throw_bounce", throw_bounce),
		THROW_BOUNCE_OPTIONS,
		DEFAULT_THROW_BOUNCE
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

func _read_option(value: Variant, options: Array, fallback: float) -> float:
	var candidate := clampf(float(value), float(options[0]), float(options[-1]))
	var nearest := fallback
	var nearest_distance := INF
	for option in options:
		var distance := absf(float(option) - candidate)
		if distance < nearest_distance:
			nearest = float(option)
			nearest_distance = distance
	return nearest
