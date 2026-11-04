extends Window

const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const FrogVisualScene = preload("res://scenes/FrogVisual.tscn")
const BASE_SIZE := 320

var fleet: Node
var pet_id := -1
var pet_size := BASE_SIZE
var visual: Node2D
var menu: PetContextMenu
var settings: Node

func configure(owner_fleet: Node, id: int, size: int) -> void:
	fleet = owner_fleet
	pet_id = id
	pet_size = size

func _ready() -> void:
	settings = get_node("/root/PetSettings")
	transparent = true
	borderless = true
	always_on_top = settings.always_on_top
	transparent_bg = true
	visible = false
	visual = FrogVisualScene.instantiate() as Node2D
	visual.name = "Frog"
	add_child(visual)
	_apply_size()
	_build_menu()
	close_requested.connect(_on_close_requested)

func set_pet_size(size: int) -> void:
	pet_size = size
	_apply_size()

func sync_position(position: Vector2) -> void:
	self.position = Vector2i(roundi(position.x), roundi(position.y))

func refresh_menu_state(small_pet_count: int, collisions_enabled: bool, collision_strength: float) -> void:
	if menu:
		menu.refresh_state(
			settings.antics_enabled,
			settings.always_on_top,
			settings.sound_enabled,
			settings.sfx_volume,
			0,
			settings.long_press_mode,
			pet_size,
			small_pet_count,
			collisions_enabled,
			collision_strength,
			small_pet_count < 100
		)

func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		refresh_menu_state(fleet.get_small_pet_count(), fleet.collisions_enabled, fleet.collision_strength)
		menu.position = DisplayServer.mouse_get_position()
		menu.popup()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and visual.is_point_on_pet(event.position):
			fleet.pointer_press(pet_id, DisplayServer.mouse_get_position())
			get_viewport().set_input_as_handled()
		elif not event.pressed and fleet.has_active_pointer():
			fleet.pointer_release(DisplayServer.mouse_get_position())
			get_viewport().set_input_as_handled()

func _build_menu() -> void:
	menu = PetContextMenu.new()
	menu.fleet_only = true
	menu.command_selected.connect(_on_command_selected)
	menu.fleet_command_selected.connect(_on_fleet_command_selected)
	menu.size_selected.connect(_on_size_selected)
	menu.collision_enabled_selected.connect(_on_collision_enabled_selected)
	menu.collision_strength_selected.connect(_on_collision_strength_selected)
	add_child(menu)
	refresh_menu_state(fleet.get_small_pet_count(), fleet.collisions_enabled, fleet.collision_strength)

func _apply_size() -> void:
	content_scale_size = Vector2i(pet_size, pet_size)
	size = Vector2i(pet_size, pet_size)
	if not is_instance_valid(visual):
		return
	visual.position = Vector2(pet_size * 0.55, pet_size * 0.51)
	visual.set_display_size_scale(float(pet_size) / float(BASE_SIZE))
	_update_mouse_region()

func _update_mouse_region() -> void:
	if is_instance_valid(visual):
		mouse_passthrough_polygon = visual.get_mouse_region()

func _on_command_selected(command: int) -> void:
	match command:
		PetContextMenu.Command.QUIT:
			fleet.remove_pet(pet_id)

func _on_fleet_command_selected(command: int) -> void:
	fleet.handle_pet_command(pet_id, command)

func _on_size_selected(size_value: int) -> void:
	fleet.set_pet_size(pet_id, size_value)

func _on_collision_enabled_selected(enabled: bool) -> void:
	fleet.set_collisions_enabled(enabled)

func _on_collision_strength_selected(strength: float) -> void:
	fleet.set_collision_strength(strength)

func _on_close_requested() -> void:
	fleet.remove_pet(pet_id)
