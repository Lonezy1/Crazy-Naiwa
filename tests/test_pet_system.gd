extends SceneTree

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const FrogVisual = preload("res://scripts/entities/FrogVisual.gd")
const FrogVisualScene = preload("res://scenes/FrogVisual.tscn")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetImpact = preload("res://scripts/core/PetImpact.gd")
const PetGesture = preload("res://scripts/input/PetGesture.gd")
const PetSettingsStore = preload("res://scripts/core/PetSettings.gd")
const PetThrowProfile = preload("res://scripts/core/PetThrowProfile.gd")
const PetSwarm = preload("res://scripts/entities/PetSwarm.gd")
const PetAudio = preload("res://scripts/audio/PetAudio.gd")
const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const PetTheme = preload("res://scripts/ui/PetTheme.gd")
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
	saved.fall_on_slow_release = true
	saved.throw_style = PetThrowProfile.Style.MADNESS
	saved.throw_duration_seconds = PetThrowProfile.Duration.CONTINUOUS
	saved.throw_strength = 4.0
	saved.throw_damping = 8.0
	saved.throw_gravity_scale = 1.25
	saved.throw_bounce = 0.35
	saved.frog_size = 544
	saved.collisions_enabled = false
	saved.frog_instances = [{"id": 4, "size": 256, "position": Vector2i(320, 480)}]
	saved.window_position = Vector2i(120, 240)
	saved.has_window_position = true
	saved.save_settings()
	var saved_config := ConfigFile.new()
	saved_config.load(path)
	_expect(not saved_config.has_section_key("pet", "collision_strength"), "collision physics uses the throw profile without duplicate persistence")

	var loaded := PetSettingsStore.new()
	loaded.settings_path = path
	loaded.load_settings()
	_expect(not loaded.always_on_top, "settings preserve always_on_top")
	_expect(not loaded.antics_enabled, "settings preserve antics_enabled")
	_expect(not loaded.sound_enabled, "settings preserve sound_enabled")
	_expect(is_equal_approx(loaded.sfx_volume, 0.25), "settings preserve sfx_volume")
	_expect(loaded.long_press_mode == PetSettingsStore.LongPressMode.TOSS, "settings preserve long press mode")
	_expect(loaded.fall_on_slow_release, "settings preserve slow-release fall toggle")
	_expect(loaded.throw_style == PetThrowProfile.Style.MADNESS, "settings preserve throw style")
	_expect(loaded.throw_duration_seconds == PetThrowProfile.Duration.CONTINUOUS, "settings preserve continuous throw duration")
	_expect(is_equal_approx(loaded.throw_strength, 4.0), "settings preserve throw strength")
	_expect(is_equal_approx(loaded.throw_damping, 8.0), "settings preserve throw damping")
	_expect(is_equal_approx(loaded.throw_gravity_scale, 1.25), "settings preserve throw gravity scale")
	_expect(is_equal_approx(loaded.throw_bounce, 0.35), "settings preserve throw bounce")
	_expect(loaded.frog_size == 544, "settings preserve primary frog size")
	_expect(not loaded.collisions_enabled, "settings preserve collision toggle")
	_expect(loaded.frog_instances.size() == 1, "settings preserve spawned frog records")
	if loaded.frog_instances.size() == 1:
		_expect(loaded.frog_instances[0]["position"] == Vector2i(320, 480), "settings preserve spawned frog positions")
	_expect(loaded.has_window_position, "settings preserve position presence")
	_expect(loaded.window_position == Vector2i(120, 240), "settings preserve window position")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	saved.free()
	loaded.free()
	var preset_settings := PetSettingsStore.new()
	preset_settings.set_throw_style(PetThrowProfile.Style.BOUNCY)
	_expect(
		is_equal_approx(preset_settings.throw_strength, 2.5)
			and is_equal_approx(preset_settings.throw_damping, 0.5)
			and is_equal_approx(preset_settings.throw_gravity_scale, 0.75)
			and is_equal_approx(preset_settings.throw_bounce, 0.95),
		"selecting bouncy style applies its complete preset"
	)
	preset_settings.set_throw_duration(PetThrowProfile.Duration.THIRTY_SECONDS)
	_expect(preset_settings.throw_duration_seconds == 30, "settings accept a supported throw duration")
	preset_settings.set_throw_duration(7)
	_expect(preset_settings.throw_duration_seconds == 30, "settings ignore unsupported throw durations")
	preset_settings.free()

func _test_gestures() -> void:
	var gesture := PetGesture.new()
	gesture.begin(Vector2.ZERO, 0.0)
	var early_move := gesture.update(Vector2(40.0, 0.0), 0.005)
	_expect(not early_move["dragging"], "movement before the 0.01 second threshold does not drag")
	var held_move := gesture.advance(Vector2(40.0, 0.0), 0.02)
	_expect(held_move["dragging"], "held movement starts immediately at the 0.01 second threshold")
	_expect(held_move["started_drag"], "gesture reports the drag transition once")
	_expect(
		held_move["drag_origin_position"] == Vector2.ZERO,
		"drag retains the original grab anchor"
	)
	_expect(
		Vector2(held_move["position"]).x - Vector2(held_move["drag_origin_position"]).x == 40.0,
		"movement made during the hold is applied at drag start without waiting for another mouse move"
	)
	var release := gesture.end(Vector2(180.0, 0.0), 0.05)
	_expect(release["dragging"], "gesture release preserves drag classification")
	_expect(Vector2(release["release_velocity"]).length() >= PetBehavior.THROW_SPEED_THRESHOLD, "recent pointer samples detect a fast flick")
	_expect(gesture.phase == PetGesture.Phase.IDLE, "gesture resets after release")
	gesture.begin(Vector2.ZERO, 1.0)
	var short_press := gesture.end(Vector2(5.0, 0.0), 1.1)
	_expect(not short_press["dragging"], "short click remains a non-drag gesture")
	gesture.begin(Vector2.ZERO, 2.0)
	var stationary_hold := gesture.advance(Vector2.ZERO, 2.02)
	_expect(not stationary_hold["dragging"], "holding without pointer movement does not start a drag")
	var first_post_hold_move := gesture.update(Vector2(12.0, 0.0), 2.03)
	_expect(first_post_hold_move["started_drag"], "first movement after a stationary hold starts dragging")
	var accelerating_gesture := PetGesture.new()
	accelerating_gesture.begin(Vector2.ZERO, 3.0)
	accelerating_gesture.update(Vector2(20.0, 0.0), 3.02)
	accelerating_gesture.update(Vector2(60.0, 0.0), 3.04)
	var accelerating_release := accelerating_gesture.end(Vector2(150.0, 0.0), 3.06)
	_expect(
		Vector2(accelerating_release["release_acceleration"]).x > 0.0,
		"gesture release carries forward mouse acceleration"
	)
	var sampled_gesture := PetGesture.new()
	sampled_gesture.begin(Vector2.ZERO, 3.0)
	sampled_gesture.update(Vector2(100.0, 0.0), 3.02)
	sampled_gesture.advance(Vector2(100.0, 0.0), 3.03)
	var sampled_release := sampled_gesture.end(Vector2(100.0, 0.0), 3.04)
	_expect(
		Vector2(sampled_release["release_velocity"]).x >= 4900.0,
		"stationary pointer polls do not dilute the last flick speed"
	)
	var stale_gesture := PetGesture.new()
	stale_gesture.begin(Vector2.ZERO, 4.0)
	stale_gesture.update(Vector2(100.0, 0.0), 4.02)
	var stale_release := stale_gesture.end(Vector2(100.0, 0.0), 4.2)
	_expect(
		Vector2(stale_release["release_velocity"]).is_zero_approx(),
		"a pause after flicking does not preserve stale throw speed"
	)

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
	var preferences_menu: PopupMenu = menu.get_node("PreferencesMenu")
	var fleet_menu: PopupMenu = menu.get_node("FleetMenu")
	var throw_group: PopupMenu = menu.get_node("ThrowMenu")
	var hover_style := menu.theme.get_stylebox("hover", "PopupMenu") as StyleBoxFlat
	var throw_damping_row := throw_group.get_item_index(PetContextMenu.Command.THROW_DAMPING)
	_expect(
		preferences_menu.theme == menu.theme and fleet_menu.theme == menu.theme and throw_group.theme == menu.theme,
		"all folded menus share the context menu theme"
	)
	_expect(
		menu.theme.get_color("font_color", "PopupMenu") == PetTheme.INK
			and hover_style.bg_color == PetTheme.HOVER,
		"folded menus reuse the established text and hover colors"
	)
	_expect(preferences_menu.is_item_checked(preferences_menu.get_item_index(PetContextMenu.Command.TOGGLE_ANTICS)), "menu marks paused state")
	_expect(preferences_menu.is_item_checked(preferences_menu.get_item_index(PetContextMenu.Command.TOGGLE_ALWAYS_ON_TOP)), "menu marks always-on-top state")
	_expect(not preferences_menu.is_item_checked(preferences_menu.get_item_index(PetContextMenu.Command.TOGGLE_SOUND)), "menu marks muted state")
	_expect(fleet_menu.is_item_disabled(fleet_menu.get_item_index(PetContextMenu.Command.CLEAR_CLONES)), "menu disables empty clone cleanup")
	_expect(menu.get_item_count() <= 6, "main context menu folds detailed commands under four groups")
	_expect(menu.get_node_or_null("CollisionMenu") == null, "collision strength has no competing independent menu")
	_expect(menu.volume_menu.is_item_checked(menu.volume_menu.get_item_index(PetContextMenu.VolumeOption.QUARTER)), "volume submenu reflects selected level")
	_expect(menu.long_press_menu.is_item_checked(menu.long_press_menu.get_item_index(PetContextMenu.LongPressOption.MOVE)), "long press menu marks move mode")
	_expect(
		not throw_group.is_item_checked(throw_group.get_item_index(PetContextMenu.Command.FALL_ON_SLOW_RELEASE)),
		"slow-release fall menu reflects its disabled default"
	)
	_expect(
		throw_group.is_item_disabled(throw_group.get_item_index(PetContextMenu.Command.FALL_ON_SLOW_RELEASE)),
		"slow-release fall control is inactive in move mode"
	)
	_expect(
		menu.throw_strength_menu.is_item_checked(menu.throw_strength_menu.get_item_index(53)),
		"throw strength menu reflects the default setting"
	)
	menu.refresh_state(
		true, true, true, 0.5, 0, PetSettingsStore.LongPressMode.TOSS,
		320, 0, true, true, 4.0, 8.0, 1.25, 0.35,
		PetThrowProfile.Style.MADNESS, PetThrowProfile.Duration.THIRTY_SECONDS, true, true
	)
	_expect(
		throw_group.is_item_checked(throw_group.get_item_index(PetContextMenu.Command.FALL_ON_SLOW_RELEASE)),
		"slow-release fall menu reflects the enabled setting"
	)
	_expect(
		not throw_group.is_item_disabled(throw_group.get_item_index(PetContextMenu.Command.FALL_ON_SLOW_RELEASE)),
		"slow-release fall control is active in toss mode"
	)
	_expect(
		menu.throw_tuning_menus[PetSettingsStore.ThrowTuning.DAMPING]["menu"].is_item_checked(8),
		"throw damping menu reflects the selected value"
	)
	_expect(
		menu.throw_tuning_menus[PetSettingsStore.ThrowTuning.GRAVITY_SCALE]["menu"].is_item_checked(5),
		"throw gravity menu reflects the selected value"
	)
	_expect(
		menu.throw_tuning_menus[PetSettingsStore.ThrowTuning.BOUNCE]["menu"].is_item_checked(1),
		"throw bounce menu reflects the selected value"
	)
	_expect(
		menu.throw_style_menu.is_item_checked(PetThrowProfile.Style.MADNESS)
			and not throw_group.is_item_disabled(throw_group.get_item_index(PetContextMenu.Command.THROW_DURATION)),
		"madness style enables and reflects its duration option"
	)
	_expect(
		menu.throw_duration_menu.is_item_checked(
			menu.throw_duration_menu.get_item_index(PetThrowProfile.Duration.THIRTY_SECONDS)
		),
		"madness duration menu reflects the selected timeout"
	)
	var behavior_menu: PopupMenu = menu.get_node("BehaviorMenu")
	_expect(
		not behavior_menu.is_item_disabled(behavior_menu.get_item_index(PetContextMenu.Command.STOP_THROW)),
		"active madness mode enables the explicit stop command"
	)
	menu.refresh_state(true, false, true, 0.5, 50, PetSettingsStore.LongPressMode.TOSS)
	_expect(not preferences_menu.is_item_checked(preferences_menu.get_item_index(PetContextMenu.Command.TOGGLE_ANTICS)), "menu reflects resumed state")
	_expect(not fleet_menu.is_item_disabled(fleet_menu.get_item_index(PetContextMenu.Command.CLEAR_CLONES)), "menu enables clone cleanup when clones exist")
	_expect(menu.volume_menu.is_item_checked(menu.volume_menu.get_item_index(PetContextMenu.VolumeOption.HALF)), "volume submenu updates selected level")
	_expect(menu.long_press_menu.is_item_checked(menu.long_press_menu.get_item_index(PetContextMenu.LongPressOption.TOSS)), "long press menu marks toss mode")
	var selected_mode := [-1]
	menu.long_press_mode_selected.connect(func(value: int) -> void: selected_mode[0] = value)
	menu._on_long_press_mode_id_pressed(PetContextMenu.LongPressOption.TOSS)
	_expect(selected_mode[0] == PetSettingsStore.LongPressMode.TOSS, "long press menu emits selected mode")
	var selected_fall_toggle := [false]
	menu.fall_on_slow_release_selected.connect(func(value: bool) -> void: selected_fall_toggle[0] = value)
	menu._on_menu_id_pressed(PetContextMenu.Command.FALL_ON_SLOW_RELEASE)
	_expect(selected_fall_toggle[0], "slow-release fall menu emits its toggled value")
	var selected_throw_strength := [0.0]
	menu.throw_strength_selected.connect(func(value: float) -> void: selected_throw_strength[0] = value)
	menu._on_throw_strength_id_pressed(58)
	_expect(is_equal_approx(selected_throw_strength[0], 6.0), "throw strength menu emits selected multiplier")
	var selected_style := [-1]
	menu.throw_style_selected.connect(func(value: int) -> void: selected_style[0] = value)
	menu._on_throw_style_id_pressed(PetThrowProfile.Style.BOUNCY)
	_expect(selected_style[0] == PetThrowProfile.Style.BOUNCY, "throw style menu emits its selected preset")
	var selected_duration := [-1]
	menu.throw_duration_selected.connect(func(value: int) -> void: selected_duration[0] = value)
	menu._on_throw_duration_id_pressed(PetThrowProfile.Duration.CONTINUOUS)
	_expect(selected_duration[0] == PetThrowProfile.Duration.CONTINUOUS, "throw duration menu emits continuous mode")
	var selected_tuning := [-1, 0.0]
	menu.throw_tuning_selected.connect(func(tuning: int, value: float) -> void:
		selected_tuning[0] = tuning
		selected_tuning[1] = value
	)
	menu._on_throw_tuning_id_pressed(8, PetSettingsStore.ThrowTuning.DAMPING)
	_expect(
		selected_tuning[0] == PetSettingsStore.ThrowTuning.DAMPING and is_equal_approx(selected_tuning[1], 8.0),
		"throw tuning menu emits its parameter and selected value"
	)
	_expect(throw_group.get_item_count() == 8, "throw controls are grouped into one expandable submenu")
	_expect(throw_group.get_item_icon(throw_damping_row) == null, "detailed throw controls avoid redundant row icons")
	menu.queue_free()
	var pet_menu := PetContextMenu.new()
	pet_menu.fleet_only = true
	root.add_child(pet_menu)
	await process_frame
	pet_menu.refresh_state(true, true, true, 0.5, 0, PetSettingsStore.LongPressMode.MOVE, 256, 2, true, true)
	var current_pet_menu: PopupMenu = pet_menu.get_node("CurrentPetMenu")
	_expect(current_pet_menu.get_item_index(PetContextMenu.Command.SPAWN_SMALL_PET) >= 0, "small pet menu exposes spawn action")
	_expect(not current_pet_menu.is_item_disabled(current_pet_menu.get_item_index(PetContextMenu.Command.CLEAR_SMALL_PETS)), "small pet menu enables clear action when populated")
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
	_expect(result.impact_normal.x < 0.0 and result.impact_normal.y < 0.0, "corner collision reports a diagonal inward normal")
	_expect(is_equal_approx(result.impact_speed, Vector2(100.0, 80.0).length()), "edge impact reports pre-bounce speed")
	var edge_result := DesktopBounds.advance_bounce(
		Vector2(190, 80), Vector2(200, 0), 0.1, work_area, window_size
	)
	_expect(edge_result.hit_x and edge_result.impact_normal == Vector2.LEFT, "side collision reports its horizontal impact direction")
	var left_result := DesktopBounds.advance_bounce(
		Vector2(110, 80), Vector2(-200, 0), 0.1, work_area, window_size
	)
	_expect(left_result.hit_x and left_result.impact_normal == Vector2.RIGHT, "left-side collision reports its horizontal impact direction")
	var top_result := DesktopBounds.advance_bounce(
		Vector2(120, 51), Vector2(0, -20), 0.1, work_area, window_size
	)
	_expect(top_result.hit_y and top_result.impact_normal == Vector2.DOWN, "top collision reports its vertical impact direction")
	var bottom_result := DesktopBounds.advance_bounce(
		Vector2(120, 140), Vector2(0, 100), 0.2, work_area, window_size
	)
	_expect(bottom_result.hit_y and bottom_result.impact_normal == Vector2.UP, "bottom collision reports its vertical impact direction")
	var edge_behavior := PetBehavior.new()
	edge_behavior.initialize(Vector2(490, 100))
	edge_behavior.velocity = Vector2(1000, 0)
	var behavior_edge_events := edge_behavior.advance(0.05, Rect2i(0, 0, 800, 600), window_size)
	var behavior_edge_impact: PetImpact = behavior_edge_events.impacts[0] if not behavior_edge_events.impacts.is_empty() else null
	_expect(
		behavior_edge_impact != null and behavior_edge_impact.body_id == 0
			and behavior_edge_impact.normal == Vector2.LEFT,
		"primary behavior emits the shared directional impact event"
	)

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
	behavior.tap()
	_expect(behavior.mode == PetBehavior.Mode.FALL, "heavy fall enters fall mode")

	behavior.set_enabled(true)
	var resting_mode := behavior.mode
	for _tap in range(12):
		behavior.tap()
	_expect(behavior.mode == resting_mode, "repeated taps no longer inflate or launch the frog")

	behavior.begin_drag(Vector2(100, 100))
	behavior.move_drag(Vector2(900, 700), Vector2(140, 110))
	var move_result := behavior.end_drag(
		work_area, window_size, Vector2.ZERO, Vector2.ZERO, false
	)
	_expect(move_result["action"] == "move", "move mode keeps the pet at the dragged position")
	_expect(behavior.mode == PetBehavior.Mode.IDLE, "move mode holds the pet after release")
	_expect(behavior.window_position == Vector2(480, 280), "drag release clamps the pet to the work area")

	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.move_drag(Vector2(200, 160), Vector2(100, 100))
	var placed_result := behavior.end_drag(
		work_area, window_size, Vector2.ZERO, Vector2.ZERO, true
	)
	_expect(placed_result["action"] == "place", "slow release places the pet when falling is disabled")
	_expect(behavior.mode == PetBehavior.Mode.IDLE, "disabled slow-release fall leaves the pet at rest")
	_expect(behavior.window_position == Vector2(200, 160), "slow release keeps the selected placement")
	var placement_position := behavior.window_position
	behavior.advance(1.0, work_area, window_size)
	_expect(behavior.window_position == placement_position, "placed pet does not receive automatic gravity")
	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.move_drag(Vector2(163, 100), Vector2(PetBehavior.THROW_DISTANCE_THRESHOLD - 1.0, 0.0))
	var short_flick := behavior.end_drag(
		work_area,
		window_size,
		Vector2(1500.0, 0.0),
		Vector2.ZERO,
		true,
		1.0,
		Rect2(),
		PetBehavior.CONTENT_EDGE_MARGIN,
		false,
		PetBehavior.THROW_DISTANCE_THRESHOLD - 1.0
	)
	_expect(short_flick["action"] == "place", "fast movement below the distance threshold only places the pet")
	_expect(behavior.window_position == Vector2(163, 100), "short fast drag keeps the selected placement")
	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.move_drag(Vector2(164, 100), Vector2(PetBehavior.THROW_DISTANCE_THRESHOLD, 0.0))
	var threshold_flick := behavior.end_drag(
		work_area,
		window_size,
		Vector2(1500.0, 0.0),
		Vector2.ZERO,
		true,
		1.0,
		Rect2(),
		PetBehavior.CONTENT_EDGE_MARGIN,
		false,
		PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	_expect(threshold_flick["action"] == "throw", "fast movement at the distance threshold can throw")

	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.move_drag(Vector2(100, 100), Vector2(100, 100))
	var toss_fall_result := behavior.end_drag(
		work_area, window_size, Vector2(100.0, 0.0), Vector2.ZERO, true,
		1.0, Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, true
	)
	_expect(toss_fall_result["action"] == "fall", "enabled slow-release fall enters gravity fall mode")
	_expect(behavior.mode == PetBehavior.Mode.FALL, "enabled slow-release fall uses fall state")
	var landed := false
	var landing_impact := false
	for _step in range(30):
		var events := behavior.advance(0.05, work_area, window_size)
		if events.landed:
			landed = true
			for impact: PetImpact in events.impacts:
				landing_impact = landing_impact or impact.normal.y < -0.9
			break
	_expect(landed, "falling release emits a landing event")
	_expect(landing_impact, "landing emits a vertical impact event")

	behavior.initialize(Vector2(470, 100))
	behavior.begin_drag(Vector2.ZERO)
	var baseline_throw := PetBehavior.new()
	baseline_throw.initialize(Vector2(200, 100))
	baseline_throw.begin_drag(Vector2.ZERO)
	baseline_throw.end_drag(
		work_area, window_size, Vector2(500.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	var baseline_speed := baseline_throw.velocity.length()
	var throw_result := behavior.end_drag(
		work_area, window_size, Vector2(500.0, 0.0), Vector2(8000.0, 0.0), true,
		1.5, Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, true, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	_expect(throw_result["action"] == "throw", "fast release enters throw mode")
	_expect(behavior.mode == PetBehavior.Mode.LAUNCH, "fast release uses launch state")
	_expect(behavior.velocity.x > baseline_speed, "forward mouse acceleration increases throw speed")
	_expect(behavior.velocity.x > 1500.0, "configured throw strength produces a stronger launch")
	_expect(behavior.velocity.x <= PetBehavior.MAX_THROW_SPEED, "throw velocity respects its safety cap")
	behavior.advance(0.05, work_area, window_size)
	_expect(behavior.window_position.x == 480.0 and behavior.velocity.x < 0.0, "throw rebounds from the screen edge")
	behavior.initialize(Vector2(200, 100))
	behavior.begin_drag(Vector2.ZERO)
	var acceleration_throw := behavior.end_drag(
		work_area, window_size, Vector2(180.0, 0.0), Vector2(10000.0, 0.0), true, 1.5,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	_expect(acceleration_throw["action"] == "throw", "forward acceleration can trigger a throw below the base speed threshold")
	_expect(behavior.velocity.x > PetBehavior.THROW_SPEED_THRESHOLD, "acceleration contributes to launch distance")
	behavior.initialize(Vector2(100, 100))
	behavior.begin_drag(Vector2.ZERO)
	behavior.end_drag(
		work_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	behavior.advance(0.2, work_area, window_size)
	_expect(
		is_equal_approx(
			behavior.velocity.y,
			PetBehavior.THROW_GRAVITY * 0.2 * exp(-PetBehavior.THROW_LINEAR_DAMPING * 0.2)
		),
		"reduced throw gravity keeps the launch airborne longer"
	)
	_expect(behavior.window_position.x > 200.0, "fling initial velocity moves the pet a long distance")
	_expect(
		behavior.velocity.x < 1200.0 and behavior.velocity.x > 0.0,
		"inertia damping gradually slows the thrown pet"
	)
	var fling_area := Rect2i(0, 0, 10000, 3000)
	var slow_fling := PetBehavior.new()
	slow_fling.initialize(Vector2(1000, 500))
	slow_fling.begin_drag(Vector2.ZERO)
	slow_fling.end_drag(
		fling_area, window_size, Vector2(500.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	var slow_fling_speed := slow_fling.velocity.x
	var fast_fling := PetBehavior.new()
	fast_fling.initialize(Vector2(1000, 500))
	fast_fling.begin_drag(Vector2.ZERO)
	fast_fling.end_drag(
		fling_area, window_size, Vector2(3000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	var fast_fling_speed := fast_fling.velocity.x
	fast_fling.advance(0.1, fling_area, window_size)
	_expect(fast_fling_speed > slow_fling_speed * 4.0, "stronger flicks launch with proportionally higher inertia")
	_expect(fast_fling.window_position.x > 1300.0, "a strong flick moves the pet far during the initial burst")
	var early_fling_speed := fast_fling.velocity.x
	fast_fling.advance(0.2, fling_area, window_size)
	_expect(fast_fling.velocity.x < early_fling_speed * 0.5, "throw damping quickly eases the initial fling speed")
	var low_damping_fling := PetBehavior.new()
	low_damping_fling.initialize(Vector2(1000, 500))
	low_damping_fling.set_throw_physics(1.5, 1.0, 0.82)
	low_damping_fling.begin_drag(Vector2.ZERO)
	low_damping_fling.end_drag(
		fling_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	low_damping_fling.advance(0.1, fling_area, window_size)
	var high_damping_fling := PetBehavior.new()
	high_damping_fling.initialize(Vector2(1000, 500))
	high_damping_fling.set_throw_physics(8.0, 1.0, 0.82)
	high_damping_fling.begin_drag(Vector2.ZERO)
	high_damping_fling.end_drag(
		fling_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	high_damping_fling.advance(0.1, fling_area, window_size)
	_expect(
		low_damping_fling.velocity.x > high_damping_fling.velocity.x,
		"lower throw damping preserves more horizontal inertia"
	)
	var normal_gravity_fling := PetBehavior.new()
	normal_gravity_fling.initialize(Vector2(1000, 500))
	normal_gravity_fling.begin_drag(Vector2.ZERO)
	normal_gravity_fling.end_drag(
		fling_area, window_size, Vector2(0.0, 1000.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	normal_gravity_fling.advance(0.1, fling_area, window_size)
	var strong_gravity_fling := PetBehavior.new()
	strong_gravity_fling.initialize(Vector2(1000, 500))
	strong_gravity_fling.set_throw_physics(4.5, 1.5, 0.82)
	strong_gravity_fling.begin_drag(Vector2.ZERO)
	strong_gravity_fling.end_drag(
		fling_area, window_size, Vector2(0.0, 1000.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	strong_gravity_fling.advance(0.1, fling_area, window_size)
	_expect(
		strong_gravity_fling.velocity.y > normal_gravity_fling.velocity.y,
		"throw gravity scale changes vertical acceleration"
	)
	var no_bounce_fling := PetBehavior.new()
	no_bounce_fling.initialize(Vector2(470, 100))
	no_bounce_fling.set_throw_physics(4.5, 1.0, 0.0)
	no_bounce_fling.begin_drag(Vector2.ZERO)
	no_bounce_fling.end_drag(
		work_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	no_bounce_fling.advance(0.05, work_area, window_size)
	_expect(
		no_bounce_fling.window_position.x == 480.0 and is_zero_approx(no_bounce_fling.velocity.x),
		"zero throw bounce stops horizontal movement at the screen edge"
	)
	var bounded_tuning := PetBehavior.new()
	bounded_tuning.set_throw_physics(99.0, -1.0, 2.0)
	_expect(
		is_equal_approx(bounded_tuning.throw_damping, 8.0)
			and is_equal_approx(bounded_tuning.throw_gravity_scale, 0.1)
			and is_equal_approx(bounded_tuning.throw_bounce, 1.0),
		"throw physics clamps values to valid ranges"
	)
	var bouncy_fling := PetBehavior.new()
	bouncy_fling.initialize(Vector2(1000, 1000))
	bouncy_fling.set_throw_mode(PetThrowProfile.Style.BOUNCY, PetThrowProfile.Duration.TEN_SECONDS)
	bouncy_fling.set_throw_physics(0.5, 0.75, 0.95)
	bouncy_fling.begin_drag(Vector2.ZERO)
	bouncy_fling.end_drag(
		fling_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	bouncy_fling.advance(5.0, fling_area, window_size)
	_expect(
		bouncy_fling.fling_active and bouncy_fling.mode == PetBehavior.Mode.LAUNCH,
		"bouncy preset lasts longer than the standard fling window"
	)
	_expect(is_equal_approx(bouncy_fling.mode_time, 25.0), "bouncy preset runs for thirty seconds")
	var madness_fling := PetBehavior.new()
	var endless_area := Rect2i(0, 0, 100000, 100000)
	madness_fling.initialize(Vector2(1000, 1000))
	madness_fling.set_throw_mode(PetThrowProfile.Style.MADNESS, PetThrowProfile.Duration.CONTINUOUS)
	madness_fling.set_throw_physics(0.0, 0.5, 1.0)
	madness_fling.begin_drag(Vector2.ZERO)
	madness_fling.end_drag(
		endless_area, window_size, Vector2(3000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	madness_fling.advance(6.0, endless_area, window_size)
	_expect(
		madness_fling.fling_active and madness_fling.mode == PetBehavior.Mode.LAUNCH,
		"continuous madness mode does not expire after the standard timeout"
	)
	_expect(
		madness_fling.velocity.length() <= PetBehavior.MAX_THROW_SPEED,
		"madness mode keeps velocity within the safety cap"
	)
	var settled_madness := PetBehavior.new()
	settled_madness.initialize(Vector2(1000.0, 99680.0))
	settled_madness.set_throw_mode(
		PetThrowProfile.Style.MADNESS,
		PetThrowProfile.Duration.CONTINUOUS
	)
	settled_madness.set_throw_physics(0.0, 0.1, 1.0)
	settled_madness.mode = PetBehavior.Mode.LAUNCH
	settled_madness.mode_time = INF
	settled_madness.fling_active = true
	settled_madness.velocity = Vector2.ZERO
	settled_madness.advance(0.01, endless_area, window_size)
	_expect(
		settled_madness.fling_active and settled_madness.mode == PetBehavior.Mode.LAUNCH,
		"continuous madness stays active when the pet settles against an edge"
	)
	_expect(madness_fling.stop_throw(), "explicit stop command cancels continuous madness mode")
	_expect(
		not madness_fling.fling_active and madness_fling.mode == PetBehavior.Mode.IDLE
			and madness_fling.velocity.is_zero_approx(),
		"stopping madness mode leaves the pet safely at rest"
	)
	var timed_madness := PetBehavior.new()
	timed_madness.initialize(Vector2(1000, 1000))
	timed_madness.set_throw_mode(PetThrowProfile.Style.MADNESS, PetThrowProfile.Duration.TEN_SECONDS)
	timed_madness.set_throw_physics(0.0, 0.1, 1.0)
	timed_madness.begin_drag(Vector2.ZERO)
	timed_madness.end_drag(
		endless_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	timed_madness.advance(10.1, endless_area, window_size)
	_expect(not timed_madness.fling_active, "timed madness mode stops when its selected duration expires")

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
	behavior.end_drag(
		work_area, window_size, Vector2(1000.0, 0.0), Vector2.ZERO, true, 1.0,
		Rect2(), PetBehavior.CONTENT_EDGE_MARGIN, false, PetBehavior.THROW_DISTANCE_THRESHOLD
	)
	behavior.advance(0.05, work_area, window_size)
	_expect(behavior.window_position.x == 480.0 and behavior.velocity.x < 0.0, "manual throw still rebounds while antics are paused")

func _test_collision_world() -> void:
	var area := Rect2i(0, 0, 1000, 1000)
	var soft_bounce_world := PetCollisionWorld.new()
	soft_bounce_world.set_collision_physics(0.5, 0.35)
	soft_bounce_world.add_body(0, 100, Vector2(100, 100), area)
	soft_bounce_world.add_body(1, 100, Vector2(152, 100), area)
	soft_bounce_world.get_body(0)["velocity"] = Vector2(300, 0)
	soft_bounce_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	var elastic_bounce_world := PetCollisionWorld.new()
	elastic_bounce_world.set_collision_physics(0.5, 0.95)
	elastic_bounce_world.add_body(0, 100, Vector2(100, 100), area)
	elastic_bounce_world.add_body(1, 100, Vector2(152, 100), area)
	elastic_bounce_world.get_body(0)["velocity"] = Vector2(300, 0)
	elastic_bounce_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	_expect(
		Vector2(elastic_bounce_world.get_body(1)["velocity"]).x
			> Vector2(soft_bounce_world.get_body(1)["velocity"]).x,
		"the active throw profile restitution controls every frog's pair collision"
	)
	var soft_damping_world := PetCollisionWorld.new()
	soft_damping_world.set_collision_physics(0.5, 0.95)
	soft_damping_world.add_body(0, 100, Vector2(100, 100), area)
	soft_damping_world.get_body(0)["velocity"] = Vector2(600, 0)
	soft_damping_world.advance(0.1, [area])
	var strong_damping_world := PetCollisionWorld.new()
	strong_damping_world.set_collision_physics(4.5, 0.95)
	strong_damping_world.add_body(0, 100, Vector2(100, 100), area)
	strong_damping_world.get_body(0)["velocity"] = Vector2(600, 0)
	strong_damping_world.advance(0.1, [area])
	_expect(
		Vector2(soft_damping_world.get_body(0)["velocity"]).x
			> Vector2(strong_damping_world.get_body(0)["velocity"]).x,
		"the active throw profile damping controls momentum for all fleet bodies"
	)
	var edge_world := PetCollisionWorld.new()
	edge_world.add_body(1, 100, Vector2(840, 200), area)
	edge_world.get_body(1)["velocity"] = Vector2(1000, 0)
	var edge_impacts: Array[PetImpact] = []
	for _step in range(20):
		edge_impacts.append_array(edge_world.advance(PetCollisionWorld.FIXED_STEP, [area]))
	_expect(edge_world.get_body(1)["position"].x <= 900.0, "collision body stays inside screen bounds")
	_expect(edge_world.get_body(1)["velocity"].x < 0.0, "collision body reflects from screen edge")
	var has_edge_impact := false
	for impact: PetImpact in edge_impacts:
		if impact.body_id == 1 and impact.normal.x < -0.9 and impact.source == PetImpact.Source.EDGE:
			has_edge_impact = true
	_expect(has_edge_impact, "screen-edge collision emits a directional impact event")

	var content_rect := Rect2(20.0, 10.0, 60.0, 80.0)
	var content_edge_world := PetCollisionWorld.new()
	content_edge_world.add_body(1, 100, Vector2(990, 200), area, content_rect)
	content_edge_world.get_body(1)["velocity"] = Vector2(1800, 0)
	_expect(
		content_edge_world.get_body(1)["position"].x == 919.0,
		"initial placement clamps by the visible-body edge"
	)
	content_edge_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	var bounced_body := content_edge_world.get_body(1)
	_expect(bounced_body["position"].x == 919.0, "collision body stops at the visible-body edge")
	_expect(bounced_body["velocity"].x < 0.0, "content boundary reverses bounce at the visible-body edge")
	_expect(
		Vector2(bounced_body["position"]).x + Rect2(bounced_body["content_rect"]).end.x <= area.end.x - DesktopBounds.CONTENT_EDGE_MARGIN,
		"bouncing body remains inside the work area"
	)

	var content_drag_world := PetCollisionWorld.new()
	content_drag_world.add_body(0, 100, Vector2(100, 100), area, content_rect)
	content_drag_world.begin_drag(0, Vector2(150, 150))
	content_drag_world.finish_drag(0, Vector2(1200, 150), [area])
	var dragged_body := content_drag_world.get_body(0)
	_expect(dragged_body["position"].x == 919.0, "drag is clamped by the visible-body bounds")
	_expect(
		Vector2(dragged_body["position"]).x + Rect2(dragged_body["content_rect"]).end.x <= area.end.x - DesktopBounds.CONTENT_EDGE_MARGIN,
		"dragged body remains inside the work area"
	)
	content_drag_world.release_drag(0)

	var edge_pair_world := PetCollisionWorld.new()
	var body_rect := Rect2(20.0, 10.0, 60.0, 80.0)
	var narrow_area := Rect2i(0, 0, 200, 200)
	edge_pair_world.add_body(0, 100, Vector2(-30, 60), narrow_area, body_rect)
	edge_pair_world.add_body(1, 100, Vector2(-30, 60), narrow_area, body_rect)
	edge_pair_world.advance(PetCollisionWorld.FIXED_STEP, [narrow_area])
	var edge_first: Dictionary = edge_pair_world.get_body(0)
	var edge_second: Dictionary = edge_pair_world.get_body(1)
	var edge_first_center: Vector2 = Vector2(edge_first["position"]) + body_rect.get_center()
	var edge_second_center: Vector2 = Vector2(edge_second["position"]) + body_rect.get_center()
	_expect(edge_first["position"].x >= -19.0, "edge-constrained pet remains within its visible boundary")
	_expect(
		edge_first_center.distance_to(edge_second_center) >= 60.0,
		"wall constraint transfers the remaining separation to the adjacent pet"
	)
	_expect(edge_second["position"].x > edge_first["position"].x, "wall-side pet pushes its neighbor away")
	var vertical_world := PetCollisionWorld.new()
	vertical_world.add_body(0, 100, Vector2(60, 60), narrow_area, body_rect)
	vertical_world.add_body(1, 100, Vector2(60, 80), narrow_area, body_rect)
	vertical_world.advance(PetCollisionWorld.FIXED_STEP, [narrow_area])
	var vertical_first: Dictionary = vertical_world.get_body(0)
	var vertical_second: Dictionary = vertical_world.get_body(1)
	var vertical_first_center := Vector2(vertical_first["position"]) + body_rect.get_center()
	var vertical_second_center := Vector2(vertical_second["position"]) + body_rect.get_center()
	_expect(
		absf(vertical_second_center.y - vertical_first_center.y) >= 80.0,
		"vertical ellipse contact separates along the frog's tall axis"
	)
	var impossible_area := Rect2i(0, 0, 100, 100)
	var impossible_world := PetCollisionWorld.new()
	impossible_world.add_body(0, 100, Vector2.ZERO, impossible_area, body_rect)
	impossible_world.add_body(1, 100, Vector2.ZERO, impossible_area, body_rect)
	impossible_world.advance(PetCollisionWorld.FIXED_STEP, [impossible_area])
	_expect(
		impossible_world.get_body(0)["position"].x >= -19.0
			and impossible_world.get_body(0)["position"].x <= 19.0
			and impossible_world.get_body(1)["position"].x >= -19.0
			and impossible_world.get_body(1)["position"].x <= 19.0,
		"physically impossible crowding stays inside the screen edges"
	)
	_expect(not impossible_world.has_motion(), "impossible overlap does not keep the physics loop active")

	var size_world := PetCollisionWorld.new()
	size_world.add_body(0, 160, Vector2(400, 300), area)
	size_world.add_body(1, 48, Vector2(500, 356), area)
	var large_start: Vector2 = size_world.get_body(0)["position"]
	var small_start: Vector2 = size_world.get_body(1)["position"]
	size_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	var large_body: Dictionary = size_world.get_body(0)
	var small_body: Dictionary = size_world.get_body(1)
	var size_distance := (Vector2(small_body["position"]) + Vector2(24, 24)).distance_to(
		Vector2(large_body["position"]) + Vector2(80, 80)
	)
	_expect(size_distance >= 64.0, "different-size pets separate by their combined collision radii")
	_expect(
		Vector2(small_body["position"]).distance_to(small_start)
			> Vector2(large_body["position"]).distance_to(large_start),
		"smaller pet moves farther under the existing mass model"
	)

	var disabled_world := PetCollisionWorld.new()
	disabled_world.collisions_enabled = false
	disabled_world.add_body(0, 100, Vector2(100, 100), area)
	disabled_world.add_body(1, 100, Vector2(100, 100), area)
	disabled_world.advance(PetCollisionWorld.FIXED_STEP, [area])
	_expect(
		Vector2(disabled_world.get_body(0)["position"]).distance_to(Vector2(disabled_world.get_body(1)["position"])) < 62.0,
		"disabling pet collision preserves the existing pass-through behavior"
	)

	var world := PetCollisionWorld.new()
	world.set_collision_physics(1.8, 0.82)
	world.add_body(0, 100, Vector2(100, 100), area)
	world.add_body(1, 100, Vector2(220, 100), area)
	world.add_body(2, 100, Vector2(340, 100), area)
	world.begin_drag(0, Vector2(150, 150))
	world.move_drag(0, Vector2(270, 150))
	world.advance(PetCollisionWorld.FIXED_STEP, [area])
	_expect(
		Vector2(world.get_body(0)["position"]).is_equal_approx(Vector2(220, 100)),
		"dragged frog follows the latest pointer target without a speed-limited catch-up"
	)
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
	var hit_small_frog := false
	for impact: PetImpact in sweep_collisions:
		hit_small_frog = hit_small_frog or impact.body_id == 1
	_expect(hit_small_frog, "release path reports the struck frog")
	var has_horizontal_impact := false
	for impact: PetImpact in sweep_collisions:
		if impact.body_id == 1 and impact.normal.x > 0.9 and impact.source == PetImpact.Source.PET:
			has_horizontal_impact = true
	_expect(has_horizontal_impact, "drag collision reports its horizontal contact normal")
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
		var repeatedly_tapped_state := PetBehavior.new()
		for _tap in range(12):
			repeatedly_tapped_state.tap()
		frog.apply_behavior(repeatedly_tapped_state)
		_expect(frog.scale.is_equal_approx(frog.base_scale), "repeated taps never scale up the frog")
		frog.set_dragging(true)
		frog.drag_vector = Vector2(600.0, 300.0)
		frog.idle_phase = 1.2
		await process_frame
		await process_frame
		_expect(sprite.scale.is_equal_approx(frog.base_image_scale), "dragging does not stretch or squash the frog")
		_expect(is_zero_approx(sprite.rotation), "dragging does not tilt the frog")
		frog.set_dragging(false)
		frog.set_idle_animation_enabled(false)
		var airborne_state := PetBehavior.new()
		airborne_state.mode = PetBehavior.Mode.LAUNCH
		airborne_state.velocity = Vector2(0.0, 2000.0)
		frog.apply_behavior(airborne_state)
		await process_frame
		await process_frame
		_expect(sprite.scale.is_equal_approx(frog.base_image_scale), "vertical flight speed no longer stretches the body")
		var stable_bounds := frog.get_content_bounds()
		frog.play_impact(Vector2.RIGHT, 1000.0)
		await process_frame
		await process_frame
		_expect(sprite.scale.x < frog.base_image_scale.x, "horizontal impact compresses the horizontal axis")
		_expect(sprite.scale.y > frog.base_image_scale.y, "horizontal impact stretches the perpendicular axis")
		_expect(frog.get_content_bounds().is_equal_approx(stable_bounds), "impact deformation does not resize the physics bounds")
		frog.impact_seconds = 0.0
		frog.impact_strength = 0.0
		frog.play_impact(Vector2.RIGHT, PetImpact.MINIMUM_SPEED - 1.0)
		_expect(is_zero_approx(frog.impact_seconds), "sub-threshold contacts do not trigger squash feedback")
		frog.play_impact(Vector2.DOWN, 1000.0)
		await process_frame
		await process_frame
		_expect(sprite.scale.y < frog.base_image_scale.y, "vertical impact compresses the vertical axis")
		_expect(sprite.scale.x > frog.base_image_scale.x, "vertical impact stretches the perpendicular axis")
	frog.position = Vector2(160, 172)
	_expect(frog.is_point_on_pet(Vector2(160, 172)), "frog center is clickable")
	_expect(not frog.is_point_on_pet(Vector2(0, 0)), "transparent area is not clickable")
	_expect(frog.get_mouse_region().size() >= 12, "mouse passthrough region has a polygon")
	var full_size_bounds := FrogVisual.content_bounds_for_size(320.0)
	var expected_size_bounds := FrogVisual.content_bounds_for_size(160.0)
	_expect(
		is_equal_approx(expected_size_bounds.position.x, full_size_bounds.position.x * 0.5)
			and is_equal_approx(expected_size_bounds.size.y, full_size_bounds.size.y * 0.5),
		"size-scaled content bounds match the pet window layout"
	)
	var resting_bounds := frog.get_content_bounds()
	sprite.scale = sprite.scale * Vector2(1.25, 1.15)
	sprite.rotation = 0.2
	var animated_bounds := frog.get_content_bounds()
	_expect(animated_bounds.is_equal_approx(resting_bounds), "physics bounds ignore transient sprite deformation")
	frog.set_display_size_scale(1.8)
	_expect(frog.is_point_on_pet(Vector2(260, 172)), "scaled frog hit region follows its configured display size")
	_expect(not frog.is_point_on_pet(Vector2(0, 0)), "scaled frog hit region excludes transparent corners")
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
