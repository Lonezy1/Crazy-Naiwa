extends Node

signal activity_changed(active: bool)
signal fleet_changed
signal drag_started
signal drag_released

const PetCollisionWorld = preload("res://scripts/entities/PetCollisionWorld.gd")
const PetGesture = preload("res://scripts/input/PetGesture.gd")
const PetContextMenu = preload("res://scripts/ui/PetContextMenu.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const PetAudio = preload("res://scripts/audio/PetAudio.gd")
const FROG_WINDOW_SCENE = preload("res://scenes/FrogPetWindow.tscn")
const BASE_SIZE := 320
const MIN_SIZE := 48
const MAX_SIZE := 640
const MAX_SMALL_PETS := 100

var world := PetCollisionWorld.new()
var collision_strength := 1.0
var collisions_enabled := true
var _windows: Dictionary = {}
var _visuals: Dictionary = {}
var _swarm: Node2D
var _behavior: PetBehavior
var _audio: Node
var _settings: Node
var _next_id := 1
var _pointer_id := -1
var _pointer_down := false
var _gesture := PetGesture.new()
var _active := false
var _state_dirty := false

func initialize_primary(pet_window: Window, visual: Node2D, behavior: PetBehavior, swarm: Node2D, audio: Node) -> void:
	_settings = get_node("/root/PetSettings")
	_behavior = behavior
	_swarm = swarm
	_audio = audio
	collisions_enabled = _settings.collisions_enabled
	collision_strength = _settings.collision_strength
	world.collisions_enabled = collisions_enabled
	world.collision_strength = collision_strength
	_windows[0] = pet_window
	_visuals[0] = visual
	var size := clampi(_settings.frog_size, MIN_SIZE, MAX_SIZE)
	var position := Vector2(pet_window.position)
	world.add_body(0, size, position, _work_area_for_position(position, size))
	_apply_size(0, size)

func restore_small_pets(saved_pets: Array[Dictionary]) -> void:
	var restored := 0
	for saved_pet in saved_pets:
		if restored >= MAX_SMALL_PETS:
			break
		var id := int(saved_pet.get("id", 0))
		var size := clampi(int(saved_pet.get("size", MIN_SIZE)), MIN_SIZE, MAX_SIZE)
		var saved_position: Variant = saved_pet.get("position", Vector2i.ZERO)
		if id <= 0 or world.get_body(id).size() > 0 or not (saved_position is Vector2i):
			continue
		var position := Vector2(saved_position)
		var area := _work_area_for_position(position, size)
		position = _clamp_window_position(position, area, size)
		_create_pet(id, size, position, area)
		_next_id = maxi(_next_id, id + 1)
		restored += 1
	if restored > 0:
		_set_active(true)
		_refresh_all_menus()
		_persist_state()

func spawn_smaller(parent_id: int) -> int:
	if get_small_pet_count() >= MAX_SMALL_PETS:
		return -1
	var parent := world.get_body(parent_id)
	if parent.is_empty():
		return -1
	var size := maxi(MIN_SIZE, floori(float(parent["size"]) * 0.8))
	var parent_position: Vector2 = parent["position"]
	var area: Rect2i = parent["work_area"]
	var position := _find_spawn_position(parent_position, int(parent["size"]), size, area)
	var id := _next_id
	_next_id += 1
	_create_pet(id, size, position, area)
	_set_active(true)
	_refresh_all_menus()
	_persist_state()
	return id

func clear_small_pets() -> void:
	var ids: Array[int] = []
	for body in world.bodies:
		var id := int(body["id"])
		if id != 0:
			ids.append(id)
	for id in ids:
		remove_pet(id, false)
	if not ids.is_empty():
		_set_active(false)
		_refresh_all_menus()
		_persist_state()

func remove_pet(id: int, persist: bool = true) -> void:
	if id == 0 or world.get_body(id).is_empty():
		return
	world.remove_body(id)
	_visuals.erase(id)
	var pet_window: Window = _windows.get(id)
	_windows.erase(id)
	if is_instance_valid(pet_window):
		pet_window.queue_free()
	if _pointer_id == id:
		_cancel_pointer()
	if get_small_pet_count() == 0:
		_set_active(false)
	_refresh_all_menus()
	if persist:
		_persist_state()

func set_pet_size(id: int, size: int) -> void:
	if world.get_body(id).is_empty():
		return
	size = clampi(size, MIN_SIZE, MAX_SIZE)
	world.set_size(id, size)
	_apply_size(id, size)
	_refresh_all_menus()
	_persist_state()

func set_collisions_enabled(value: bool) -> void:
	collisions_enabled = value
	world.collisions_enabled = value
	_refresh_all_menus()
	_persist_state()

func set_collision_strength(value: float) -> void:
	collision_strength = clampf(value, 0.5, 1.25)
	world.collision_strength = collision_strength
	_refresh_all_menus()
	_persist_state()

func handle_pet_command(pet_id: int, command: int) -> void:
	match command:
		PetContextMenu.Command.SPAWN_SMALL_PET:
			spawn_smaller(pet_id)
		PetContextMenu.Command.CLEAR_SMALL_PETS:
			clear_small_pets()
		PetContextMenu.Command.REMOVE_THIS_PET:
			remove_pet(pet_id)
	_refresh_all_menus()

func pointer_press(id: int, pointer_position: Vector2) -> void:
	if not _active or _pointer_down or world.get_body(id).is_empty():
		return
	_pointer_id = id
	_pointer_down = true
	_gesture.begin(pointer_position)

func pointer_release(pointer_position: Vector2) -> void:
	if not _pointer_down:
		return
	var result := _gesture.end(pointer_position)
	if bool(result["started_drag"]):
		_start_drag(pointer_position)
	if bool(result["dragging"]):
		var collided_ids := world.finish_drag(_pointer_id, pointer_position, _all_work_areas())
		for id in collided_ids:
			var collided_visual: Node2D = _visuals.get(id)
			if is_instance_valid(collided_visual):
				collided_visual.call("play_impact")
		world.release_drag(_pointer_id)
		drag_released.emit()
		_state_dirty = true
		_sync_windows()
	else:
		var visual: Node2D = _visuals.get(_pointer_id)
		if is_instance_valid(visual):
			visual.call("play_impact")
	_cancel_pointer()

func has_active_pointer() -> bool:
	return _pointer_down

func is_active() -> bool:
	return _active

func get_small_pet_count() -> int:
	return maxi(0, world.bodies.size() - 1)

func refresh_menu(menu: PetContextMenu, clone_count: int = 0) -> void:
	menu.refresh_state(
		_settings.antics_enabled,
		_settings.always_on_top,
		_settings.sound_enabled,
		_settings.sfx_volume,
		clone_count,
		_settings.long_press_mode,
		int(world.get_body(0).get("size", BASE_SIZE)),
		get_small_pet_count(),
		collisions_enabled,
		collision_strength,
		get_small_pet_count() < MAX_SMALL_PETS
	)

func persist_state() -> void:
	_persist_state()

func pointer_move(pointer_position: Vector2) -> void:
	if _pointer_down:
		world.move_drag(_pointer_id, pointer_position)

func set_always_on_top(value: bool) -> void:
	for pet_window: Window in _windows.values():
		if is_instance_valid(pet_window):
			pet_window.always_on_top = value

func sync_primary_position(position: Vector2) -> void:
	var body := world.get_body(0)
	if body.is_empty():
		return
	body["position"] = position
	body["drag_target"] = position
	body["work_area"] = _work_area_for_position(position, int(body["size"]))

func _process(delta: float) -> void:
	if not _active or world.bodies.size() < 2:
		return
	if _pointer_down:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pointer_release(DisplayServer.mouse_get_position())
			return
		var pointer_position := Vector2(DisplayServer.mouse_get_position())
		var result := _gesture.advance(pointer_position)
		if bool(result["started_drag"]):
			_start_drag(pointer_position)
		if bool(result["dragging"]):
			world.move_drag(_pointer_id, pointer_position)
	var collided_ids := world.advance(delta, _all_work_areas())
	if not collided_ids.is_empty():
		_state_dirty = true
	for id in collided_ids:
		var visual: Node2D = _visuals.get(id)
		if is_instance_valid(visual):
			visual.call("play_impact")
	_sync_windows()
	if _state_dirty and not world.has_motion():
		_state_dirty = false
		_persist_state()

func _create_pet(id: int, size: int, position: Vector2, area: Rect2i) -> void:
	var pet_window := FROG_WINDOW_SCENE.instantiate() as Window
	pet_window.call("configure", self, id, size)
	pet_window.visible = false
	pet_window.position = Vector2i(roundi(position.x), roundi(position.y))
	get_tree().root.add_child(pet_window)
	pet_window.position = Vector2i(roundi(position.x), roundi(position.y))
	pet_window.visible = true
	_windows[id] = pet_window
	_visuals[id] = pet_window.get("visual")
	world.add_body(id, size, position, area)

func _apply_size(id: int, size: int) -> void:
	var body := world.get_body(id)
	var pet_window: Window = _windows.get(id)
	var visual: Node2D = _visuals.get(id)
	if body.is_empty() or not is_instance_valid(pet_window) or not is_instance_valid(visual):
		return
	pet_window.content_scale_size = Vector2i(size, size)
	pet_window.size = Vector2i(size, size)
	pet_window.position = Vector2i(roundi(Vector2(body["position"]).x), roundi(Vector2(body["position"]).y))
	if id == 0:
		if is_instance_valid(_swarm):
			_swarm.scale = Vector2.ONE * (float(size) / float(BASE_SIZE))
		if is_instance_valid(_behavior):
			_behavior.window_position = body["position"]
	visual.position = Vector2(size * 0.55, size * 0.51)
	visual.call("set_display_size_scale", float(size) / float(BASE_SIZE))
	if id == 0 and is_instance_valid(_swarm) and _swarm.visible:
		pet_window.mouse_passthrough_polygon = PackedVector2Array([
			Vector2.ZERO, Vector2(size, 0), Vector2(size, size), Vector2(0, size)
		])
	else:
		pet_window.mouse_passthrough_polygon = visual.call("get_mouse_region")
	if id != 0:
		pet_window.call("refresh_menu_state", get_small_pet_count(), collisions_enabled, collision_strength)

func _start_drag(pointer_position: Vector2) -> void:
	if world.begin_drag(_pointer_id, pointer_position):
		var visual: Node2D = _visuals.get(_pointer_id)
		if is_instance_valid(visual):
			visual.call("set_dragging", true)
		if is_instance_valid(_audio):
			_audio.call("play_effect", PetAudio.Effect.GRAB_START)
		drag_started.emit()

func _cancel_pointer() -> void:
	var visual: Node2D = _visuals.get(_pointer_id)
	if is_instance_valid(visual):
		visual.call("set_dragging", false)
	_pointer_down = false
	_pointer_id = -1
	_gesture.reset()

func _sync_windows() -> void:
	for body in world.bodies:
		var id := int(body["id"])
		var position: Vector2 = body["position"]
		var pet_window: Window = _windows.get(id)
		if is_instance_valid(pet_window):
			pet_window.position = Vector2i(roundi(position.x), roundi(position.y))
		if id == 0 and is_instance_valid(_behavior):
			_behavior.window_position = position

func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	activity_changed.emit(value)

func _find_spawn_position(parent_position: Vector2, parent_size: int, child_size: int, area: Rect2i) -> Vector2:
	var parent_center := parent_position + Vector2(parent_size, parent_size) * 0.5
	var child_radius := float(child_size) * PetCollisionWorld.RADIUS_RATIO
	var parent_radius := float(parent_size) * PetCollisionWorld.RADIUS_RATIO
	var distance := parent_radius + child_radius + 10.0
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()]
	var best_position := parent_position
	var least_overlap := INF
	for direction in directions:
		var candidate := _clamp_window_position(parent_center + direction * distance - Vector2(child_size, child_size) * 0.5, area, child_size)
		var overlap := 0.0
		for body in world.bodies:
			var other_size := int(body["size"])
			var other_center: Vector2 = Vector2(body["position"]) + Vector2(other_size, other_size) * 0.5
			var gap := candidate + Vector2(child_size, child_size) * 0.5 - other_center
			var penetration := float(child_size + other_size) * PetCollisionWorld.RADIUS_RATIO - gap.length()
			overlap += maxf(0.0, penetration)
		if overlap < least_overlap:
			best_position = candidate
			least_overlap = overlap
		if is_zero_approx(overlap):
			return candidate
	return best_position

func _all_work_areas() -> Array[Rect2i]:
	var areas: Array[Rect2i] = []
	for screen in range(DisplayServer.get_screen_count()):
		areas.append(DisplayServer.screen_get_usable_rect(screen))
	return areas

func _work_area_for_position(position: Vector2, size: int) -> Rect2i:
	var center := position + Vector2(size, size) * 0.5
	for area in _all_work_areas():
		if area.has_point(Vector2i(roundi(center.x), roundi(center.y))):
			return area
	return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())

func _clamp_window_position(position: Vector2, area: Rect2i, size: int) -> Vector2:
	var maximum := Vector2(maxi(area.position.x, area.end.x - size), maxi(area.position.y, area.end.y - size))
	return Vector2(clampf(position.x, area.position.x, maximum.x), clampf(position.y, area.position.y, maximum.y))

func _refresh_all_menus() -> void:
	fleet_changed.emit()
	for id in _windows:
		if id == 0:
			continue
		var pet_window: Window = _windows[id]
		if is_instance_valid(pet_window):
			pet_window.call("refresh_menu_state", get_small_pet_count(), collisions_enabled, collision_strength)

func _persist_state() -> void:
	var saved_pets: Array[Dictionary] = []
	for body in world.bodies:
		var id := int(body["id"])
		if id == 0:
			continue
		var pet_window: Window = _windows.get(id)
		var position: Vector2 = body["position"]
		if is_instance_valid(pet_window):
			position = Vector2(pet_window.position)
		saved_pets.append({
			"id": id,
			"size": int(body["size"]),
			"position": Vector2i(roundi(position.x), roundi(position.y)),
		})
	_settings.frog_size = int(world.get_body(0).get("size", BASE_SIZE))
	var primary_window: Window = _windows.get(0)
	if is_instance_valid(primary_window):
		_settings.window_position = primary_window.position
		_settings.has_window_position = true
	_settings.frog_instances = saved_pets
	_settings.collisions_enabled = collisions_enabled
	_settings.collision_strength = collision_strength
	_settings.save_settings()
