extends RefCounted

## Mouse gesture classifier shared by the window input layer and tests.
## It deliberately does not move the window or mutate behavior state.

enum Phase { IDLE, PRESSED, DRAGGING }

const HOLD_THRESHOLD_SECONDS := 0.01
const MOVE_THRESHOLD_PIXELS := 10.0
const VELOCITY_WINDOW_SECONDS := 0.12
const ACCELERATION_WINDOW_SECONDS := 0.06
const MAX_ESTIMATED_ACCELERATION := 12000.0

var phase := Phase.IDLE
var press_position := Vector2.ZERO
var current_position := Vector2.ZERO
var _drag_origin_position := Vector2.ZERO
var press_time := 0.0
var _last_motion_time := 0.0
var _samples: Array[Dictionary] = []

func begin(position: Vector2, timestamp: float = -1.0) -> void:
	var now := _resolve_timestamp(timestamp)
	phase = Phase.PRESSED
	press_position = position
	current_position = position
	press_time = now
	_last_motion_time = now
	_samples.clear()
	_samples.append({"position": position, "time": now})

func update(position: Vector2, timestamp: float = -1.0) -> Dictionary:
	if phase == Phase.IDLE:
		return _empty_result()
	var now := _resolve_timestamp(timestamp)
	_record_sample(position, now)
	current_position = position
	var started_drag := false
	if phase == Phase.PRESSED:
		var held_long_enough := now - press_time >= HOLD_THRESHOLD_SECONDS
		var moved_far_enough := position.distance_to(press_position) >= MOVE_THRESHOLD_PIXELS
		if held_long_enough and moved_far_enough:
			phase = Phase.DRAGGING
			_drag_origin_position = press_position
			started_drag = true
	return _result(started_drag, now)

func advance(position: Vector2, timestamp: float = -1.0) -> Dictionary:
	return update(position, timestamp)

func end(position: Vector2, timestamp: float = -1.0) -> Dictionary:
	if phase == Phase.IDLE:
		return _empty_result()
	var now := _resolve_timestamp(timestamp)
	var update_result := update(position, now)
	var was_dragging := phase == Phase.DRAGGING
	var result := {
		"dragging": was_dragging,
		"started_drag": bool(update_result["started_drag"]),
		"position": current_position,
		"drag_origin_position": _drag_origin_position,
		"duration": now - press_time,
		"total": current_position - press_position,
		"release_velocity": _estimate_velocity(now),
		"release_acceleration": _estimate_acceleration(now),
	}
	reset()
	return result

func reset() -> void:
	phase = Phase.IDLE
	_last_motion_time = 0.0
	_samples.clear()

func _result(started_drag: bool, timestamp: float) -> Dictionary:
	return {
		"dragging": phase == Phase.DRAGGING,
		"started_drag": started_drag,
		"position": current_position,
		"drag_origin_position": _drag_origin_position,
		"duration": timestamp - press_time,
		"total": current_position - press_position,
		"release_velocity": _estimate_velocity(timestamp),
		"release_acceleration": _estimate_acceleration(timestamp),
	}

func _empty_result() -> Dictionary:
	return {
		"dragging": false,
		"started_drag": false,
		"position": current_position,
		"drag_origin_position": current_position,
		"duration": 0.0,
		"total": Vector2.ZERO,
		"release_velocity": Vector2.ZERO,
		"release_acceleration": Vector2.ZERO,
	}

func _record_sample(position: Vector2, timestamp: float) -> void:
	if not _samples.is_empty() and not Vector2(_samples[-1]["position"]).is_equal_approx(position):
		_last_motion_time = timestamp
	_samples.append({"position": position, "time": timestamp})
	var cutoff := timestamp - VELOCITY_WINDOW_SECONDS
	while _samples.size() > 2 and float(_samples[0]["time"]) < cutoff:
		_samples.pop_front()

func _estimate_velocity(reference_time: float) -> Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	if reference_time - _last_motion_time > VELOCITY_WINDOW_SECONDS:
		return Vector2.ZERO
	return _average_velocity_between(
		_last_motion_time - VELOCITY_WINDOW_SECONDS,
		_last_motion_time
	)

func _estimate_acceleration(reference_time: float) -> Vector2:
	if _samples.size() < 3:
		return Vector2.ZERO
	if reference_time - _last_motion_time > VELOCITY_WINDOW_SECONDS:
		return Vector2.ZERO
	var midpoint := _last_motion_time - ACCELERATION_WINDOW_SECONDS * 0.5
	var previous_velocity := _average_velocity_between(
		midpoint - ACCELERATION_WINDOW_SECONDS,
		midpoint
	)
	var recent_velocity := _average_velocity_between(midpoint, _last_motion_time)
	return ((recent_velocity - previous_velocity) / ACCELERATION_WINDOW_SECONDS).limit_length(
		MAX_ESTIMATED_ACCELERATION
	)

func _average_velocity_between(start_time: float, end_time: float) -> Vector2:
	var distance := Vector2.ZERO
	var elapsed := 0.0
	for index in range(1, _samples.size()):
		var previous: Dictionary = _samples[index - 1]
		var current: Dictionary = _samples[index]
		var segment_start := float(previous["time"])
		var segment_end := float(current["time"])
		var segment_delta := segment_end - segment_start
		var segment_midpoint := (segment_start + segment_end) * 0.5
		if segment_delta <= 0.000001 or segment_midpoint < start_time or segment_midpoint > end_time:
			continue
		var segment_distance: Vector2 = Vector2(current["position"]) - Vector2(previous["position"])
		if segment_distance.is_zero_approx():
			continue
		distance += segment_distance
		elapsed += segment_delta
	if elapsed <= 0.000001:
		return Vector2.ZERO
	return distance / elapsed

func _resolve_timestamp(timestamp: float) -> float:
	if timestamp >= 0.0:
		return timestamp
	return float(Time.get_ticks_usec()) / 1000000.0
