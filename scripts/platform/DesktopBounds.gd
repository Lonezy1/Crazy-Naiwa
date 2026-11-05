extends RefCounted

const CONTENT_EDGE_MARGIN := 1.0

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

static func clamp_position_to_content(
	position: Vector2,
	work_area: Rect2i,
	content_rect: Rect2,
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Vector2:
	var limits := content_position_limits(work_area, content_rect, edge_margin)
	var minimum: Vector2 = limits.minimum
	var maximum: Vector2 = limits.maximum
	return Vector2(clampf(position.x, minimum.x, maximum.x), clampf(position.y, minimum.y, maximum.y))

static func content_position_limits(
	work_area: Rect2i,
	content_rect: Rect2,
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Dictionary:
	var margin := maxf(edge_margin, 0.0)
	var minimum := Vector2(
		ceil(float(work_area.position.x) - content_rect.position.x + margin),
		ceil(float(work_area.position.y) - content_rect.position.y + margin)
	)
	var maximum := Vector2(
		floor(float(work_area.end.x) - content_rect.end.x - margin),
		floor(float(work_area.end.y) - content_rect.end.y - margin)
	)
	maximum.x = maxf(maximum.x, minimum.x)
	maximum.y = maxf(maximum.y, minimum.y)
	return {"minimum": minimum, "maximum": maximum}

static func advance_bounce(
	position: Vector2,
	velocity: Vector2,
	delta: float,
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = 0.0
) -> Dictionary:
	var minimum := Vector2(work_area.position)
	var maximum := Vector2(max_window_position(work_area, window_size))
	if content_rect.size.x > 0.0 and content_rect.size.y > 0.0:
		var limits := content_position_limits(work_area, content_rect, edge_margin)
		minimum = limits.minimum
		maximum = limits.maximum
	var next := position + velocity * delta
	var hit_x := false
	var hit_y := false
	if next.x < minimum.x or next.x > maximum.x:
		next.x = clampf(next.x, minimum.x, maximum.x)
		velocity.x = absf(velocity.x) if next.x <= minimum.x else -absf(velocity.x)
		hit_x = true
	if next.y < minimum.y or next.y > maximum.y:
		next.y = clampf(next.y, minimum.y, maximum.y)
		velocity.y = absf(velocity.y) if next.y <= minimum.y else -absf(velocity.y)
		hit_y = true
	return {
		"position": next,
		"velocity": velocity,
		"hit_x": hit_x,
		"hit_y": hit_y,
		"corner_hit": hit_x and hit_y
	}
