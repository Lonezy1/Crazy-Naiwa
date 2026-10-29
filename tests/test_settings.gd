extends SceneTree

const PetSettingsStore = preload("res://scripts/PetSettings.gd")
const FrogVisual = preload("res://scripts/FrogVisual.gd")

func _init() -> void:
	var path := "user://crazy_naiwa_test.cfg"
	var saved := PetSettingsStore.new()
	saved.settings_path = path
	saved.always_on_top = false
	saved.window_position = Vector2i(120, 240)
	saved.has_window_position = true
	saved.save_settings()

	var loaded := PetSettingsStore.new()
	loaded.settings_path = path
	loaded.load_settings()
	assert(loaded.always_on_top == false)
	assert(loaded.has_window_position)
	assert(loaded.window_position == Vector2i(120, 240))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	saved.free()
	loaded.free()
	_test_pet_input_state()
	print("All Crazy Naiwa tests passed.")
	quit()

func _test_pet_input_state() -> void:
	var frog := FrogVisual.new()
	frog.position = Vector2(160, 172)
	assert(frog.is_point_on_pet(Vector2(160, 172)))
	assert(not frog.is_point_on_pet(Vector2(0, 0)))
	assert(frog.get_mouse_region().size() >= 12)
	frog.set_held(true)
	assert(frog.is_held)
	assert(frog.velocity.is_zero_approx())
	frog.set_held(false, Vector2(30, -55))
	assert(not frog.is_held)
	assert(frog.velocity == Vector2(30, -55))
	frog.free()
