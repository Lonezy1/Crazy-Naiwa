extends Node

const SETTINGS_PATH := "user://crazy_naiwa.cfg"
const SECTION := "pet"

enum LongPressMode { MOVE, TOSS }

var settings_path := SETTINGS_PATH
var always_on_top := true
var antics_enabled := true
var sound_enabled := true
var sfx_volume := 0.5
var long_press_mode := LongPressMode.MOVE
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
	config.set_value(SECTION, "frog_size", frog_size)
	config.set_value(SECTION, "collisions_enabled", collisions_enabled)
	config.set_value(SECTION, "collision_strength", collision_strength)
	config.set_value(SECTION, "frog_instances", frog_instances)
	if has_window_position:
		config.set_value(SECTION, "window_position", window_position)
	config.save(settings_path)
