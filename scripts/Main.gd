extends Node2D

const PetTheme = preload("res://scripts/PetTheme.gd")

var frog: Node2D
var pointer_held := false
var is_dragging_window := false
var press_screen_position := Vector2i.ZERO
var window_start_position := Vector2i.ZERO
var last_drag_delta := Vector2.ZERO
var menu: PopupMenu

func _ready() -> void:
	Engine.max_fps = 30
	var pet_window := get_window()
	pet_window.transparent = true
	pet_window.borderless = true
	pet_window.always_on_top = PetSettings.always_on_top
	frog = $Frog
	_restore_window_position()
	menu = PopupMenu.new()
	menu.theme = PetTheme.create_popup_theme()
	menu.add_item("回到屏幕右下角", 1)
	menu.add_separator()
	menu.add_check_item("总在最上面", 2)
	menu.add_item("退出奶蛙", 9)
	menu.id_pressed.connect(_on_menu_pressed)
	add_child(menu)
	_apply_menu_state()
	_update_mouse_region()

func _process(_delta: float) -> void:
	_update_mouse_region()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			menu.position = DisplayServer.mouse_get_position()
			menu.popup()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and frog.is_point_on_pet(event.position):
				pointer_held = true
				press_screen_position = DisplayServer.mouse_get_position()
				window_start_position = get_window().position
				last_drag_delta = Vector2.ZERO
				frog.set_held(true)
			elif not event.pressed and pointer_held:
				pointer_held = false
				if is_dragging_window:
					frog.set_held(false, Vector2(clampf(last_drag_delta.x * 4.0, -100.0, 100.0), -55.0))
					_save_settings()
				else:
					frog.set_held(false)
				is_dragging_window = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_held:
		var current_screen_position := DisplayServer.mouse_get_position()
		var movement := current_screen_position - press_screen_position
		if not is_dragging_window and movement.length() >= 4.0:
			is_dragging_window = true
		if is_dragging_window:
			get_window().position = window_start_position + movement
			last_drag_delta = event.relative
			get_viewport().set_input_as_handled()

func _update_mouse_region() -> void:
	if is_instance_valid(frog):
		get_window().mouse_passthrough_polygon = frog.get_mouse_region()

func _restore_window_position() -> void:
	var screen_count := DisplayServer.get_screen_count()
	var target_screen := DisplayServer.window_get_current_screen()
	var target := DisplayServer.screen_get_usable_rect(target_screen)
	var restored := false
	if PetSettings.has_window_position:
		for screen in range(screen_count):
			var usable := DisplayServer.screen_get_usable_rect(screen)
			if usable.has_point(PetSettings.window_position):
				target = usable
				restored = true
				break
	if restored:
		var max_position := target.end - get_window().size
		get_window().position = Vector2i(
			clampi(PetSettings.window_position.x, target.position.x, maxi(target.position.x, max_position.x)),
			clampi(PetSettings.window_position.y, target.position.y, maxi(target.position.y, max_position.y))
		)
	else:
		var max_position := target.end - get_window().size
		get_window().position = Vector2i(
			maxi(target.position.x, max_position.x - 18),
			maxi(target.position.y, max_position.y - 24)
		)

func _save_settings() -> void:
	PetSettings.window_position = get_window().position
	PetSettings.has_window_position = true
	PetSettings.save_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()

func _exit_tree() -> void:
	_save_settings()

func _on_menu_pressed(id: int) -> void:
	match id:
		1:
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var max_position := usable.end - get_window().size
			get_window().position = Vector2i(
				maxi(usable.position.x, max_position.x - 18),
				maxi(usable.position.y, max_position.y - 24)
			)
			_save_settings()
		2:
			PetSettings.always_on_top = not PetSettings.always_on_top
			get_window().always_on_top = PetSettings.always_on_top
			PetSettings.save_settings()
			_apply_menu_state()
		9:
			get_tree().quit()

func _apply_menu_state() -> void:
	if menu:
		menu.set_item_checked(menu.get_item_index(2), PetSettings.always_on_top)
