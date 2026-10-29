extends Node2D

signal activity_finished

const FROG_CLONE_SCENE := preload("res://scenes/FrogClone.tscn")
const MAX_CLONES := 50

var clone_container: Node2D
var simulation_enabled := true
var remaining_seconds := 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	remaining_seconds -= delta
	if remaining_seconds <= 0.0:
		clear()

func _ready() -> void:
	clone_container = Node2D.new()
	clone_container.name = "Clones"
	add_child(clone_container)
	_create_wall(Vector2(160.0, 306.0), Vector2(320.0, 20.0))
	_create_wall(Vector2(7.0, 160.0), Vector2(14.0, 320.0))
	_create_wall(Vector2(313.0, 160.0), Vector2(14.0, 320.0))
	visible = false

func spawn() -> int:
	clear()
	visible = true
	remaining_seconds = 15.0
	for index in range(MAX_CLONES):
		var clone := FROG_CLONE_SCENE.instantiate() as RigidBody2D
		clone.position = Vector2(randf_range(18.0, 302.0), randf_range(-180.0, 35.0))
		clone.rotation = randf_range(-0.25, 0.25)
		clone.freeze = not simulation_enabled
		clone_container.add_child(clone)
	return clone_container.get_child_count()

func clear() -> void:
	if not is_instance_valid(clone_container):
		return
	var had_activity := visible or not clone_container.get_children().is_empty()
	for clone in clone_container.get_children():
		clone_container.remove_child(clone)
		clone.free()
	visible = false
	remaining_seconds = 0.0
	if had_activity:
		activity_finished.emit()

func get_clone_count() -> int:
	return clone_container.get_child_count() if is_instance_valid(clone_container) else 0

func kick_near(target_position: Vector2, impulse: Vector2) -> void:
	if not simulation_enabled:
		return
	for body: RigidBody2D in clone_container.get_children():
		var distance: float = body.position.distance_to(target_position)
		if distance <= 90.0:
			var direction: Vector2 = (body.position - target_position).normalized()
			body.apply_central_impulse(direction * (1.0 - distance / 90.0) * impulse.length() + impulse * 0.18)

func set_simulation_enabled(value: bool) -> void:
	simulation_enabled = value
	for body: RigidBody2D in clone_container.get_children():
		body.freeze = not simulation_enabled

func _create_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	wall.add_child(shape_node)
	add_child(wall)
