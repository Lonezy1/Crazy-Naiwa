extends RefCounted

## Mouse gesture classifier shared by the window input layer and tests.
## It deliberately does not move the window or mutate behavior state.

enum Phase { IDLE, PRESSED, DRAGGING }

const HOLD_THRESHOLD_SECONDS := 0.45
const MOVE_THRESHOLD_PIXELS := 10.0
const VELOCITY_WINDOW_SECONDS := 0.12

var phase := Phase.IDLE
var press_position := Vector2.ZERO
var current_position := Vector2.ZERO
var press_time := 0.0
var _samples: Array[Dictionary] = []

func begin(position: Vector2, timestamp: float = -1.0) -> void:
	var now := _resolve_timestamp(timestamp)
	phase = Phase.PRESSED
	press_position = position
	current_position = position
	press_time = now
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
		"duration": now - press_time,
		"total": current_position - press_position,
		"release_velocity": _estimate_velocity(),
	}
	reset()
	return result

func reset() -> void:
	phase = Phase.IDLE
	_samples.clear()

func _result(started_drag: bool, timestamp: float) -> Dictionary:
	return {
		"dragging": phase == Phase.DRAGGING,
		"started_drag": started_drag,
		"position": current_position,
		"duration": timestamp - press_time,
		"total": current_position - press_position,
		"release_velocity": _estimate_velocity(),
	}

func _empty_result() -> Dictionary:
	return {
		"dragging": false,
		"started_drag": false,
		"position": current_position,
		"duration": 0.0,
		"total": Vector2.ZERO,
		"release_velocity": Vector2.ZERO,
	}

func _record_sample(position: Vector2, timestamp: float) -> void:
	_samples.append({"position": position, "time": timestamp})
	var cutoff := timestamp - VELOCITY_WINDOW_SECONDS
	while _samples.size() > 2 and float(_samples[0]["time"]) < cutoff:
		_samples.pop_front()

func _estimate_velocity() -> Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	var first: Dictionary = _samples[0]
	var last: Dictionary = _samples[_samples.size() - 1]
	var elapsed := float(last["time"]) - float(first["time"])
	if elapsed <= 0.0001:
		return Vector2.ZERO
	return (last["position"] - first["position"]) / elapsed

func _resolve_timestamp(timestamp: float) -> float:
	if timestamp >= 0.0:
		return timestamp
	return float(Time.get_ticks_msec()) / 1000.0
