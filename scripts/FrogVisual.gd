extends Node2D

const PetTheme = preload("res://scripts/PetTheme.gd")

var velocity := Vector2.ZERO
var is_held := false
var blink_time := 0.0
var blink_interval := 3.5
var blink_progress := 0.0
var bounce_time := 0.0

func _ready() -> void:
	randomize()

func _process(delta: float) -> void:
	blink_time += delta
	if blink_time >= blink_interval and blink_progress <= 0.0:
		blink_time = 0.0
		blink_interval = randf_range(3.0, 6.0)
		blink_progress = 1.0
	if blink_progress > 0.0:
		blink_progress = maxf(0.0, blink_progress - delta * 5.0)
	if not is_held:
		bounce_time += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_held:
		return
	velocity.y += 220.0 * delta
	position += velocity * delta
	var floor_y := 232.0
	if position.y >= floor_y:
		position.y = floor_y
		if absf(velocity.y) > 20.0:
			velocity.y *= -0.34
		else:
			velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	if position.x < 70.0 or position.x > 250.0:
		position.x = clampf(position.x, 70.0, 250.0)
		velocity.x *= -0.8

func is_point_on_pet(point: Vector2) -> bool:
	return point.distance_to(position) <= 62.0 \
		or point.distance_to(position + Vector2(-34, -42)) <= 18.0 \
		or point.distance_to(position + Vector2(34, -42)) <= 18.0

func get_mouse_region() -> PackedVector2Array:
	var c := position
	return PackedVector2Array([
		c + Vector2(-56, -34), c + Vector2(-52, -53), c + Vector2(-39, -61),
		c + Vector2(-22, -59), c + Vector2(-10, -50), c + Vector2(10, -50),
		c + Vector2(22, -59), c + Vector2(39, -61), c + Vector2(52, -53),
		c + Vector2(56, -34), c + Vector2(62, -13), c + Vector2(61, 16),
		c + Vector2(51, 42), c + Vector2(32, 58), c + Vector2(0, 64),
		c + Vector2(-32, 58), c + Vector2(-51, 42), c + Vector2(-61, 16),
		c + Vector2(-62, -13)
	])

func set_held(value: bool, release_velocity := Vector2.ZERO) -> void:
	is_held = value
	velocity = Vector2.ZERO if value else release_velocity
	if not value and velocity.is_zero_approx():
		velocity.y = -105.0

func _draw() -> void:
	var bob := sin(bounce_time * 2.0) * 2.0 if not is_held else 0.0
	var center := Vector2(0, bob)
	_draw_filled_oval(center + Vector2(0, 63), Vector2(68, 11), PetTheme.SHADOW)
	draw_circle(center + Vector2(0, 2), 64, PetTheme.BODY_DARK)
	draw_circle(center, 60, PetTheme.BODY)
	draw_circle(center + Vector2(-34, -41), 18, PetTheme.BODY)
	draw_circle(center + Vector2(34, -41), 18, PetTheme.BODY)
	draw_circle(center + Vector2(-34, -42), 8, PetTheme.CREAM)
	draw_circle(center + Vector2(34, -42), 8, PetTheme.CREAM)
	var eye_height := 3.0 if blink_progress > 0.0 else 13.0
	_draw_filled_oval(center + Vector2(-22, -7), Vector2(9, eye_height), PetTheme.INK)
	_draw_filled_oval(center + Vector2(22, -7), Vector2(9, eye_height), PetTheme.INK)
	_draw_filled_oval(center + Vector2(0, 23), Vector2(27, 12), PetTheme.CREAM)
	draw_arc(center + Vector2(0, 21), 17, 0.15, PI - 0.15, 24, PetTheme.INK, 4.0)
	draw_circle(center + Vector2(0, 30), 4, PetTheme.INK)

func _draw_filled_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
