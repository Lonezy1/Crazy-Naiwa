extends Node

const SETTINGS_PATH := "user://crazy_naiwa.cfg"
const SECTION := "pet"

var settings_path := SETTINGS_PATH
var always_on_top := true
var antics_enabled := true
var sound_enabled := true
var sfx_volume := 0.5
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
	if has_window_position:
		config.set_value(SECTION, "window_position", window_position)
	config.save(settings_path)
