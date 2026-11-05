extends RefCounted

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")
const PetThrowProfile = preload("res://scripts/core/PetThrowProfile.gd")
const PetImpact = preload("res://scripts/core/PetImpact.gd")

enum Mode { IDLE, DVD_BOUNCE, SLITHER, FLOAT, FALL, LAUNCH, DRAG }

const THROW_SPEED_THRESHOLD := 360.0
const THROW_DISTANCE_THRESHOLD := 64.0
const MAX_THROW_SPEED := PetThrowProfile.MAX_SPEED
const THROW_SPEED_SCALE := 1.8
const THROW_ACCELERATION_WINDOW := 0.055
const MAX_ACCELERATION_SPEED_BONUS := 700.0
const THROW_GRAVITY := 540.0
const THROW_LINEAR_DAMPING := 4.5
const THROW_BOUNCE := 1.0
const FLOAT_ASCEND_SPEED := 900.0
const CONTENT_EDGE_MARGIN := DesktopBounds.CONTENT_EDGE_MARGIN

var enabled := true
var mode := Mode.DVD_BOUNCE
var window_position := Vector2.ZERO
var velocity := Vector2(178.0, 132.0)
var mode_time := 11.0
var corner_flash_seconds := 0.0
var drag_anchor := Vector2.ZERO
var drag_total := Vector2.ZERO
var mode_before_drag := Mode.DVD_BOUNCE
var throw_damping := THROW_LINEAR_DAMPING
var throw_gravity_scale := 1.0
var throw_bounce := THROW_BOUNCE
var throw_style := PetThrowProfile.Style.STANDARD
var throw_duration_seconds := PetThrowProfile.DEFAULT_DURATION
var throw_floor_bounce := 0.48
var fling_active := false

func initialize(initial_position: Vector2) -> void:
	window_position = initial_position

func advance(
	delta: float,
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Dictionary:
	var impacts: Array[PetImpact] = []
	var events := {"corner_hit": false, "landed": false, "impacts": impacts}
	corner_flash_seconds = maxf(0.0, corner_flash_seconds - delta)
	if mode == Mode.IDLE or mode == Mode.DRAG:
		return events
	mode_time -= delta
	match mode:
		Mode.DVD_BOUNCE:
			var result := DesktopBounds.advance_bounce(
				window_position, velocity, delta, work_area, window_size, content_rect, edge_margin
			)
			window_position = result.position
			velocity = result.velocity
			_set_edge_impact(events, result)
			events.corner_hit = result.corner_hit
			if events.corner_hit:
				corner_flash_seconds = 1.0
			if mode_time <= 0.0:
				_start_random_antics(work_area, window_size, content_rect, edge_margin)
		Mode.SLITHER:
			var minimum_x := float(work_area.position.x)
			var maximum := _maximum_position(work_area, window_size, content_rect, edge_margin)
			if content_rect.size.x > 0.0 and content_rect.size.y > 0.0:
				minimum_x = float(DesktopBounds.content_position_limits(work_area, content_rect, edge_margin).minimum.x)
			window_position.y = maximum.y
			window_position.x += velocity.x * delta
			if window_position.x < minimum_x or window_position.x > maximum.x:
				var impact_speed := absf(velocity.x)
				var impact_normal := Vector2.RIGHT if velocity.x < 0.0 else Vector2.LEFT
				window_position.x = clampf(window_position.x, minimum_x, maximum.x)
				velocity.x *= -1.0
				_set_impact(events, impact_normal, impact_speed)
			if mode_time <= 0.0:
				_start_dvd_bounce()
		Mode.FLOAT:
			var top_position := float(work_area.position.y)
			if content_rect.size.y > 0.0:
				var limits := DesktopBounds.content_position_limits(work_area, content_rect, edge_margin)
				top_position = float(limits.minimum.y)
			window_position.y = move_toward(window_position.y, top_position, FLOAT_ASCEND_SPEED * delta)
			if window_position.y <= top_position or mode_time <= 0.0:
				var reached_top := window_position.y <= top_position
				window_position.y = top_position
				mode = Mode.FALL
				mode_time = 8.0
				velocity = Vector2(0.0, 260.0)
				if reached_top:
					_set_impact(events, Vector2.DOWN, FLOAT_ASCEND_SPEED)
		Mode.FALL:
			velocity.y += 1850.0 * delta
			var result := DesktopBounds.advance_bounce(
				window_position, velocity, delta, work_area, window_size, content_rect, edge_margin
			)
			window_position = result.position
			velocity = result.velocity
			_set_edge_impact(events, result)
			if result.hit_y and velocity.y < 0.0:
				velocity.y = 0.0
				velocity.x = 0.0
				mode = Mode.DVD_BOUNCE if enabled else Mode.IDLE
				mode_time = 4.0
				events.landed = true
		Mode.LAUNCH:
			var gravity_scale := throw_gravity_scale if fling_active else 1.0
			var damping := throw_damping if fling_active else THROW_LINEAR_DAMPING
			velocity.y += THROW_GRAVITY * gravity_scale * delta
			velocity = (velocity * exp(-damping * delta)).limit_length(MAX_THROW_SPEED)
			var result := DesktopBounds.advance_bounce(
				window_position, velocity, delta, work_area, window_size, content_rect, edge_margin
			)
			window_position = result.position
			velocity = result.velocity
			_set_edge_impact(events, result)
			var restitution := throw_bounce if fling_active else THROW_BOUNCE
			if result.hit_x:
				velocity.x *= restitution
			if result.hit_y:
				velocity.y *= restitution
			events.corner_hit = result.corner_hit
			if result.corner_hit:
				corner_flash_seconds = 1.0
			if result.hit_y and velocity.y < 0.0:
				velocity.y *= throw_floor_bounce if fling_active else 0.48
			var duration_expired := mode_time <= 0.0
			var settled_on_edge: bool = bool(result["hit_y"]) and absf(velocity.y) < 70.0
			var continuous_madness := (
				fling_active
				and throw_style == PetThrowProfile.Style.MADNESS
				and throw_duration_seconds == PetThrowProfile.Duration.CONTINUOUS
			)
			if duration_expired or (not continuous_madness and settled_on_edge and velocity.length() < 70.0):
				fling_active = false
				_start_dvd_bounce()
	return events

func set_throw_physics(damping: float, gravity_scale: float, bounce: float) -> void:
	throw_damping = clampf(damping, PetThrowProfile.DAMPING_OPTIONS[0], PetThrowProfile.DAMPING_OPTIONS[-1])
	throw_gravity_scale = clampf(gravity_scale, PetThrowProfile.GRAVITY_SCALE_OPTIONS[0], PetThrowProfile.GRAVITY_SCALE_OPTIONS[-1])
	throw_bounce = clampf(bounce, 0.0, 1.0)

func set_throw_mode(style: int, duration_seconds: int) -> void:
	throw_style = clampi(style, PetThrowProfile.Style.STANDARD, PetThrowProfile.Style.MADNESS)
	throw_duration_seconds = duration_seconds if PetThrowProfile.is_valid_duration(duration_seconds) else PetThrowProfile.DEFAULT_DURATION
	var preset := PetThrowProfile.get_preset(throw_style)
	throw_floor_bounce = float(preset["floor_bounce"])
	if fling_active:
		var run_duration := throw_duration_seconds if throw_style == PetThrowProfile.Style.MADNESS else int(preset["duration_seconds"])
		mode_time = INF if run_duration == PetThrowProfile.Duration.CONTINUOUS else float(run_duration)

func stop_throw() -> bool:
	if not fling_active:
		return false
	fling_active = false
	mode = Mode.IDLE
	mode_time = 0.0
	velocity = Vector2.ZERO
	return true

func tap() -> bool:
	if mode == Mode.DRAG:
		mode = mode_before_drag
	if mode == Mode.FLOAT:
		mode = Mode.FALL
		mode_time = 8.0
		velocity = Vector2(0.0, 1250.0)
		return true
	return false

func begin_drag(mouse_position: Vector2) -> void:
	fling_active = false
	mode_before_drag = mode
	drag_total = Vector2.ZERO
	drag_anchor = mouse_position
	mode = Mode.DRAG
	velocity = Vector2.ZERO

func move_drag(target_position: Vector2, mouse_position: Vector2) -> void:
	window_position = target_position
	drag_total = mouse_position - drag_anchor

func end_drag(
	work_area: Rect2i,
	window_size: Vector2i,
	release_velocity: Vector2,
	release_acceleration: Vector2,
	throw_mode_enabled: bool,
	throw_strength: float = 1.0,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = CONTENT_EDGE_MARGIN,
	slow_release_fall_enabled: bool = false,
	drag_distance: float = 0.0
) -> Dictionary:
	window_position = _clamp_to_content(window_position, work_area, window_size, content_rect, edge_margin)
	drag_total = Vector2.ZERO
	fling_active = false
	if not throw_mode_enabled:
		mode = Mode.IDLE
		velocity = Vector2.ZERO
		return {"action": "move"}
	var release_speed := release_velocity.length()
	var launch_direction := release_velocity.normalized()
	if launch_direction.is_zero_approx():
		launch_direction = release_acceleration.normalized()
	var forward_acceleration := maxf(release_acceleration.dot(launch_direction), 0.0)
	var acceleration_bonus := minf(
		forward_acceleration * THROW_ACCELERATION_WINDOW,
		MAX_ACCELERATION_SPEED_BONUS
	)
	var launch_speed := (
		(release_speed + acceleration_bonus)
		* THROW_SPEED_SCALE
		* clampf(throw_strength, PetThrowProfile.STRENGTH_OPTIONS[0], PetThrowProfile.STRENGTH_OPTIONS[-1])
	)
	if drag_distance >= THROW_DISTANCE_THRESHOLD and launch_speed >= THROW_SPEED_THRESHOLD:
		mode = Mode.LAUNCH
		fling_active = true
		match throw_style:
			PetThrowProfile.Style.STANDARD:
				mode_time = 5.0
			PetThrowProfile.Style.BOUNCY:
				mode_time = 30.0
			PetThrowProfile.Style.MADNESS:
				mode_time = INF if throw_duration_seconds == PetThrowProfile.Duration.CONTINUOUS else float(throw_duration_seconds)
		velocity = launch_direction * minf(launch_speed, MAX_THROW_SPEED)
		return {"action": "throw"}
	velocity = Vector2.ZERO
	if slow_release_fall_enabled:
		mode = Mode.FALL
		mode_time = 8.0
		return {"action": "fall"}
	mode = Mode.IDLE
	return {"action": "place"}

func set_enabled(value: bool) -> void:
	enabled = value
	fling_active = false
	if enabled:
		_start_dvd_bounce()
	else:
		mode = Mode.IDLE
		velocity = Vector2.ZERO

func start_slither(
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> void:
	fling_active = false
	mode = Mode.SLITHER
	mode_time = 7.0
	velocity = Vector2(164.0 if velocity.x >= 0.0 else -164.0, 0.0)
	window_position.y = _maximum_position(work_area, window_size, content_rect, edge_margin).y

func start_float() -> void:
	fling_active = false
	mode = Mode.FLOAT
	mode_time = 6.5
	velocity = Vector2.ZERO

func start_dvd_bounce() -> void:
	_start_dvd_bounce()

func _start_dvd_bounce() -> void:
	fling_active = false
	mode = Mode.DVD_BOUNCE if enabled else Mode.IDLE
	mode_time = randf_range(8.0, 14.0)
	if velocity.length() < 70.0:
		velocity = Vector2(178.0, -132.0)

func _start_random_antics(
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2,
	edge_margin: float
) -> void:
	if randi_range(0, 1) == 0:
		mode = Mode.SLITHER
		mode_time = randf_range(4.0, 7.0)
		velocity = Vector2(164.0 if velocity.x >= 0.0 else -164.0, 0.0)
		window_position.y = _maximum_position(work_area, window_size, content_rect, edge_margin).y
	else:
		mode = Mode.FLOAT
		mode_time = randf_range(5.0, 8.0)
		velocity = Vector2.ZERO

func _clamp_to_content(
	position: Vector2,
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2,
	edge_margin: float
) -> Vector2:
	if content_rect.size.x > 0.0 and content_rect.size.y > 0.0:
		return DesktopBounds.clamp_position_to_content(position, work_area, content_rect, edge_margin)
	return DesktopBounds.clamp_position(position, work_area, window_size)

func _maximum_position(
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2,
	edge_margin: float
) -> Vector2:
	if content_rect.size.x > 0.0 and content_rect.size.y > 0.0:
		return Vector2(DesktopBounds.content_position_limits(work_area, content_rect, edge_margin).maximum)
	return Vector2(DesktopBounds.max_window_position(work_area, window_size))

func _set_edge_impact(events: Dictionary, result: Dictionary) -> void:
	_set_impact(events, Vector2(result.get("impact_normal", Vector2.ZERO)), float(result.get("impact_speed", 0.0)))

func _set_impact(events: Dictionary, normal: Vector2, impact_speed: float) -> void:
	if impact_speed < PetImpact.MINIMUM_SPEED or normal.is_zero_approx():
		return
	var impacts: Array = events["impacts"]
	for impact: PetImpact in impacts:
		if impact.body_id == 0:
			impact.merge(normal, impact_speed, PetImpact.Source.EDGE)
			return
	impacts.append(PetImpact.new(0, normal, impact_speed, PetImpact.Source.EDGE))
