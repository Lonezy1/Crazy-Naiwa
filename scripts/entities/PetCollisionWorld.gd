extends RefCounted

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")

const FIXED_STEP := 1.0 / 60.0
const MAX_FRAME_STEPS := 8
const MAX_FROG_SPEED := 1800.0
const MAX_DRAG_SPEED := 2400.0
const EDGE_RESTITUTION := 0.72
const BASE_RESTITUTION := 0.82
const LINEAR_DAMPING := 1.8
const STOP_SPEED := 14.0
const RADIUS_RATIO := 0.31
const MAX_RELEASE_STEPS := 512

var bodies: Array[Dictionary] = []
var collisions_enabled := true
var collision_strength := 1.0
var _accumulator := 0.0

func has_motion() -> bool:
	for body in bodies:
		if bool(body["dragged"]) or Vector2(body["velocity"]).length() >= STOP_SPEED:
			return true
	return false

func add_body(
	id: int,
	size: int,
	position: Vector2,
	work_area: Rect2i,
	content_rect: Rect2 = Rect2()
) -> void:
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		content_rect = Rect2(Vector2.ZERO, Vector2.ONE * size)
	bodies.append({
		"id": id,
		"size": size,
		"position": position,
		"velocity": Vector2.ZERO,
		"dragged": false,
		"drag_target": position,
		"grab_offset": Vector2.ZERO,
		"work_area": work_area,
		"content_rect": content_rect,
	})
	set_content_rect(id, content_rect)

func remove_body(id: int) -> void:
	for index in range(bodies.size() - 1, -1, -1):
		if int(bodies[index]["id"]) == id:
			bodies.remove_at(index)
			return

func get_body(id: int) -> Dictionary:
	for body in bodies:
		if int(body["id"]) == id:
			return body
	return {}

func set_content_rect(id: int, content_rect: Rect2) -> void:
	var body := get_body(id)
	if body.is_empty():
		return
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		var size := int(body["size"])
		content_rect = Rect2(Vector2.ZERO, Vector2.ONE * size)
	body["content_rect"] = content_rect
	var area: Rect2i = body["work_area"]
	body["position"] = _clamp_position(body["position"], area, content_rect)
	body["drag_target"] = _clamp_position(body["drag_target"], area, content_rect)

func begin_drag(id: int, pointer_position: Vector2) -> bool:
	var body := get_body(id)
	if body.is_empty():
		return false
	body["dragged"] = true
	body["velocity"] = Vector2.ZERO
	body["grab_offset"] = pointer_position - Vector2(body["position"])
	body["drag_target"] = body["position"]
	return true

func move_drag(id: int, pointer_position: Vector2) -> void:
	var body := get_body(id)
	if body.is_empty() or not bool(body["dragged"]):
		return
	body["drag_target"] = pointer_position - Vector2(body["grab_offset"])

func release_drag(id: int) -> void:
	var body := get_body(id)
	if body.is_empty():
		return
	body["dragged"] = false
	body["velocity"] = Vector2.ZERO
	body["drag_target"] = body["position"]

func finish_drag(id: int, pointer_position: Vector2, work_areas: Array[Rect2i]) -> Array[int]:
	var body := get_body(id)
	if body.is_empty() or not bool(body["dragged"]):
		return []
	move_drag(id, pointer_position)
	var target: Vector2 = body["drag_target"]
	var distance := target.distance_to(Vector2(body["position"]))
	var steps := clampi(ceili(distance / (MAX_DRAG_SPEED * FIXED_STEP)), 1, MAX_RELEASE_STEPS)
	var collisions: Array[int] = []
	for _step in range(steps):
		var current: Vector2 = body["position"]
		var remaining := target - current
		if remaining.length() <= 0.5:
			break
		# Keep release sweeps small enough to preserve contacts along a fast pointer path.
		body["drag_target"] = current + remaining.limit_length(MAX_DRAG_SPEED * FIXED_STEP)
		collisions.append_array(_advance_fixed(FIXED_STEP, work_areas))
	return _unique_ids(collisions)

func set_size(id: int, size: int) -> void:
	var body := get_body(id)
	if body.is_empty():
		return
	var old_size := int(body["size"])
	var center := Vector2(body["position"]) + Vector2(old_size, old_size) * 0.5
	body["size"] = size
	body["position"] = _clamp_position(
		center - Vector2(size, size) * 0.5, body["work_area"], body["content_rect"]
	)
	body["drag_target"] = body["position"]

func advance(delta: float, work_areas: Array[Rect2i]) -> Array[int]:
	var collided_ids: Array[int] = []
	if bodies.is_empty():
		return collided_ids
	_accumulator = minf(_accumulator + maxf(delta, 0.0), FIXED_STEP * MAX_FRAME_STEPS)
	var step_count := 0
	while _accumulator >= FIXED_STEP and step_count < MAX_FRAME_STEPS:
		collided_ids.append_array(_advance_fixed(FIXED_STEP, work_areas))
		_accumulator -= FIXED_STEP
		step_count += 1
	return _unique_ids(collided_ids)

func _advance_fixed(delta: float, work_areas: Array[Rect2i]) -> Array[int]:
	var collided_ids: Array[int] = []
	var drag_targets: Dictionary = {}
	var maximum_motion := 0.0
	var minimum_size := 640.0
	for body in bodies:
		minimum_size = minf(minimum_size, float(body["size"]))
		if bool(body["dragged"]):
			var desired := Vector2(body["drag_target"])
			var motion: Vector2 = desired - Vector2(body["position"])
			drag_targets[int(body["id"])] = Vector2(body["position"]) + motion
			maximum_motion = maxf(maximum_motion, motion.length())
		else:
			maximum_motion = maxf(maximum_motion, Vector2(body["velocity"]).length() * delta)
	var substeps := clampi(ceili(maximum_motion / maxf(8.0, minimum_size * 0.35)), 1, 8)
	var substep_delta := delta / float(substeps)
	for substep in range(substeps):
		var remaining_substeps := float(substeps - substep)
		for body in bodies:
			var id := int(body["id"])
			if bool(body["dragged"]):
				var old_position: Vector2 = body["position"]
				var target: Vector2 = drag_targets[id]
				var next_position := old_position + (target - old_position) / remaining_substeps
				body["position"] = next_position
				body["velocity"] = ((next_position - old_position) / substep_delta).limit_length(MAX_DRAG_SPEED)
			else:
				body["position"] = Vector2(body["position"]) + Vector2(body["velocity"]) * substep_delta
				body["velocity"] = Vector2(body["velocity"]) * exp(-LINEAR_DAMPING * substep_delta)
			_resolve_boundaries(body, work_areas, collided_ids)
		if collisions_enabled:
			_resolve_pairs(collided_ids)
		for body in bodies:
			if bool(body["dragged"]):
				continue
			var velocity: Vector2 = body["velocity"]
			if velocity.length() < STOP_SPEED:
				body["velocity"] = Vector2.ZERO
			else:
				body["velocity"] = velocity.limit_length(MAX_FROG_SPEED)
			_resolve_boundaries(body, work_areas, collided_ids)
	return _unique_ids(collided_ids)

func _resolve_boundaries(body: Dictionary, work_areas: Array[Rect2i], collided_ids: Array[int]) -> void:
	var content_rect: Rect2 = body["content_rect"]
	var area: Rect2i = body["work_area"]
	var center := Vector2(body["position"]) + content_rect.get_center()
	for candidate in work_areas:
		if candidate.has_point(Vector2i(roundi(center.x), roundi(center.y))):
			area = candidate
			break
	body["work_area"] = area
	var limits := DesktopBounds.content_position_limits(area, content_rect)
	var minimum: Vector2 = limits.minimum
	var maximum: Vector2 = limits.maximum
	var position: Vector2 = body["position"]
	var velocity: Vector2 = body["velocity"]
	var dragged := bool(body["dragged"])
	var hit_left := position.x < minimum.x
	var hit_right := position.x > maximum.x
	if hit_left or hit_right:
		var hit_speed := absf(velocity.x)
		position.x = clampf(position.x, minimum.x, maximum.x)
		if dragged:
			velocity.x = 0.0
		else:
			velocity.x = absf(velocity.x) * EDGE_RESTITUTION if hit_left else -absf(velocity.x) * EDGE_RESTITUTION
		if hit_speed > STOP_SPEED:
			_collide_id(collided_ids, int(body["id"]))
	var hit_top := position.y < minimum.y
	var hit_bottom := position.y > maximum.y
	if hit_top or hit_bottom:
		var hit_speed := absf(velocity.y)
		position.y = clampf(position.y, minimum.y, maximum.y)
		if dragged:
			velocity.y = 0.0
		else:
			velocity.y = absf(velocity.y) * EDGE_RESTITUTION if hit_top else -absf(velocity.y) * EDGE_RESTITUTION
		if hit_speed > STOP_SPEED:
			_collide_id(collided_ids, int(body["id"]))
	body["position"] = position
	body["velocity"] = velocity
	if dragged:
		body["drag_target"] = _clamp_position(body["drag_target"], area, content_rect)

func _resolve_pairs(collided_ids: Array[int]) -> void:
	var restitution := clampf(BASE_RESTITUTION * collision_strength, 0.1, 0.97)
	for _iteration in range(2):
		for first_index in range(bodies.size()):
			var first: Dictionary = bodies[first_index]
			for second_index in range(first_index + 1, bodies.size()):
				var second: Dictionary = bodies[second_index]
				var first_size := int(first["size"])
				var second_size := int(second["size"])
				var normal_delta := (Vector2(second["position"]) + Vector2.ONE * second_size * 0.5) - (Vector2(first["position"]) + Vector2.ONE * first_size * 0.5)
				var minimum_distance := maxf(10.0, float(first_size + second_size) * RADIUS_RATIO)
				if absf(normal_delta.x) >= minimum_distance or absf(normal_delta.y) >= minimum_distance:
					continue
				var distance := normal_delta.length()
				if distance >= minimum_distance:
					continue
				var normal := normal_delta / distance if distance > 0.001 else Vector2.RIGHT
				var first_inverse_mass := 0.0 if bool(first["dragged"]) else 1.0 / pow(float(first_size) / 320.0, 2.0)
				var second_inverse_mass := 0.0 if bool(second["dragged"]) else 1.0 / pow(float(second_size) / 320.0, 2.0)
				var inverse_mass_sum := first_inverse_mass + second_inverse_mass
				if inverse_mass_sum <= 0.0:
					continue
				var penetration := minimum_distance - distance + 0.05
				first["position"] = Vector2(first["position"]) - normal * penetration * first_inverse_mass / inverse_mass_sum
				second["position"] = Vector2(second["position"]) + normal * penetration * second_inverse_mass / inverse_mass_sum
				var first_velocity: Vector2 = first["velocity"]
				var second_velocity: Vector2 = second["velocity"]
				var closing_speed := (second_velocity - first_velocity).dot(normal)
				if closing_speed < 0.0:
					var impulse := -(1.0 + restitution) * closing_speed / inverse_mass_sum
					first["velocity"] = (first_velocity - normal * impulse * first_inverse_mass).limit_length(MAX_FROG_SPEED)
					second["velocity"] = (second_velocity + normal * impulse * second_inverse_mass).limit_length(MAX_FROG_SPEED)
					if absf(closing_speed) > STOP_SPEED:
						_collide_id(collided_ids, int(first["id"]))
						_collide_id(collided_ids, int(second["id"]))

func _clamp_position(position: Vector2, area: Rect2i, content_rect: Rect2) -> Vector2:
	return DesktopBounds.clamp_position_to_content(position, area, content_rect)

func _collide_id(ids: Array[int], id: int) -> void:
	if not ids.has(id):
		ids.append(id)

func _unique_ids(ids: Array[int]) -> Array[int]:
	var unique: Array[int] = []
	for id in ids:
		if not unique.has(id):
			unique.append(id)
	return unique
