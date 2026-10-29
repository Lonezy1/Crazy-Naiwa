extends RefCounted

static func current_work_area() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())

static func max_window_position(work_area: Rect2i, window_size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(work_area.position.x, work_area.end.x - window_size.x),
		maxi(work_area.position.y, work_area.end.y - window_size.y)
	)

static func clamp_position(position: Vector2, work_area: Rect2i, window_size: Vector2i) -> Vector2:
	var maximum := max_window_position(work_area, window_size)
	return Vector2(
		clampf(position.x, work_area.position.x, maximum.x),
		clampf(position.y, work_area.position.y, maximum.y)
	)

static func advance_bounce(
	position: Vector2,
	velocity: Vector2,
	delta: float,
	work_area: Rect2i,
	window_size: Vector2i
) -> Dictionary:
	var maximum := max_window_position(work_area, window_size)
	var next := position + velocity * delta
	var hit_x := false
	var hit_y := false
	if next.x < work_area.position.x or next.x > maximum.x:
		next.x = clampf(next.x, work_area.position.x, maximum.x)
		velocity.x = absf(velocity.x) if next.x <= work_area.position.x else -absf(velocity.x)
		hit_x = true
	if next.y < work_area.position.y or next.y > maximum.y:
		next.y = clampf(next.y, work_area.position.y, maximum.y)
		velocity.y = absf(velocity.y) if next.y <= work_area.position.y else -absf(velocity.y)
		hit_y = true
	return {
		"position": next,
		"velocity": velocity,
		"hit_x": hit_x,
		"hit_y": hit_y,
		"corner_hit": hit_x and hit_y
	}
