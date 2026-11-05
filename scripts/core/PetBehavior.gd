extends RefCounted

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")

enum Mode { IDLE, DVD_BOUNCE, SLITHER, FLOAT, FALL, LAUNCH, DRAG }

const MAX_POKE_COUNT := 10
const THROW_SPEED_THRESHOLD := 360.0
const MAX_THROW_SPEED := 2100.0
const THROW_SPEED_SCALE := 1.2
const THROW_ACCELERATION_WINDOW := 0.055
const MAX_ACCELERATION_SPEED_BONUS := 700.0
const THROW_GRAVITY := 540.0
const FLOAT_ASCEND_SPEED := 900.0
const CONTENT_EDGE_MARGIN := DesktopBounds.CONTENT_EDGE_MARGIN

var enabled := true
var mode := Mode.DVD_BOUNCE
var window_position := Vector2.ZERO
var velocity := Vector2(178.0, 132.0)
var mode_time := 11.0
var inflation_hits := 0
var inflation_scale := 1.0
var impact_seconds := 0.0
var corner_flash_seconds := 0.0
var drag_anchor := Vector2.ZERO
var drag_total := Vector2.ZERO
var mode_before_drag := Mode.DVD_BOUNCE

func initialize(initial_position: Vector2) -> void:
	window_position = initial_position

func advance(
	delta: float,
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Dictionary:
	var events := {"corner_hit": false, "landed": false}
	impact_seconds = maxf(0.0, impact_seconds - delta)
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
				window_position.x = clampf(window_position.x, minimum_x, maximum.x)
				velocity.x *= -1.0
			if mode_time <= 0.0:
				_start_dvd_bounce()
		Mode.FLOAT:
			var top_position := float(work_area.position.y)
			if content_rect.size.y > 0.0:
				var limits := DesktopBounds.content_position_limits(work_area, content_rect, edge_margin)
				top_position = float(limits.minimum.y)
			window_position.y = move_toward(window_position.y, top_position, FLOAT_ASCEND_SPEED * delta)
			if window_position.y <= top_position or mode_time <= 0.0:
				window_position.y = top_position
				mode = Mode.FALL
				mode_time = 8.0
				velocity = Vector2(0.0, 260.0)
		Mode.FALL:
			velocity.y += 1850.0 * delta
			var result := DesktopBounds.advance_bounce(
				window_position, velocity, delta, work_area, window_size, content_rect, edge_margin
			)
			window_position = result.position
			velocity = result.velocity
			if result.hit_y and velocity.y < 0.0:
				velocity.y = 0.0
				velocity.x = 0.0
				impact_seconds = 0.42
				mode = Mode.DVD_BOUNCE if enabled else Mode.IDLE
				mode_time = 4.0
				events.landed = true
		Mode.LAUNCH:
			velocity.y += THROW_GRAVITY * delta
			var result := DesktopBounds.advance_bounce(
				window_position, velocity, delta, work_area, window_size, content_rect, edge_margin
			)
			window_position = result.position
			velocity = result.velocity
			events.corner_hit = result.corner_hit
			if result.corner_hit:
				corner_flash_seconds = 1.0
			if result.hit_y and velocity.y < 0.0:
				velocity.y *= 0.48
			if mode_time <= 0.0 or (result.hit_y and absf(velocity.y) < 70.0):
				_start_dvd_bounce()
	return events

func poke(
	work_area: Rect2i,
	window_size: Vector2i,
	content_rect: Rect2 = Rect2(),
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Dictionary:
	if mode == Mode.DRAG:
		mode = mode_before_drag
	if mode == Mode.FLOAT:
		mode = Mode.FALL
		mode_time = 8.0
		velocity = Vector2(0.0, 1250.0)
		return {"heavy_fall": true, "burst": false, "inflation": inflation_scale}
	inflation_hits += 1
	inflation_scale = pow(1.2, inflation_hits)
	if inflation_hits < MAX_POKE_COUNT:
		return {"heavy_fall": false, "burst": false, "inflation": inflation_scale}
	inflation_hits = 0
	inflation_scale = 1.0
	mode = Mode.LAUNCH
	mode_time = 4.5
	velocity = Vector2(randf_range(-440.0, 440.0), -560.0)
	window_position = _clamp_to_content(window_position, work_area, window_size, content_rect, edge_margin)
	return {"heavy_fall": false, "burst": true, "inflation": inflation_scale}

func begin_drag(mouse_position: Vector2) -> void:
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
	edge_margin: float = CONTENT_EDGE_MARGIN
) -> Dictionary:
	window_position = _clamp_to_content(window_position, work_area, window_size, content_rect, edge_margin)
	drag_total = Vector2.ZERO
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
	var launch_speed := (release_speed + acceleration_bonus) * THROW_SPEED_SCALE * clampf(throw_strength, 0.5, 2.0)
	if launch_speed >= THROW_SPEED_THRESHOLD:
		mode = Mode.LAUNCH
		mode_time = 5.0
		velocity = launch_direction * minf(launch_speed, MAX_THROW_SPEED)
		return {"action": "throw"}
	mode = Mode.FALL
	mode_time = 8.0
	velocity = Vector2.ZERO
	return {"action": "fall"}

func set_enabled(value: bool) -> void:
	enabled = value
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
	mode = Mode.SLITHER
	mode_time = 7.0
	velocity = Vector2(164.0 if velocity.x >= 0.0 else -164.0, 0.0)
	window_position.y = _maximum_position(work_area, window_size, content_rect, edge_margin).y

func start_float() -> void:
	mode = Mode.FLOAT
	mode_time = 6.5
	velocity = Vector2.ZERO

func start_dvd_bounce() -> void:
	_start_dvd_bounce()

func _start_dvd_bounce() -> void:
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
