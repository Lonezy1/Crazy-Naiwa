extends SceneTree

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const FrogVisual = preload("res://scripts/entities/FrogVisual.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetSettingsStore = preload("res://scripts/core/PetSettings.gd")
const PetSwarm = preload("res://scripts/entities/PetSwarm.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_settings()
	_test_desktop_bounds()
	_test_behavior()
	await _test_frog_hit_region()
	await _test_swarm()
	if failures == 0:
		print("All Crazy Naiwa tests passed.")
		quit(0)
	else:
		push_error("%d Crazy Naiwa test(s) failed." % failures)
		quit(1)

func _test_settings() -> void:
	var path := "user://crazy_naiwa_test.cfg"
	var saved := PetSettingsStore.new()
	saved.settings_path = path
	saved.always_on_top = false
	saved.antics_enabled = false
	saved.window_position = Vector2i(120, 240)
	saved.has_window_position = true
	saved.save_settings()

	var loaded := PetSettingsStore.new()
	loaded.settings_path = path
	loaded.load_settings()
	_expect(not loaded.always_on_top, "settings preserve always_on_top")
	_expect(not loaded.antics_enabled, "settings preserve antics_enabled")
	_expect(loaded.has_window_position, "settings preserve position presence")
	_expect(loaded.window_position == Vector2i(120, 240), "settings preserve window position")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	saved.free()
	loaded.free()

func _test_desktop_bounds() -> void:
	var work_area := Rect2i(100, 50, 400, 300)
	var window_size := Vector2i(300, 200)
	_expect(DesktopBounds.max_window_position(work_area, window_size) == Vector2i(200, 150), "bounds maximum position")
	_expect(DesktopBounds.clamp_position(Vector2(500, -20), work_area, window_size) == Vector2(200, 50), "bounds clamp")
	var result := DesktopBounds.advance_bounce(
		Vector2(190, 140), Vector2(100, 80), 1.0, work_area, window_size
	)
	_expect(result.position == Vector2(200, 150), "bounce clamps at corner")
	_expect(result.hit_x and result.hit_y and result.corner_hit, "bounce reports corner collision")
	_expect(result.velocity.x < 0.0 and result.velocity.y < 0.0, "bounce reverses both axes")

func _test_behavior() -> void:
	var work_area := Rect2i(0, 0, 800, 600)
	var window_size := Vector2i(320, 320)
	var behavior := PetBehavior.new()
	behavior.initialize(Vector2(100, 100))
	behavior.start_slither(work_area, window_size)
	_expect(behavior.mode == PetBehavior.Mode.SLITHER, "slither mode starts")
	_expect(behavior.window_position.y == 280.0, "slither moves to the bottom edge")
	behavior.start_float()
	_expect(behavior.mode == PetBehavior.Mode.FLOAT, "float mode starts")
	behavior.begin_drag(Vector2(100, 100))
	var fall_result := behavior.poke(work_area, window_size)
	_expect(fall_result.heavy_fall, "poking while floating causes heavy fall")
	_expect(behavior.mode == PetBehavior.Mode.FALL, "heavy fall enters fall mode")

	behavior.set_enabled(true)
	for _hit in range(9):
		var poke_result := behavior.poke(work_area, window_size)
		_expect(not poke_result.burst, "first nine pokes do not burst")
	_expect(behavior.inflation_hits == 9, "poke counter reaches nine")
	_expect(is_equal_approx(behavior.inflation_scale, pow(1.2, 9)), "pokes use the expected inflation multiplier")
	var burst_result := behavior.poke(work_area, window_size)
	_expect(burst_result.burst, "tenth poke bursts")
	_expect(behavior.inflation_hits == 0, "burst resets poke counter")
	_expect(behavior.mode == PetBehavior.Mode.LAUNCH, "burst launches the frog")

	behavior.begin_drag(Vector2(100, 100))
	behavior.move_drag(Vector2(140, 110), Vector2(140, 110))
	behavior.end_drag(work_area, window_size)
	_expect(behavior.mode == PetBehavior.Mode.LAUNCH, "drag release launches")
	_expect(behavior.velocity.x < 0.0, "drag launches opposite to pull")

	behavior.tongue_seconds = 1.0
	behavior.wake_up()
	_expect(behavior.tongue_seconds > 0.0, "pointer wake does not dismiss the tongue")
	_expect(behavior.add_tongue_wiggle(300.0), "tongue releases after enough movement")
	_expect(behavior.tongue_seconds == 0.0, "released tongue is dismissed")

	behavior.advance(612.0, work_area, window_size)
	_expect(behavior.pixelation_amount == 1.0, "idle state reaches full pixelation")
	_expect(behavior.record_activity(), "activity detects pixelated state")
	_expect(behavior.pixelation_amount == 0.0, "activity resets pixelation")

func _test_frog_hit_region() -> void:
	var frog := FrogVisual.new()
	root.add_child(frog)
	await process_frame
	frog.position = Vector2(160, 172)
	_expect(frog.is_point_on_pet(Vector2(160, 172)), "frog center is clickable")
	_expect(not frog.is_point_on_pet(Vector2(0, 0)), "transparent area is not clickable")
	_expect(frog.get_mouse_region().size() >= 12, "mouse passthrough region has a polygon")
	frog.inflation_scale = 1.8
	frog.scale = Vector2(1.8, 1.8)
	_expect(frog.is_point_on_pet(Vector2(260, 172)), "inflated frog hit region scales with it")
	_expect(not frog.is_point_on_pet(Vector2(0, 0)), "inflation does not capture the window corners")
	frog.queue_free()
	await process_frame

func _test_swarm() -> void:
	var swarm := PetSwarm.new()
	root.add_child(swarm)
	await process_frame
	_expect(swarm.spawn() == 50, "swarm spawns fifty clones")
	_expect(swarm.visible, "swarm reveals its play area")
	swarm.kick_near(Vector2(160, 100), Vector2(0, -20))
	swarm.remaining_seconds = 0.001
	await process_frame
	_expect(swarm.get_clone_count() == 0, "swarm automatically clears after its timer")
	_expect(not swarm.visible, "automatic cleanup hides the swarm play area")
	swarm.spawn()
	swarm.clear()
	_expect(swarm.get_clone_count() == 0, "swarm clears all clones")
	_expect(not swarm.visible, "cleared swarm hides its play area")
	swarm.queue_free()
	await process_frame

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Test failed: " + label)
