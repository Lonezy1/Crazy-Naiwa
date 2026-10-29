extends Node2D

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetTheme = preload("res://scripts/ui/PetTheme.gd")
const PET_WINDOW_SIZE := Vector2i(320, 320)

var behavior := PetBehavior.new()
var frog: Node2D
var swarm: Node2D
var effects: CanvasGroup
var menu: PopupMenu
var pointer_held := false
var pointer_was_on_pet := false
var dragging := false
var drag_screen_origin := Vector2.ZERO
var drag_window_origin := Vector2.ZERO

func _ready() -> void:
	Engine.max_fps = 30
	var pet_window := get_window()
	pet_window.transparent = true
	pet_window.borderless = true
	pet_window.always_on_top = PetSettings.always_on_top
	pet_window.size = PET_WINDOW_SIZE
	frog = $FrogEffects/Frog
	swarm = $PetSwarm
	effects = $FrogEffects
	_restore_window_position()
	behavior.set_enabled(PetSettings.antics_enabled)
	behavior.tongue_enabled = true
	behavior.initialize(Vector2(pet_window.position))
	swarm.set_simulation_enabled(PetSettings.antics_enabled)
	frog.set_pointer_position(get_viewport().get_mouse_position())
	_build_menu()
	_apply_behavior_visuals()
	_apply_pixelation()
	_update_mouse_region()
	swarm.activity_finished.connect(_on_swarm_activity_finished)

func _process(delta: float) -> void:
	var pointer_position := get_viewport().get_mouse_position()
	frog.set_pointer_position(pointer_position)
	_update_pointer_activity(pointer_position, false)
	var work_area := DesktopBounds.current_work_area()
	if not pointer_held:
		var events := behavior.advance(delta, work_area, PET_WINDOW_SIZE)
		if events.corner_hit:
			frog.play_blink()
		if events.tongue_started:
			frog.play_blink()
		if events.landed:
			frog.play_impact()
		_set_window_position(behavior.window_position)
	_apply_behavior_visuals()
	_apply_pixelation()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		frog.set_pointer_position(event.position)
		_update_pointer_activity(event.position, not event.relative.is_zero_approx())
		if swarm.visible and not event.relative.is_zero_approx():
			swarm.kick_near(event.position, event.relative * 2.4)
		if pointer_held:
			var screen_mouse := Vector2(DisplayServer.mouse_get_position())
			var movement := screen_mouse - drag_screen_origin
			if not dragging and movement.length() >= 5.0:
				dragging = true
			if dragging:
				behavior.move_drag(drag_window_origin + movement, screen_mouse)
				_set_window_position(behavior.window_position)
				_apply_behavior_visuals()
				get_viewport().set_input_as_handled()
		elif behavior.tongue_seconds > 0.0:
			if behavior.add_tongue_wiggle(event.relative.length()):
				frog.play_blink()
			_apply_behavior_visuals()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			menu.position = DisplayServer.mouse_get_position()
			menu.popup()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and frog.is_point_on_pet(event.position):
				pointer_held = true
				dragging = false
				drag_screen_origin = Vector2(DisplayServer.mouse_get_position())
				drag_window_origin = Vector2(get_window().position)
				behavior.begin_drag(drag_screen_origin)
				frog.set_held(true)
			elif event.pressed and swarm.visible:
				swarm.kick_near(event.position, Vector2(0.0, -120.0))
			elif not event.pressed and pointer_held:
				pointer_held = false
				frog.set_held(false)
				if dragging:
					behavior.end_drag(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
					_save_settings()
				else:
					var result := behavior.poke(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
					if result.burst:
						frog.play_burst()
					elif result.heavy_fall:
						frog.play_impact()
				_apply_behavior_visuals()
				_apply_pixelation()
				_update_mouse_region()
				get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		behavior.dismiss_tongue()
		_apply_behavior_visuals()

func _build_menu() -> void:
	menu = PopupMenu.new()
	menu.theme = PetTheme.create_popup_theme()
	menu.add_item("DVD 弹跳", 1)
	menu.add_item("立即蛄蛹", 2)
	menu.add_item("飘到顶端再坠落", 3)
	menu.add_separator()
	menu.add_item("分裂 50 只", 4)
	menu.add_item("清理分身", 5)
	menu.add_separator()
	menu.add_check_item("暂停整活", 6)
	menu.add_check_item("总在最上面", 7)
	menu.add_separator()
	menu.add_item("回到屏幕右下角", 8)
	menu.add_item("退出奶蛙", 9)
	menu.id_pressed.connect(_on_menu_pressed)
	add_child(menu)
	_apply_menu_state()

func _on_menu_pressed(id: int) -> void:
	match id:
		1:
			behavior.start_dvd_bounce()
		2:
			behavior.start_slither(DesktopBounds.current_work_area(), PET_WINDOW_SIZE)
		3:
			behavior.start_float()
		4:
			swarm.set_simulation_enabled(PetSettings.antics_enabled)
			swarm.spawn()
			_update_mouse_region()
		5:
			swarm.clear()
			_update_mouse_region()
		6:
			PetSettings.antics_enabled = not PetSettings.antics_enabled
			behavior.set_enabled(PetSettings.antics_enabled)
			swarm.set_simulation_enabled(PetSettings.antics_enabled)
			PetSettings.save_settings()
			_apply_menu_state()
		7:
			PetSettings.always_on_top = not PetSettings.always_on_top
			get_window().always_on_top = PetSettings.always_on_top
			PetSettings.save_settings()
			_apply_menu_state()
		8:
			_move_to_corner()
		9:
			_save_settings()
			get_tree().quit()
	_apply_behavior_visuals()

func _apply_behavior_visuals() -> void:
	if is_instance_valid(frog):
		frog.apply_behavior(behavior)

func _apply_pixelation() -> void:
	if not is_instance_valid(effects) or not effects.material is ShaderMaterial:
		return
	var material := effects.material as ShaderMaterial
	material.set_shader_parameter("pixel_size", lerpf(1.0, 10.0, behavior.pixelation_amount))

func _update_pointer_activity(position: Vector2, pointer_moved: bool) -> void:
	var pointer_on_pet: bool = frog.is_point_on_pet(position)
	if pointer_on_pet and (not pointer_was_on_pet or pointer_moved):
		var restored := behavior.wake_up()
		if restored:
			frog.play_blink()
			_apply_pixelation()
	pointer_was_on_pet = pointer_on_pet

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

func _set_window_position(position: Vector2) -> void:
	get_window().position = Vector2i(roundi(position.x), roundi(position.y))

func _restore_window_position() -> void:
	var target := DesktopBounds.current_work_area()
	if PetSettings.has_window_position:
		for screen in range(DisplayServer.get_screen_count()):
			var usable := DisplayServer.screen_get_usable_rect(screen)
			if usable.has_point(PetSettings.window_position):
				target = usable
				break
		get_window().position = DesktopBounds.clamp_position(PetSettings.window_position, target, PET_WINDOW_SIZE)
	else:
		_move_to_corner()

func _move_to_corner() -> void:
	var usable := DesktopBounds.current_work_area()
	var maximum := DesktopBounds.max_window_position(usable, PET_WINDOW_SIZE)
	var destination := Vector2i(maxi(usable.position.x, maximum.x - 18), maxi(usable.position.y, maximum.y - 24))
	get_window().position = destination
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

func _apply_menu_state() -> void:
	if not menu:
		return
	menu.set_item_checked(menu.get_item_index(6), not PetSettings.antics_enabled)
	menu.set_item_checked(menu.get_item_index(7), PetSettings.always_on_top)
