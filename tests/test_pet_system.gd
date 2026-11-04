extends SceneTree

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const FrogVisual = preload("res://scripts/entities/FrogVisual.gd")
const FrogVisualScene = preload("res://scenes/FrogVisual.tscn")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetGesture = preload("res://scripts/input/PetGesture.gd")
const PetSettingsStore = preload("res://scripts/core/PetSettings.gd")
const PetSwarm = preload("res://scripts/entities/PetSwarm.gd")
const PetAudio = preload("res://scripts/audio/PetAudio.gd")
const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const PetCollisionWorld = preload("res://scripts/entities/PetCollisionWorld.gd")
const FrogTexture: Texture2D = preload("res://assets/character/stand.png")

var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_settings()
	_test_gestures()
	await _test_audio_and_menu()
	_test_desktop_bounds()
	_test_behavior()
	_test_collision_world()
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
	saved.sound_enabled = false
	saved.sfx_volume = 0.25
	saved.long_press_mode = PetSettingsStore.LongPressMode.TOSS
	saved.frog_size = 544
	saved.collisions_enabled = false
	saved.collision_strength = 1.15
	saved.frog_instances = [{"id": 4, "size": 256, "position": Vector2i(320, 480)}]
	saved.window_position = Vector2i(120, 240)
	saved.has_window_position = true
	saved.save_settings()

	var loaded := PetSettingsStore.new()
	loaded.settings_path = path
	loaded.load_settings()
	_expect(not loaded.always_on_top, "settings preserve always_on_top")
	_expect(not loaded.antics_enabled, "settings preserve antics_enabled")
	_expect(not loaded.sound_enabled, "settings preserve sound_enabled")
	_expect(is_equal_approx(loaded.sfx_volume, 0.25), "settings preserve sfx_volume")
	_expect(loaded.long_press_mode == PetSettingsStore.LongPressMode.TOSS, "settings preserve long press mode")
	_expect(loaded.frog_size == 544, "settings preserve primary frog size")
	_expect(not loaded.collisions_enabled, "settings preserve collision toggle")
	_expect(is_equal_approx(loaded.collision_strength, 1.15), "settings preserve collision strength")
	_expect(loaded.frog_instances.size() == 1, "settings preserve spawned frog records")
	if loaded.frog_instances.size() == 1:
		_expect(loaded.frog_instances[0]["position"] == Vector2i(320, 480), "settings preserve spawned frog positions")
	_expect(loaded.has_window_position, "settings preserve position presence")
	_expect(loaded.window_position == Vector2i(120, 240), "settings preserve window position")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	saved.free()
	loaded.free()

func _test_gestures() -> void:
	var gesture := PetGesture.new()
	gesture.begin(Vector2.ZERO, 0.0)
	var early_move := gesture.update(Vector2(40.0, 0.0), 0.2)
	_expect(not early_move["dragging"], "movement before the hold threshold does not drag")
	var held_move := gesture.update(Vector2(60.0, 0.0), 0.46)
	_expect(held_move["dragging"], "long press followed by movement starts a drag")
	_expect(held_move["started_drag"], "gesture reports the drag transition once")
	var release := gesture.end(Vector2(180.0, 0.0), 0.50)
	_expect(release["dragging"], "gesture release preserves drag classification")
	_expect(Vector2(release["release_velocity"]).length() >= PetBehavior.THROW_SPEED_THRESHOLD, "recent pointer samples detect a fast flick")
	_expect(gesture.phase == PetGesture.Phase.IDLE, "gesture resets after release")
	gesture.begin(Vector2.ZERO, 1.0)
	var short_press := gesture.end(Vector2(5.0, 0.0), 1.2)
	_expect(not short_press["dragging"], "short click remains a non-drag gesture")

func _test_audio_and_menu() -> void:
	for effect in PetAudio.EFFECT_SPECS.keys():
		var stream := PetAudio.create_effect_stream(effect)
		_expect(stream != null, "audio effect stream is created")
		if stream:
			_expect(stream.mix_rate == PetAudio.SAMPLE_RATE, "audio effect uses shared sample rate")
			_expect(stream.data.size() > 0, "audio effect contains PCM data")
	var audio := PetAudio.new()
	root.add_child(audio)
	await process_frame
	var settings := root.get_node("PetSettings")
	var original_sound_enabled: bool = settings.sound_enabled
	settings.sound_enabled = false
	audio.sync_settings()
	_expect(not audio.play_effect(PetAudio.Effect.POKE), "muted setting blocks sound playback")
	settings.sound_enabled = original_sound_enabled
	audio.sync_settings()
	audio.queue_free()
	var menu := PetContextMenu.new()
	root.add_child(menu)
	await process_frame
	_expect(not menu.visible, "context menu stays hidden until requested")
	menu.refresh_state(false, true, false, 0.25, 0, PetSettingsStore.LongPressMode.MOVE)
	_expect(menu.is_item_checked(menu.get_item_index(PetContextMenu.Command.TOGGLE_ANTICS)), "menu marks paused state")
	_expect(menu.is_item_checked(menu.get_item_index(PetContextMenu.Command.TOGGLE_ALWAYS_ON_TOP)), "menu marks always-on-top state")
	_expect(not menu.is_item_checked(menu.get_item_index(PetContextMenu.Command.TOGGLE_SOUND)), "menu marks muted state")
	_expect(menu.is_item_disabled(menu.get_item_index(PetContextMenu.Command.CLEAR_CLONES)), "menu disables empty clone cleanup")
	_expect(menu.volume_menu.is_item_checked(menu.volume_menu.get_item_index(PetContextMenu.VolumeOption.QUARTER)), "volume submenu reflects selected level")
	_expect(menu.long_press_menu.is_item_checked(menu.long_press_menu.get_item_index(PetContextMenu.LongPressOption.MOVE)), "long press menu marks move mode")
	menu.refresh_state(true, false, true, 0.5, 50, PetSettingsStore.LongPressMode.TOSS)
	_expect(not menu.is_item_checked(menu.get_item_index(PetContextMenu.Command.TOGGLE_ANTICS)), "menu reflects resumed state")
	_expect(not menu.is_item_disabled(menu.get_item_index(PetContextMenu.Command.CLEAR_CLONES)), "menu enables clone cleanup when clones exist")
	_expect(menu.volume_menu.is_item_checked(menu.volume_menu.get_item_index(PetContextMenu.VolumeOption.HALF)), "volume submenu updates selected level")
	_expect(menu.long_press_menu.is_item_checked(menu.long_press_menu.get_item_index(PetContextMenu.LongPressOption.TOSS)), "long press menu marks toss mode")
	var selected_mode := [-1]
	menu.long_press_mode_selected.connect(func(value: int) -> void: selected_mode[0] = value)
	menu._on_long_press_mode_id_pressed(PetContextMenu.LongPressOption.TOSS)
	_expect(selected_mode[0] == PetSettingsStore.LongPressMode.TOSS, "long press menu emits selected mode")
	menu.queue_free()
	var pet_menu := PetContextMenu.new()
	pet_menu.fleet_only = true
	root.add_child(pet_menu)
	await process_frame
	pet_menu.refresh_state(true, true, true, 0.5, 0, PetSettingsStore.LongPressMode.MOVE, 256, 2, true, 1.0, true)
	_expect(pet_menu.get_item_index(PetContextMenu.Command.SPAWN_SMALL_PET) >= 0, "small pet menu exposes spawn action")
	_expect(not pet_menu.is_item_disabled(pet_menu.get_item_index(PetContextMenu.Command.CLEAR_SMALL_PETS)), "small pet menu enables clear action when populated")
	_expect(pet_menu.size_menu.is_item_checked(pet_menu.size_menu.get_item_index(320)) == false, "size submenu tracks a non-preset baby size")
	var selected_size := [0]
	pet_menu.size_selected.connect(func(value: int) -> void: selected_size[0] = value)
	pet_menu._on_size_id_pressed(461)
	_expect(selected_size[0] == 461, "size submenu emits selected preset")
	pet_menu.queue_free()
	await process_frame

func _test_desktop_bounds() -> void:
	var work_area := Rect2i(100, 50, 400, 300)
	var window_size := Vector2i(300, 200)
	_expect(DesktopBounds.max_window_position(work_area, window_size) == Vector2i(200, 150), "bounds maximum position")
	_expect(DesktopBounds.clamp_position(Vector2(500, -20), work_area, window_size) == Vector2(200, 50), "bounds clamp")
	var content_rect := Rect2(97.0, 41.0, 157.0, 247.0)
	_expect(
		DesktopBounds.clamp_position_to_content(Vector2(0, 0), work_area, content_rect, 6.0)
			== Vector2(9, 15),
		"content clamp keeps the pet body inside the work area"
	)
	_expect(
		DesktopBounds.clamp_position_to_content(Vector2(999, 999), work_area, content_rect, 6.0)
			== Vector2(240, 56),
		"content clamp allows the transparent window to approach the edge"
	)
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
	behavior.move_drag(Vector2(900, 700), Vector2(140, 110))
	var move_result := behavior.end_drag(
		work_area, window_size, Vector2.ZERO, false
	)
	_expect(move_result["action"] == "move", "move mode keeps the pet at the dragged position")
	_expect(behavior.mode == PetBehavior.Mode.IDLE, "move mode holds the pet after release")
	_expect(behavior.window_position == Vector2(480, 280), "drag release clamps the pet to the work area")

	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.move_drag(Vector2(100, 100), Vector2(100, 100))
	var toss_fall_result := behavior.end_drag(
		work_area, window_size, Vector2(100.0, 0.0), true
	)
	_expect(toss_fall_result["action"] == "fall", "slow release enters gravity fall mode")
	_expect(behavior.mode == PetBehavior.Mode.FALL, "slow release uses fall state")
	var landed := false
	for _step in range(30):
		var events := behavior.advance(0.05, work_area, window_size)
		if events.landed:
			landed = true
			break
	_expect(landed, "falling release emits a landing event")
	_expect(behavior.impact_seconds > 0.0, "landing applies impact feedback")

	behavior.initialize(Vector2(470, 100))
	behavior.begin_drag(Vector2.ZERO)
	var throw_result := behavior.end_drag(
		work_area, window_size, Vector2(1000.0, 0.0), true
	)
	_expect(throw_result["action"] == "throw", "fast release enters throw mode")
	_expect(behavior.mode == PetBehavior.Mode.LAUNCH, "fast release uses launch state")
	_expect(is_equal_approx(behavior.velocity.x, 950.0), "throw velocity follows flick direction")
	behavior.advance(0.05, work_area, window_size)
	_expect(behavior.window_position.x == 480.0 and behavior.velocity.x < 0.0, "throw rebounds from the screen edge")

	behavior.set_enabled(false)
	behavior.initialize(Vector2(100, 200))
	behavior.start_float()
	var reached_fall := false
	for _step in range(10):
		behavior.advance(0.1, work_area, window_size)
		if behavior.mode == PetBehavior.Mode.FALL:
			reached_fall = true
			break
	_expect(reached_fall, "manual top fall advances while antics are paused")
	_expect(behavior.mode == PetBehavior.Mode.FALL, "manual top fall reaches the work area top before falling")
	_expect(behavior.window_position.y == float(work_area.position.y), "manual top fall starts from the screen work area edge")
	landed = false
	for _step in range(30):
		var events := behavior.advance(0.05, work_area, window_size)
		if events.landed:
			landed = true
			break
	_expect(landed, "manual top fall reaches the bottom while antics are paused")
	_expect(behavior.mode == PetBehavior.Mode.IDLE, "manual top fall returns to paused state after landing")

	behavior.initialize(Vector2(470, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.end_drag(work_area, window_size, Vector2(1000.0, 0.0), true)
	behavior.advance(0.05, work_area, window_size)
	_expect(behavior.window_position.x == 480.0 and behavior.velocity.x < 0.0, "manual throw still rebounds while antics are paused")

func _test_collision_world() -> void:
	var area := Rect2i(0, 0, 1000, 1000)
	var edge_world := PetCollisionWorld.new()
	edge_world.add_body(1, 100, Vector2(840, 200), area)
	edge_world.get_body(1)["velocity"] = Vector2(1000, 0)
	for _step in range(20):
		edge_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	_expect(edge_world.get_body(1)["position"].x <= 900.0, "collision body stays inside screen bounds")
	_expect(edge_world.get_body(1)["velocity"].x < 0.0, "collision body reflects from screen edge")

	var world := PetCollisionWorld.new()
	world.add_body(0, 100, Vector2(100, 100), area)
	world.add_body(1, 100, Vector2(220, 100), area)
	world.add_body(2, 100, Vector2(340, 100), area)
	world.begin_drag(0, Vector2(150, 150))
	world.move_drag(0, Vector2(270, 150))
	for _step in range(24):
		world.advance(PetCollisionWorld.FIXED_STEP, [area])
	_expect(Vector2(world.get_body(1)["velocity"]).x > 0.0, "dragged frog transfers momentum to first target")
	_expect(Vector2(world.get_body(2)["velocity"]).x > 0.0, "first target transfers momentum in a chain collision")
	var dragged_position: Vector2 = world.get_body(0)["position"]
	world.release_drag(0)
	_expect(world.get_body(0)["position"] == dragged_position, "released frog remains at its current position")
	_expect(Vector2(world.get_body(0)["velocity"]).is_zero_approx(), "released frog does not retain drag velocity")

	var sweep_world := PetCollisionWorld.new()
	sweep_world.add_body(0, 48, Vector2(100, 300), area)
	sweep_world.add_body(1, 48, Vector2(300, 300), area)
	sweep_world.begin_drag(0, Vector2(124, 324))
	var sweep_collisions := sweep_world.finish_drag(0, Vector2(524, 324), [area])
	_expect(sweep_collisions.has(1), "release path catches a fast drag collision")
	_expect(Vector2(sweep_world.get_body(1)["velocity"]).x > 0.0, "fast drag transfers momentum before release")
	sweep_world.release_drag(0)
	_expect(
		Vector2(sweep_world.get_body(0)["position"]).distance_to(Vector2(500, 300)) <= 0.5,
		"fast drag finishes at the grab-offset-adjusted release position"
	)

func _test_frog_hit_region() -> void:
	_expect(FrogTexture.get_width() == 406 and FrogTexture.get_height() == 615, "character texture imports")
	var frog := FrogVisualScene.instantiate() as FrogVisual
	root.add_child(frog)
	await process_frame
	var sprite := frog.get_node_or_null("CharacterImage") as Sprite2D
	_expect(sprite != null, "frog creates a character sprite")
	if sprite:
		_expect(sprite.texture == FrogTexture, "sprite uses the project character texture")
		_expect(sprite.material == null, "character sprite uses its texture without a screen sampler shader")
		var grabbed_state := PetBehavior.new()
		grabbed_state.mode = PetBehavior.Mode.DRAG
		frog.apply_behavior(grabbed_state)
		_expect(sprite.texture == FrogTexture, "missing grab artwork falls back to the standing sprite")
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
