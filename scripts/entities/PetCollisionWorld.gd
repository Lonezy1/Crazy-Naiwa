extends RefCounted

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const PetImpact = preload("res://scripts/core/PetImpact.gd")
const PetThrowProfile = preload("res://scripts/core/PetThrowProfile.gd")

const FIXED_STEP := 1.0 / 60.0
const MAX_FRAME_STEPS := 8
const MAX_FROG_SPEED := 1800.0
const MAX_DRAG_SPEED := 2400.0
const STOP_SPEED := 14.0
const RADIUS_RATIO := 0.31
const POSITION_ITERATIONS := 5
const MAX_RELEASE_STEPS := 512

var bodies: Array[Dictionary] = []
var collisions_enabled := true
var collision_damping: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["damping"]
var collision_restitution: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["bounce"]
var _accumulator := 0.0
var _needs_initial_solve := false

func has_motion() -> bool:
	if _needs_initial_solve:
		return true
	for body in bodies:
		if bool(body["dragged"]) or Vector2(body["velocity"]).length() >= STOP_SPEED:
			return true
	return false

func set_collisions_enabled(value: bool) -> void:
	collisions_enabled = value
	if value:
		_needs_initial_solve = true

func set_collision_physics(damping: float, restitution: float) -> void:
	collision_damping = clampf(
		damping,
		PetThrowProfile.DAMPING_OPTIONS[0],
		PetThrowProfile.DAMPING_OPTIONS[-1]
	)
	collision_restitution = clampf(restitution, 0.0, 1.0)

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
	_needs_initial_solve = true
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
		content_rect = Rect2(Vector2.ZERO, Vector2.ONE * int(body["size"]))
	if not Rect2(body["content_rect"]).is_equal_approx(content_rect):
		_needs_initial_solve = true
	body["content_rect"] = content_rect
	var area: Rect2i = body["work_area"]
	var position: Vector2 = body["position"]
	var drag_target: Vector2 = body["drag_target"]
	var clamped_position := _clamp_position(position, area, content_rect)
	var clamped_target := _clamp_position(drag_target, area, content_rect)
	if clamped_position != position or clamped_target != drag_target:
		_needs_initial_solve = true
	body["position"] = clamped_position
	body["drag_target"] = clamped_target

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

func finish_drag(id: int, pointer_position: Vector2, work_areas: Array[Rect2i]) -> Array[PetImpact]:
	var body := get_body(id)
	if body.is_empty() or not bool(body["dragged"]):
		return []
	move_drag(id, pointer_position)
	var target: Vector2 = body["drag_target"]
	var distance := target.distance_to(Vector2(body["position"]))
	var steps := clampi(ceili(distance / (MAX_DRAG_SPEED * FIXED_STEP)), 1, MAX_RELEASE_STEPS)
	var impacts: Array[PetImpact] = []
	for _step in range(steps):
		var current: Vector2 = body["position"]
		var remaining := target - current
		if remaining.length() <= 0.5:
			break
		body["drag_target"] = current + remaining.limit_length(MAX_DRAG_SPEED * FIXED_STEP)
		_merge_impacts(impacts, _advance_fixed(FIXED_STEP, work_areas))
	return impacts

func set_size(id: int, size: int) -> void:
	var body := get_body(id)
	if body.is_empty():
		return
	var old_size := int(body["size"])
	var center := Vector2(body["position"]) + Vector2(old_size, old_size) * 0.5
	body["size"] = size
	body["position"] = _clamp_position(
		center - Vector2(size, size) * 0.5,
		body["work_area"],
		body["content_rect"]
	)
	body["drag_target"] = body["position"]
	_needs_initial_solve = true

func advance(delta: float, work_areas: Array[Rect2i]) -> Array[PetImpact]:
	var impacts: Array[PetImpact] = []
	if bodies.is_empty():
		return impacts
	_accumulator = minf(_accumulator + maxf(delta, 0.0), FIXED_STEP * MAX_FRAME_STEPS)
	var step_count := 0
	while _accumulator >= FIXED_STEP and step_count < MAX_FRAME_STEPS:
		_merge_impacts(impacts, _advance_fixed(FIXED_STEP, work_areas))
		_accumulator -= FIXED_STEP
		step_count += 1
	return impacts

func _advance_fixed(delta: float, work_areas: Array[Rect2i]) -> Array[PetImpact]:
	var impacts: Array[PetImpact] = []
	var drag_targets: Dictionary = {}
	var maximum_motion := 0.0
	var minimum_size := 640.0
	for body in bodies:
		minimum_size = minf(minimum_size, float(body["size"]))
		if bool(body["dragged"]):
			var motion: Vector2 = Vector2(body["drag_target"]) - Vector2(body["position"])
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
				body["velocity"] = Vector2(body["velocity"]) * exp(-collision_damping * substep_delta)
			_resolve_boundaries(body, work_areas, impacts)
		for iteration in range(POSITION_ITERATIONS):
			if collisions_enabled:
				_resolve_pairs(impacts, iteration == 0)
			for body in bodies:
				_resolve_boundaries(body, work_areas, impacts)
		for body in bodies:
			if bool(body["dragged"]):
				continue
			var velocity: Vector2 = body["velocity"]
			if velocity.length() < STOP_SPEED:
				body["velocity"] = Vector2.ZERO
			else:
				body["velocity"] = velocity.limit_length(MAX_FROG_SPEED)
			_resolve_boundaries(body, work_areas, impacts)
	_needs_initial_solve = false
	return impacts

func _resolve_boundaries(body: Dictionary, work_areas: Array[Rect2i], impacts: Array[PetImpact]) -> void:
	var content_rect: Rect2 = body["content_rect"]
	var area: Rect2i = body["work_area"]
	var center := Vector2(body["position"]) + content_rect.get_center()
	for candidate in work_areas:
		if candidate.has_point(Vector2i(roundi(center.x), roundi(center.y))):
			area = candidate
			break
	body["work_area"] = area
	var limits := _body_position_limits(area, content_rect)
	var minimum: Vector2 = limits.minimum
	var maximum: Vector2 = limits.maximum
	var position: Vector2 = body["position"]
	var velocity: Vector2 = body["velocity"]
	var dragged := bool(body["dragged"])
	var impact_vector := Vector2.ZERO
	if position.x < minimum.x or position.x > maximum.x:
		var hit_left := position.x < minimum.x
		var outward_speed := absf(velocity.x) if dragged else maxf(0.0, -velocity.x if hit_left else velocity.x)
		position.x = clampf(position.x, minimum.x, maximum.x)
		if dragged:
			velocity.x = 0.0
		elif outward_speed > 0.0:
			velocity.x = outward_speed * collision_restitution if hit_left else -outward_speed * collision_restitution
		if outward_speed > 0.0:
			impact_vector.x = outward_speed if hit_left else -outward_speed
	if position.y < minimum.y or position.y > maximum.y:
		var hit_top := position.y < minimum.y
		var outward_speed := absf(velocity.y) if dragged else maxf(0.0, -velocity.y if hit_top else velocity.y)
		position.y = clampf(position.y, minimum.y, maximum.y)
		if dragged:
			velocity.y = 0.0
		elif outward_speed > 0.0:
			velocity.y = outward_speed * collision_restitution if hit_top else -outward_speed * collision_restitution
		if outward_speed > 0.0:
			impact_vector.y = outward_speed if hit_top else -outward_speed
	body["position"] = position
	body["velocity"] = velocity
	if not impact_vector.is_zero_approx():
		_record_impact(
			impacts,
			int(body["id"]),
			impact_vector.normalized(),
			impact_vector.length(),
			PetImpact.Source.EDGE
		)
	if dragged:
		body["drag_target"] = _clamp_position(body["drag_target"], area, content_rect)

func _resolve_pairs(impacts: Array[PetImpact], apply_impulses: bool) -> void:
	var restitution := collision_restitution
	for first_index in range(bodies.size()):
		var first: Dictionary = bodies[first_index]
		for second_index in range(first_index + 1, bodies.size()):
			var second: Dictionary = bodies[second_index]
			var first_size := int(first["size"])
			var second_size := int(second["size"])
			var first_rect: Rect2 = first["content_rect"]
			var second_rect: Rect2 = second["content_rect"]
			var first_center := Vector2(first["position"]) + first_rect.get_center()
			var second_center := Vector2(second["position"]) + second_rect.get_center()
			var normal_delta := second_center - first_center
			var combined_radii := _body_collision_radii(first) + _body_collision_radii(second)
			combined_radii.x = maxf(combined_radii.x, 5.0)
			combined_radii.y = maxf(combined_radii.y, 5.0)
			var scaled_delta := normal_delta / combined_radii
			var scaled_distance := scaled_delta.length()
			if scaled_distance >= 1.0:
				continue
			var gradient := Vector2(
				normal_delta.x / pow(combined_radii.x, 2.0),
				normal_delta.y / pow(combined_radii.y, 2.0)
			)
			var normal := gradient.normalized() if not gradient.is_zero_approx() else Vector2.RIGHT
			var first_inverse_mass := 0.0 if bool(first["dragged"]) else 1.0 / pow(float(first["size"]) / 320.0, 2.0)
			var second_inverse_mass := 0.0 if bool(second["dragged"]) else 1.0 / pow(float(second["size"]) / 320.0, 2.0)
			var inverse_mass_sum := first_inverse_mass + second_inverse_mass
			if inverse_mass_sum <= 0.0:
				continue
			var penetration := _ellipse_penetration(normal_delta, combined_radii)
			var first_position := Vector2(first["position"]) - normal * penetration * first_inverse_mass / inverse_mass_sum
			var second_position := Vector2(second["position"]) + normal * penetration * second_inverse_mass / inverse_mass_sum
			first["position"] = _clamp_position(first_position, first["work_area"], first_rect)
			second["position"] = _clamp_position(second_position, second["work_area"], second_rect)
			var corrected_first_center := Vector2(first["position"]) + first_rect.get_center()
			var corrected_second_center := Vector2(second["position"]) + second_rect.get_center()
			var remaining_penetration := _ellipse_penetration(
				corrected_second_center - corrected_first_center,
				combined_radii
			)
			if remaining_penetration > 0.01:
				var first_capacity := _available_movement(first, -normal, remaining_penetration)
				var second_capacity := _available_movement(second, normal, remaining_penetration)
				var first_extra := minf(remaining_penetration, first_capacity)
				var second_extra := minf(remaining_penetration - first_extra, second_capacity)
				first["position"] = Vector2(first["position"]) - normal * first_extra
				second["position"] = Vector2(second["position"]) + normal * second_extra
			var first_velocity: Vector2 = first["velocity"]
			var second_velocity: Vector2 = second["velocity"]
			var closing_speed := (second_velocity - first_velocity).dot(normal)
			if closing_speed < 0.0:
				_record_impact(impacts, int(first["id"]), -normal, -closing_speed, PetImpact.Source.PET)
				_record_impact(impacts, int(second["id"]), normal, -closing_speed, PetImpact.Source.PET)
				if apply_impulses:
					var impulse := -(1.0 + restitution) * closing_speed / inverse_mass_sum
					first["velocity"] = (first_velocity - normal * impulse * first_inverse_mass).limit_length(MAX_FROG_SPEED)
					second["velocity"] = (second_velocity + normal * impulse * second_inverse_mass).limit_length(MAX_FROG_SPEED)

func _body_position_limits(area: Rect2i, content_rect: Rect2) -> Dictionary:
	return DesktopBounds.content_position_limits(area, content_rect)

func _ellipse_penetration(delta: Vector2, radii: Vector2) -> float:
	var scaled_distance := (delta / radii).length()
	if scaled_distance >= 1.0:
		return 0.0
	var effective_radius := delta.length() / scaled_distance if scaled_distance > 0.001 else radii.x
	return (1.0 - scaled_distance) * effective_radius

func _body_collision_radii(body: Dictionary) -> Vector2:
	var size := float(body["size"])
	var content_rect: Rect2 = body["content_rect"]
	if content_rect.position.is_zero_approx() and content_rect.size.is_equal_approx(Vector2.ONE * size):
		return Vector2.ONE * size * RADIUS_RATIO
	return content_rect.size * 0.5

func _available_movement(body: Dictionary, direction: Vector2, distance: float) -> float:
	if bool(body["dragged"]):
		return 0.0
	var direction_unit := direction.normalized()
	var desired := Vector2(body["position"]) + direction_unit * distance
	var clamped := _clamp_position(desired, body["work_area"], body["content_rect"])
	return clampf((clamped - Vector2(body["position"])).dot(direction_unit), 0.0, distance)

func _clamp_position(position: Vector2, area: Rect2i, content_rect: Rect2) -> Vector2:
	var limits := _body_position_limits(area, content_rect)
	return Vector2(
		clampf(position.x, limits.minimum.x, limits.maximum.x),
		clampf(position.y, limits.minimum.y, limits.maximum.y)
	)

func _merge_impacts(target: Array[PetImpact], added: Array[PetImpact]) -> void:
	for impact in added:
		_record_impact(target, impact.body_id, impact.normal, impact.speed, impact.source)

func _record_impact(
	events: Array[PetImpact],
	body_id: int,
	normal: Vector2,
	speed: float,
	source: int
) -> void:
	if speed < PetImpact.MINIMUM_SPEED or normal.is_zero_approx():
		return
	for event: PetImpact in events:
		if event.body_id == body_id:
			event.merge(normal, speed, source)
			return
	events.append(PetImpact.new(body_id, normal, speed, source))
