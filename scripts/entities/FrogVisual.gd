extends Node2D

const PetTheme = preload("res://scripts/ui/PetTheme.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const MAX_VISIBLE_INFLATION := 1.8

var velocity := Vector2.ZERO
var mode := PetBehavior.Mode.DVD_BOUNCE
var inflation_scale := 1.0
var tongue_seconds := 0.0
var impact_seconds := 0.0
var corner_flash_seconds := 0.0
var burst_seconds := 0.0
var drag_vector := Vector2.ZERO
var blink_seconds := 0.0
var idle_phase := 0.0
var pointer_local := Vector2.ZERO
var is_held := false
var is_hovered := false
var base_scale := Vector2.ONE

func _ready() -> void:
	base_scale = scale

func _process(delta: float) -> void:
	idle_phase += delta
	tongue_seconds = maxf(0.0, tongue_seconds - delta)
	impact_seconds = maxf(0.0, impact_seconds - delta)
	corner_flash_seconds = maxf(0.0, corner_flash_seconds - delta)
	burst_seconds = maxf(0.0, burst_seconds - delta)
	blink_seconds = maxf(0.0, blink_seconds - delta)
	queue_redraw()

func apply_behavior(state: PetBehavior) -> void:
	mode = state.mode
	velocity = state.velocity
	var inflation_progress := float(state.inflation_hits) / float(PetBehavior.MAX_POKE_COUNT - 1)
	inflation_scale = lerpf(1.0, MAX_VISIBLE_INFLATION, clampf(inflation_progress, 0.0, 1.0))
	scale = base_scale * inflation_scale
	tongue_seconds = state.tongue_seconds
	impact_seconds = state.impact_seconds
	corner_flash_seconds = state.corner_flash_seconds
	drag_vector = state.drag_total

func set_pointer_position(viewport_position: Vector2) -> void:
	pointer_local = to_local(viewport_position)
	is_hovered = is_point_on_pet(viewport_position)
	queue_redraw()

func play_burst() -> void:
	burst_seconds = 0.65
	play_blink()
	queue_redraw()

func play_impact() -> void:
	impact_seconds = 0.42
	queue_redraw()

func is_point_on_pet(viewport_position: Vector2) -> bool:
	var point := to_local(viewport_position)
	return point.length() <= 64.0 or point.distance_to(Vector2(-34.0, -42.0)) <= 18.0 \
		or point.distance_to(Vector2(34.0, -42.0)) <= 18.0

func get_mouse_region() -> PackedVector2Array:
	var local_points := PackedVector2Array([
		Vector2(-56, -34), Vector2(-52, -53), Vector2(-39, -61),
		Vector2(-22, -59), Vector2(-10, -50), Vector2(10, -50),
		Vector2(22, -59), Vector2(39, -61), Vector2(52, -53),
		Vector2(56, -34), Vector2(62, -13), Vector2(61, 16),
		Vector2(51, 42), Vector2(32, 58), Vector2(0, 64),
		Vector2(-32, 58), Vector2(-51, 42), Vector2(-61, 16), Vector2(-62, -13)
	])
	var window_points := PackedVector2Array()
	for point in local_points:
		window_points.append(to_global(point))
	return window_points

func set_held(value: bool) -> void:
	is_held = value

func play_blink() -> void:
	blink_seconds = 0.18

func _draw() -> void:
	var breathing := sin(idle_phase * 2.0) * 0.025
	var stretch := 0.0
	var squish := 0.0
	var tilt := 0.0
	match mode:
		PetBehavior.Mode.SLITHER:
			stretch = 0.12 * sin((idle_phase + velocity.x * 0.001) * 12.0)
			squish = -absf(stretch) * 0.8
			tilt = 0.08 * sin(idle_phase * 6.0)
		PetBehavior.Mode.FLOAT:
			tilt = sin(idle_phase * 1.4) * 0.04
			squish = sin(idle_phase * 2.0) * 0.025
		PetBehavior.Mode.FALL, PetBehavior.Mode.LAUNCH:
			stretch = clampf(absf(velocity.y) / 1500.0, 0.0, 0.26)
			squish = -stretch * 0.58
			tilt = clampf(velocity.x / 1800.0, -0.18, 0.18)
		PetBehavior.Mode.DRAG:
			stretch = clampf(drag_vector.length() / 400.0, 0.0, 0.42)
			tilt = clampf(drag_vector.x / 450.0, -0.28, 0.28)
		PetBehavior.Mode.DVD_BOUNCE:
			tilt = clampf(velocity.x / 2800.0, -0.08, 0.08)
	var scale_x := 1.0 + breathing + stretch - squish * 0.4
	var scale_y := 1.0 - breathing - stretch * 0.48 + squish
	if impact_seconds > 0.0:
		var impact := sin((0.42 - impact_seconds) * 24.0) * (impact_seconds / 0.42)
		scale_x *= 1.0 + impact * 0.23
		scale_y *= 1.0 - impact * 0.19
	var transform := Transform2D(tilt, Vector2(scale_x, scale_y), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(transform)
	_draw_frog()
	if is_held:
		_draw_tether()
	elif tongue_seconds > 0.0:
		_draw_tongue()
	if corner_flash_seconds > 0.0:
		_draw_corner_burst()
	if burst_seconds > 0.0:
		_draw_burst()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frog() -> void:
	var gaze := (pointer_local / 500.0).limit_length(1.0) * 3.5
	_draw_filled_oval(Vector2(0, 63), Vector2(68, 11), PetTheme.SHADOW)
	if impact_seconds > 0.0:
		draw_circle(Vector2.ZERO, 67, PetTheme.HOVER)
	elif is_hovered or is_held:
		draw_circle(Vector2.ZERO, 67, PetTheme.HOVER)
	draw_circle(Vector2(0, 2), 64, PetTheme.BODY_DARK)
	draw_circle(Vector2.ZERO, 60, PetTheme.BODY)
	draw_circle(Vector2(-34, -41), 18, PetTheme.BODY)
	draw_circle(Vector2(34, -41), 18, PetTheme.BODY)
	draw_circle(Vector2(-34, -42), 8, PetTheme.CREAM)
	draw_circle(Vector2(34, -42), 8, PetTheme.CREAM)
	var eye_height := 3.0 if blink_seconds > 0.0 else 13.0
	_draw_filled_oval(Vector2(-22, -7) + gaze, Vector2(9, eye_height), PetTheme.INK)
	_draw_filled_oval(Vector2(22, -7) + gaze, Vector2(9, eye_height), PetTheme.INK)
	_draw_filled_oval(Vector2(0, 23), Vector2(27, 12), PetTheme.CREAM)
	draw_arc(Vector2(0, 21), 17, 0.15, PI - 0.15, 24, PetTheme.INK, 4.0)
	draw_circle(Vector2(0, 30), 4, PetTheme.INK)

func _draw_tongue() -> void:
	var target := pointer_local.limit_length(112.0)
	var mouth := Vector2(0, 28)
	var bend := (mouth + target) * 0.5 + Vector2(0, 12)
	var points := PackedVector2Array([mouth, bend, target])
	draw_polyline(points, PetTheme.TONGUE, 8.0, true)
	draw_polyline(points, PetTheme.CREAM, 2.0, true)
	draw_circle(target, 8, PetTheme.BODY_DARK)
	draw_circle(target, 4, PetTheme.BODY)

func _draw_tether() -> void:
	if drag_vector.is_zero_approx():
		return
	var mouth := Vector2(0, 28)
	var target := -drag_vector.normalized() * minf(36.0 + drag_vector.length() * 0.18, 112.0)
	var bend := (mouth + target) * 0.5 + Vector2(0, 14)
	var points := PackedVector2Array([mouth, bend, target])
	draw_polyline(points, PetTheme.TONGUE, 8.0, true)
	draw_polyline(points, PetTheme.CREAM, 2.0, true)

func _draw_corner_burst() -> void:
	var strength := corner_flash_seconds
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var inner := Vector2(cos(angle), sin(angle)) * 78.0
		var outer := Vector2(cos(angle), sin(angle)) * (110.0 + 18.0 * sin(idle_phase * 24.0))
		draw_line(inner, outer, PetTheme.CREAM.lightened(0.18 * strength), 5.0)

func _draw_burst() -> void:
	var progress := 1.0 - burst_seconds / 0.65
	var radius := lerpf(62.0, 148.0, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, PetTheme.BODY_DARK, 8.0 * (1.0 - progress))
	for index in range(6):
		var angle := TAU * float(index) / 6.0 + idle_phase
		var point := Vector2(cos(angle), sin(angle)) * (radius * 0.72)
		draw_circle(point, 4.0 * (1.0 - progress), PetTheme.CREAM)

func _draw_filled_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
