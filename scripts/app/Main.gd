extends Node2D

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const PetAudio = preload("res://scripts/audio/PetAudio.gd")
const PET_WINDOW_SIZE := Vector2i(320, 320)

var behavior := PetBehavior.new()
var frog: Node2D
var swarm: Node2D
var menu: PetContextMenu
var audio: PetAudio
var pointer_held := false
var dragging := false
var drag_screen_origin := Vector2i.ZERO
var drag_offset := Vector2i.ZERO

func _ready() -> void:
	Engine.max_fps = 30
	var pet_window := get_window()
	pet_window.transparent = true
	pet_window.borderless = true
	pet_window.always_on_top = PetSettings.always_on_top
	pet_window.size = PET_WINDOW_SIZE
	frog = $Frog
	swarm = $PetSwarm
	_restore_window_position()
	behavior.set_enabled(PetSettings.antics_enabled)
	behavior.initialize(Vector2(pet_window.position))
	swarm.set_simulation_enabled(PetSettings.antics_enabled)
	audio = PetAudio.new()
	audio.name = "PetAudio"
	add_child(audio)
	_build_menu()
	_apply_behavior_visuals()
	_update_mouse_region()
	swarm.activity_finished.connect(_on_swarm_activity_finished)

func _process(delta: float) -> void:
	var work_area := DesktopBounds.current_work_area()
	if not pointer_held and not menu.visible:
		var events := behavior.advance(delta, work_area, PET_WINDOW_SIZE)
		if events.corner_hit:
			frog.play_blink()
			audio.play_effect(PetAudio.Effect.CORNER_BUMP)
		if events.landed:
			frog.play_impact()
			audio.play_effect(PetAudio.Effect.LAND)
		_set_window_position(behavior.window_position)
	_apply_behavior_visuals()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if swarm.visible and not event.relative.is_zero_approx():
			swarm.kick_near(event.position, event.relative * 2.4)
		if pointer_held:
			var screen_mouse := DisplayServer.mouse_get_position()
			var movement := Vector2(screen_mouse - drag_screen_origin)
			if not dragging and movement.length() >= 5.0:
				dragging = true
			if dragging:
				var next_window_position := screen_mouse - drag_offset
				behavior.move_drag(Vector2(next_window_position), Vector2(screen_mouse))
				_set_window_position(Vector2(next_window_position))
				_apply_behavior_visuals()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_refresh_menu_state()
			menu.position = DisplayServer.mouse_get_position()
			menu.popup()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and frog.is_point_on_pet(event.position):
				pointer_held = true
				dragging = false
				drag_screen_origin = DisplayServer.mouse_get_position()
				var window_position := get_window().position
				drag_offset = drag_screen_origin - window_position
				behavior.begin_drag(Vector2(drag_screen_origin))
			elif event.pressed and swarm.visible:
				swarm.kick_near(event.position, Vector2(0.0, -120.0))
			elif not event.pressed and pointer_held:
				pointer_held = false
				if dragging:
					behavior.end_drag(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
					_set_window_position(behavior.window_position)
					_save_settings()
					audio.play_effect(PetAudio.Effect.DRAG_RELEASE)
				else:
					var result := behavior.poke(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
					if result.burst:
						frog.play_burst()
						audio.play_effect(PetAudio.Effect.BURST)
					elif result.heavy_fall:
						frog.play_impact()
						audio.play_effect(PetAudio.Effect.LAND)
					else:
						audio.play_effect(PetAudio.Effect.POKE)
				_apply_behavior_visuals()
				_update_mouse_region()
				get_viewport().set_input_as_handled()
func _build_menu() -> void:
	menu = PetContextMenu.new()
	menu.command_selected.connect(_on_menu_pressed)
	menu.setting_selected.connect(_on_menu_setting_selected)
	menu.volume_selected.connect(_on_menu_volume_selected)
	add_child(menu)
	_refresh_menu_state()

func _on_menu_pressed(id: int) -> void:
	match id:
		PetContextMenu.Command.DVD_BOUNCE:
			behavior.start_dvd_bounce()
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.SLITHER:
			behavior.start_slither(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.FLOAT_FALL:
			behavior.start_float()
			audio.play_effect(PetAudio.Effect.MENU_CLICK)
		PetContextMenu.Command.SPAWN_CLONES:
			swarm.set_simulation_enabled(PetSettings.antics_enabled)
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
		PetContextMenu.Command.QUIT:
			_save_settings()
			get_tree().quit()
	_apply_behavior_visuals()
	_refresh_menu_state()

func _on_menu_setting_selected(setting: int, enabled: bool) -> void:
	match setting:
		PetContextMenu.Setting.ANTICS_ENABLED:
			PetSettings.antics_enabled = enabled
			behavior.set_enabled(enabled)
			swarm.set_simulation_enabled(enabled)
		PetContextMenu.Setting.ALWAYS_ON_TOP:
			PetSettings.always_on_top = enabled
			get_window().always_on_top = enabled
		PetContextMenu.Setting.SOUND_ENABLED:
			PetSettings.sound_enabled = enabled
			audio.sync_settings()
	PetSettings.save_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _on_menu_volume_selected(value: float) -> void:
	PetSettings.sfx_volume = value
	PetSettings.save_settings()
	audio.sync_settings()
	_refresh_menu_state()
	audio.play_effect(PetAudio.Effect.MENU_CLICK)

func _apply_behavior_visuals() -> void:
	if is_instance_valid(frog):
		frog.apply_behavior(behavior)

func _update_mouse_region() -> void:
	if not is_instance_valid(frog) or not is_instance_valid(swarm):
		return
	if swarm.visible:
		get_window().mouse_passthrough_polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(PET_WINDOW_SIZE.x, 0),
			Vector2(PET_WINDOW_SIZE),
			Vector2(0, PET_WINDOW_SIZE.y)
		])
	else:
		get_window().mouse_passthrough_polygon = frog.get_mouse_region()

func _on_swarm_activity_finished() -> void:
	_update_mouse_region()
	_refresh_menu_state()

func _set_window_position(target_position: Vector2) -> void:
	DisplayServer.window_set_position(Vector2i(roundi(target_position.x), roundi(target_position.y)), 0)

func _restore_window_position() -> void:
	var target := DesktopBounds.current_work_area()
	if PetSettings.has_window_position:
		for screen in range(DisplayServer.get_screen_count()):
			var usable := DisplayServer.screen_get_usable_rect(screen)
			if usable.has_point(PetSettings.window_position):
				target = usable
				break
		_set_window_position(DesktopBounds.clamp_position(PetSettings.window_position, target, PET_WINDOW_SIZE))
	else:
		_move_to_corner()

func _move_to_corner() -> void:
	var usable := DesktopBounds.current_work_area()
	var maximum := DesktopBounds.max_window_position(usable, PET_WINDOW_SIZE)
	var destination := Vector2i(maxi(usable.position.x, maximum.x - 18), maxi(usable.position.y, maximum.y - 24))
	_set_window_position(Vector2(destination))
	behavior.window_position = Vector2(destination)
	_save_settings()

func _save_settings() -> void:
	PetSettings.window_position = get_window().position
	PetSettings.has_window_position = true
	PetSettings.save_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()

func _exit_tree() -> void:
	_save_settings()

func _refresh_menu_state() -> void:
	if not menu:
		return
	menu.refresh_state(
		PetSettings.antics_enabled,
		PetSettings.always_on_top,
		PetSettings.sound_enabled,
		PetSettings.sfx_volume,
		swarm.get_clone_count()
	)
