extends RefCounted

const DesktopBounds = preload("res://scripts/platform/DesktopBounds.gd")

enum Mode { IDLE, DVD_BOUNCE, SLITHER, FLOAT, FALL, LAUNCH, DRAG }

const MAX_POKE_COUNT := 10
const MAX_LAUNCH_SPEED := 760.0

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

func initialize(position: Vector2) -> void:
	window_position = position

func advance(delta: float, work_area: Rect2i, window_size: Vector2i) -> Dictionary:
	var events := {"corner_hit": false, "landed": false}
	impact_seconds = maxf(0.0, impact_seconds - delta)
	corner_flash_seconds = maxf(0.0, corner_flash_seconds - delta)
	if not enabled or mode == Mode.IDLE or mode == Mode.DRAG:
		return events
	mode_time -= delta
	match mode:
		Mode.DVD_BOUNCE:
			var result := DesktopBounds.advance_bounce(window_position, velocity, delta, work_area, window_size)
			window_position = result.position
			velocity = result.velocity
			events.corner_hit = result.corner_hit
			if events.corner_hit:
				corner_flash_seconds = 1.0
			if mode_time <= 0.0:
				_start_random_antics(work_area, window_size)
		Mode.SLITHER:
			var maximum := DesktopBounds.max_window_position(work_area, window_size)
			window_position.y = maximum.y
			window_position.x += velocity.x * delta
			if window_position.x < work_area.position.x or window_position.x > maximum.x:
				window_position.x = clampf(window_position.x, work_area.position.x, maximum.x)
				velocity.x *= -1.0
			if mode_time <= 0.0:
				_start_dvd_bounce()
		Mode.FLOAT:
			window_position.y = move_toward(window_position.y, work_area.position.y, 58.0 * delta)
			if mode_time <= 0.0:
				mode = Mode.FALL
				mode_time = 8.0
				velocity = Vector2(0.0, 260.0)
		Mode.FALL:
			velocity.y += 1850.0 * delta
			var result := DesktopBounds.advance_bounce(window_position, velocity, delta, work_area, window_size)
			window_position = result.position
			velocity = result.velocity
			if result.hit_y and velocity.y < 0.0:
				velocity.y = 0.0
				velocity.x = 0.0
				impact_seconds = 0.42
				mode = Mode.DVD_BOUNCE
				mode_time = 4.0
				events.landed = true
		Mode.LAUNCH:
			velocity.y += 980.0 * delta
			var result := DesktopBounds.advance_bounce(window_position, velocity, delta, work_area, window_size)
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

func poke(work_area: Rect2i, window_size: Vector2i) -> Dictionary:
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
	window_position = DesktopBounds.clamp_position(window_position, work_area, window_size)
	return {"heavy_fall": false, "burst": true, "inflation": inflation_scale}

func begin_drag(mouse_position: Vector2) -> void:
	mode_before_drag = mode
	drag_total = Vector2.ZERO
	drag_anchor = mouse_position
	mode = Mode.DRAG
	velocity = Vector2.ZERO

func move_drag(position: Vector2, mouse_position: Vector2) -> void:
	window_position = position
	drag_total = mouse_position - drag_anchor

func end_drag(work_area: Rect2i, window_size: Vector2i) -> void:
	var pull := drag_total
	if pull.length() >= 20.0:
		mode = Mode.LAUNCH
		mode_time = 5.0
		velocity = -pull.normalized() * minf(pull.length() * 2.2, MAX_LAUNCH_SPEED)
	else:
		_start_dvd_bounce()
	window_position = DesktopBounds.clamp_position(window_position, work_area, window_size)
	drag_total = Vector2.ZERO

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		_start_dvd_bounce()
	else:
		mode = Mode.IDLE
		velocity = Vector2.ZERO

func start_slither(work_area: Rect2i, window_size: Vector2i) -> void:
	mode = Mode.SLITHER
	mode_time = 7.0
	velocity = Vector2(164.0 if velocity.x >= 0.0 else -164.0, 0.0)
	window_position.y = DesktopBounds.max_window_position(work_area, window_size).y

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

func _start_random_antics(work_area: Rect2i, window_size: Vector2i) -> void:
	if randi_range(0, 1) == 0:
		mode = Mode.SLITHER
		mode_time = randf_range(4.0, 7.0)
		velocity = Vector2(164.0 if velocity.x >= 0.0 else -164.0, 0.0)
		window_position.y = DesktopBounds.max_window_position(work_area, window_size).y
	else:
		mode = Mode.FLOAT
		mode_time = randf_range(5.0, 8.0)
		velocity = Vector2.ZERO
