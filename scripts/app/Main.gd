extends Node2D

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetImpact = preload("res://scripts/core/PetImpact.gd")
const PetGesture = preload("res://scripts/input/PetGesture.gd")
const PetSettingsStore = preload("res://scripts/core/PetSettings.gd")
const PetInteractions = preload("res://scripts/core/PetInteractions.gd")
const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const PetAudio = preload("res://scripts/audio/PetAudio.gd")
const PetFleet = preload("res://scripts/entities/PetFleet.gd")
const PET_EDGE_MARGIN := DesktopBounds.CONTENT_EDGE_MARGIN

var behavior := PetBehavior.new()
var gesture := PetGesture.new()
var frog: Node2D
var swarm: Node2D
var menu: PetContextMenu
var audio: PetAudio
var fleet: Node
var settings: Node
var avatar_dialog: FileDialog
var interaction_notice: AcceptDialog
var pointer_held := false
var dragging := false
var avatar_feed_press := false
var drag_offset := Vector2.ZERO
var last_drag_pointer_position := Vector2.ZERO

func _ready() -> void:
	Engine.max_fps = 60
	settings = get_node("/root/PetSettings")
	var pet_window := get_window()
	pet_window.transparent = true
	pet_window.borderless = true
	pet_window.always_on_top = settings.always_on_top
	pet_window.content_scale_size = Vector2i(settings.frog_size, settings.frog_size)
	pet_window.size = Vector2i(settings.frog_size, settings.frog_size)
	frog = $Frog
	frog.position = Vector2(settings.frog_size * 0.55, settings.frog_size * 0.51)
	frog.call("set_display_size_scale", float(settings.frog_size) / 320.0)
	swarm = $PetSwarm
	_restore_window_position()
	behavior.set_enabled(settings.antics_enabled)
	behavior.initialize(Vector2(pet_window.position))
	_sync_throw_configuration()
	swarm.set_simulation_enabled(settings.antics_enabled)
	audio = PetAudio.new()
	audio.name = "PetAudio"
	add_child(audio)
	fleet = PetFleet.new()
	fleet.name = "PetFleet"
	add_child(fleet)
	fleet.initialize_primary(pet_window, frog, behavior, swarm, audio)
	fleet.activity_changed.connect(_on_fleet_activity_changed)
	fleet.fleet_changed.connect(_refresh_menu_state)
	_build_menu()
	_build_interaction_dialogs()
	pet_window.files_dropped.connect(_on_files_dropped)
	frog.interaction_result_revealed.connect(_on_interaction_result_revealed)
	call_deferred("_restore_small_pets")
	if not fleet.is_active():
		_apply_behavior_visuals()
	_update_mouse_region()
	swarm.activity_finished.connect(_on_swarm_activity_finished)

func _process(delta: float) -> void:
	if pointer_held:
		_handle_gesture_result(gesture.advance(Vector2(DisplayServer.mouse_get_position())))
	var work_area := DesktopBounds.current_work_area()
	var advance_behavior: bool = not fleet.is_active() and not pointer_held and not menu.visible
	if advance_behavior:
		var events := behavior.advance(
			delta, work_area, get_window().size, frog.get_content_bounds(), PET_EDGE_MARGIN
		)
		if events.corner_hit:
			frog.play_blink()
			audio.play_effect(PetAudio.Effect.CORNER_BUMP)
		for impact: PetImpact in events["impacts"]:
			if impact.body_id == 0:
				frog.play_impact(impact.normal, impact.speed)
		if events.landed:
			audio.play_effect(PetAudio.Effect.LAND)
	if not fleet.is_active():
		_apply_behavior_visuals()
	if advance_behavior:
		_set_window_position(behavior.window_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if swarm.visible and not event.relative.is_zero_approx():
			swarm.kick_near(event.position, event.relative * 2.4)
		if pointer_held:
			var screen_mouse := DisplayServer.mouse_get_position()
			_handle_gesture_result(gesture.update(Vector2(screen_mouse)))
			if dragging:
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if frog.has_pending_avatar() and frog.is_point_on_rear(event.position):
				_feed_pending_avatar()
			else:
				_refresh_menu_state()
				menu.position = DisplayServer.mouse_get_position()
				menu.popup()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and frog.is_point_on_pet(event.position):
				avatar_feed_press = not fleet.is_active() and frog.has_pending_avatar() and frog.is_point_on_rear(event.position)
				if fleet.is_active():
					fleet.pointer_press(0, DisplayServer.mouse_get_position())
					get_viewport().set_input_as_handled()
				else:
					pointer_held = true
					dragging = false
					var drag_screen_origin := DisplayServer.mouse_get_position()
					gesture.begin(Vector2(drag_screen_origin))
			elif event.pressed and swarm.visible:
				swarm.kick_near(event.position, Vector2(0.0, -120.0))
			elif not event.pressed and fleet.has_active_pointer():
				fleet.pointer_release(DisplayServer.mouse_get_position())
				avatar_feed_press = false
				get_viewport().set_input_as_handled()
			elif not event.pressed and pointer_held:
				var release_result := gesture.end(Vector2(DisplayServer.mouse_get_position()))
				pointer_held = false
				_handle_gesture_result(release_result)
				if bool(release_result["dragging"]):
					dragging = true
					var drag_result := behavior.end_drag(
						DesktopBounds.current_work_area(),
						get_window().size,
						Vector2(release_result["release_velocity"]),
						Vector2(release_result["release_acceleration"]),
						settings.long_press_mode == PetSettingsStore.LongPressMode.TOSS,
						settings.throw_strength,
						frog.get_content_bounds(),
						PET_EDGE_MARGIN,
						settings.fall_on_slow_release,
						Vector2(release_result["total"]).length()
					)
					match drag_result["action"]:
						"throw": audio.play_effect(PetAudio.Effect.THROW)
						_: audio.play_effect(PetAudio.Effect.DRAG_RELEASE)
				else:
					if avatar_feed_press:
						_feed_pending_avatar()
					elif behavior.tap():
						frog.play_impact(Vector2.DOWN, 1250.0)
						audio.play_effect(PetAudio.Effect.LAND)
					else:
						audio.play_effect(PetAudio.Effect.POKE)
				_apply_behavior_visuals()
				_set_window_position(behavior.window_position)
				if bool(release_result["dragging"]):
					_save_settings()
				_update_mouse_region()
				dragging = false
				avatar_feed_press = false
				last_drag_pointer_position = Vector2.ZERO
				get_viewport().set_input_as_handled()
func _build_menu() -> void:
	menu = PetContextMenu.new()
	menu.command_selected.connect(_on_menu_pressed)
	menu.setting_selected.connect(_on_menu_setting_selected)
	menu.volume_selected.connect(_on_menu_volume_selected)
	menu.long_press_mode_selected.connect(_on_long_press_mode_selected)
	menu.fall_on_slow_release_selected.connect(_on_fall_on_slow_release_selected)
	menu.throw_strength_selected.connect(_on_throw_strength_selected)
	menu.throw_style_selected.connect(_on_throw_style_selected)
	menu.throw_duration_selected.connect(_on_throw_duration_selected)
	menu.throw_tuning_selected.connect(_on_throw_tuning_selected)
	menu.fleet_command_selected.connect(_on_fleet_command_selected)
	menu.size_selected.connect(_on_frog_size_selected)
	menu.collision_enabled_selected.connect(_on_collision_enabled_selected)
	add_child(menu)
	_refresh_menu_state()

func _restore_small_pets() -> void:
	if is_instance_valid(fleet):
		fleet.restore_small_pets(settings.frog_instances)

func _on_menu_pressed(id: int) -> void:
	match id:
		PetContextMenu.Command.DVD_BOUNCE:
			behavior.start_dvd_bounce()
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.SLITHER:
			behavior.start_slither(
				DesktopBounds.current_work_area(),
				get_window().size,
				frog.get_content_bounds(),
				PET_EDGE_MARGIN
			)
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.FLOAT_FALL:
			behavior.start_float()
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.SPAWN_CLONES:
			swarm.set_simulation_enabled(settings.antics_enabled)
			swarm.spawn()
			audio.play_effect(PetAudio.Effect.SWARM_SPAWN)
			_update_mouse_region()
		PetContextMenu.Command.CLEAR_CLONES:
			if swarm.get_clone_count() > 0:
				swarm.clear()
				audio.play_effect(PetAudio.Effect.SWARM_CLEAR)
			_update_mouse_region()
		PetContextMenu.Command.MOVE_TO_CORNER:
			_move_to_corner()
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.STOP_THROW:
			if behavior.stop_throw():
				audio.play_effect(PetAudio.Effect.DRAG_RELEASE)
		PetContextMenu.Command.PICK_AVATAR:
			avatar_dialog.popup_centered(Vector2i(760, 560))
		PetContextMenu.Command.FEED_AVATAR:
			_feed_pending_avatar()
		PetContextMenu.Command.DRAW_FORTUNE:
			frog.play_interaction(PetInteractions.draw_fortune())
		PetContextMenu.Command.CLEAR_INTERACTION_RESULT:
			frog.clear_interaction_result()
		PetContextMenu.Command.QUIT:
			_save_settings()
			get_tree().quit()
	_apply_behavior_visuals()
	_refresh_menu_state()

func _build_interaction_dialogs() -> void:
	avatar_dialog = FileDialog.new()
	avatar_dialog.title = "选择一张头像"
	avatar_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	avatar_dialog.access = FileDialog.ACCESS_FILESYSTEM
	avatar_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp ; 图片文件"])
	avatar_dialog.theme = menu.theme
	avatar_dialog.file_selected.connect(_on_avatar_file_selected)
	add_child(avatar_dialog)

	interaction_notice = AcceptDialog.new()
	interaction_notice.title = "奶蛙没吃下这张图"
	interaction_notice.theme = menu.theme
	add_child(interaction_notice)

func _on_files_dropped(files: PackedStringArray) -> void:
	for path in files:
		if PetInteractions.supports_image_path(path):
			_load_avatar(path)
			return
	_show_interaction_notice("请拖入 PNG、JPG、WebP 或 BMP 图片。")

func _on_avatar_file_selected(path: String) -> void:
	_load_avatar(path)

func _load_avatar(path: String) -> void:
	var loaded := PetInteractions.load_avatar(path)
	if not bool(loaded.get("ok", false)):
		_show_interaction_notice(str(loaded.get("error", "图片无法读取，请换一张再试。")))
		return
	var texture := ImageTexture.create_from_image(loaded["image"] as Image)
	frog.set_pending_avatar(texture)
	_refresh_menu_state()

func _feed_pending_avatar() -> void:
	if not frog.has_pending_avatar():
		return
	frog.play_interaction(PetInteractions.create_avatar_result(frog.pending_avatar))
	audio.play_effect(PetAudio.Effect.FEED)
	_refresh_menu_state()

func _show_interaction_notice(message: String) -> void:
	interaction_notice.dialog_text = message
	interaction_notice.popup_centered()

func _on_interaction_result_revealed(_kind: int) -> void:
	audio.play_effect(PetAudio.Effect.REVEAL)

func _on_menu_setting_selected(setting: int, enabled: bool) -> void:
	match setting:
		PetContextMenu.Setting.ANTICS_ENABLED:
			settings.antics_enabled = enabled
			behavior.set_enabled(enabled)
			swarm.set_simulation_enabled(enabled)
		PetContextMenu.Setting.ALWAYS_ON_TOP:
			settings.always_on_top = enabled
			get_window().always_on_top = enabled
			fleet.set_always_on_top(enabled)
		PetContextMenu.Setting.SOUND_ENABLED:
			settings.sound_enabled = enabled
			audio.sync_settings()
	settings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_menu_volume_selected(value: float) -> void:
	settings.sfx_volume = value
	settings.save_settings()
	audio.sync_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_long_press_mode_selected(mode: int) -> void:
	settings.long_press_mode = mode
	settings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_fall_on_slow_release_selected(enabled: bool) -> void:
	settings.fall_on_slow_release = enabled
	settings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_throw_strength_selected(value: float) -> void:
	settings.throw_strength = value
	settings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_throw_style_selected(style: int) -> void:
	settings.set_throw_style(style)
	settings.save_settings()
	_sync_throw_configuration()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_throw_duration_selected(seconds: int) -> void:
	settings.set_throw_duration(seconds)
	settings.save_settings()
	_sync_throw_configuration()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_throw_tuning_selected(tuning: int, value: float) -> void:
	match tuning:
		PetSettingsStore.ThrowTuning.DAMPING:
			settings.throw_damping = value
		PetSettingsStore.ThrowTuning.GRAVITY_SCALE:
			settings.throw_gravity_scale = value
		PetSettingsStore.ThrowTuning.BOUNCE:
			settings.throw_bounce = value
	_sync_throw_configuration()
	settings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _sync_throw_configuration() -> void:
	behavior.set_throw_physics(
		settings.throw_damping,
		settings.throw_gravity_scale,
		settings.throw_bounce
	)
	behavior.set_throw_mode(settings.throw_style, settings.throw_duration_seconds)
	if is_instance_valid(fleet):
		fleet.set_collision_physics(settings.throw_damping, settings.throw_bounce)

func _on_fleet_command_selected(command: int) -> void:
	fleet.handle_pet_command(0, command)
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_frog_size_selected(size: int) -> void:
	fleet.set_pet_size(0, size)
	audio.play_effect(PetAudio.Effect.MENU_CLICK)
	_update_mouse_region()

func _on_collision_enabled_selected(enabled: bool) -> void:
	fleet.set_collisions_enabled(enabled)
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_fleet_activity_changed(active: bool) -> void:
	behavior.set_enabled(not active and settings.antics_enabled)
	_apply_behavior_visuals()
	_update_mouse_region()

func _handle_gesture_result(result: Dictionary) -> void:
	if bool(result.get("started_drag", false)):
		_begin_drag(
			Vector2(result["position"]),
			Vector2(result["drag_origin_position"])
		)
	if dragging and bool(result.get("dragging", false)):
		var screen_mouse := Vector2(result["position"])
		var pointer_motion := screen_mouse - last_drag_pointer_position
		var next_window_position := screen_mouse - Vector2(drag_offset)
		behavior.move_drag(next_window_position, screen_mouse)
		_apply_behavior_visuals()
		var attempted_position := next_window_position
		next_window_position = DesktopBounds.clamp_position_to_content(
			next_window_position,
			DesktopBounds.current_work_area(),
			frog.get_content_bounds(),
			PET_EDGE_MARGIN
		)
		var blocked_motion := next_window_position - attempted_position
		if not blocked_motion.is_zero_approx():
			var impact_normal := blocked_motion.normalized()
			var impact_speed := maxf(0.0, -pointer_motion.dot(impact_normal)) * 60.0
			if impact_speed >= PetImpact.MINIMUM_SPEED:
				frog.play_impact(impact_normal, impact_speed)
		behavior.move_drag(next_window_position, screen_mouse)
		_set_window_position(next_window_position)
		_apply_behavior_visuals()
		last_drag_pointer_position = screen_mouse

func _begin_drag(screen_position: Vector2, drag_origin_position: Vector2) -> void:
	if dragging:
		return
	dragging = true
	last_drag_pointer_position = screen_position
	drag_offset = drag_origin_position - Vector2(get_window().position)
	behavior.begin_drag(drag_origin_position)
	audio.play_effect(PetAudio.Effect.GRAB_START)
	_apply_behavior_visuals()

func _apply_behavior_visuals() -> void:
	if is_instance_valid(frog):
		frog.apply_behavior(behavior)

func _update_mouse_region() -> void:
	if not is_instance_valid(frog) or not is_instance_valid(swarm):
		return
	if swarm.visible:
		get_window().mouse_passthrough_polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(get_window().size.x, 0),
			Vector2(get_window().size),
			Vector2(0, get_window().size.y)
		])
	else:
		get_window().mouse_passthrough_polygon = frog.get_mouse_region()

func _on_swarm_activity_finished() -> void:
	_update_mouse_region()
	_refresh_menu_state()

func _set_window_position(target_position: Vector2) -> void:
	var content_bounds: Rect2 = frog.get_content_bounds() if is_instance_valid(frog) else Rect2(Vector2.ZERO, Vector2(get_window().size))
	var target_center: Vector2 = target_position + content_bounds.get_center()
	var work_area := DesktopBounds.current_work_area()
	for screen in range(DisplayServer.get_screen_count()):
		var candidate: Rect2i = DisplayServer.screen_get_usable_rect(screen)
		if candidate.has_point(Vector2i(roundi(target_center.x), roundi(target_center.y))):
			work_area = candidate
			break
	target_position = DesktopBounds.clamp_position_to_content(
		target_position, work_area, content_bounds, PET_EDGE_MARGIN
	)
	DisplayServer.window_set_position(Vector2i(roundi(target_position.x), roundi(target_position.y)), 0)
	behavior.window_position = target_position
	if is_instance_valid(fleet):
		fleet.sync_primary_position(target_position)

func _restore_window_position() -> void:
	var target := DesktopBounds.current_work_area()
	if settings.has_window_position:
		var content_center: Vector2 = frog.get_content_bounds().get_center()
		for screen in range(DisplayServer.get_screen_count()):
			var usable := DisplayServer.screen_get_usable_rect(screen)
			if usable.has_point(settings.window_position + Vector2i(roundi(content_center.x), roundi(content_center.y))):
				target = usable
				break
		_set_window_position(DesktopBounds.clamp_position_to_content(
			settings.window_position,
			target,
			frog.get_content_bounds(),
			PET_EDGE_MARGIN
		))
	else:
		_move_to_corner()

func _move_to_corner() -> void:
	var usable := DesktopBounds.current_work_area()
	var content: Rect2 = frog.get_content_bounds()
	var destination := DesktopBounds.clamp_position_to_content(
		Vector2(usable.end) - content.end - Vector2.ONE * PET_EDGE_MARGIN,
		usable,
		content,
		PET_EDGE_MARGIN
	)
	_set_window_position(destination)
	behavior.window_position = destination
	_save_settings()

func _save_settings() -> void:
	settings.window_position = get_window().position
	settings.has_window_position = true
	if is_instance_valid(fleet):
		fleet.persist_state()
	else:
		settings.save_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()

func _exit_tree() -> void:
	_save_settings()

func _refresh_menu_state() -> void:
	if not menu:
		return
	fleet.refresh_menu(menu, swarm.get_clone_count(), behavior.fling_active)
	menu.refresh_interaction_state(
		frog.has_pending_avatar(),
		not frog.interaction_result.is_empty()
	)
