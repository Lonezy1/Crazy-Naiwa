extends RefCounted

enum Source { EDGE, PET, MIXED }

const MINIMUM_SPEED := 85.0

var body_id: int
var normal: Vector2
var speed: float
var source: int

func _init(id: int, impact_normal: Vector2, impact_speed: float, impact_source: int) -> void:
	body_id = id
	normal = impact_normal.normalized()
	speed = impact_speed
	source = impact_source

func merge(impact_normal: Vector2, impact_speed: float, impact_source: int) -> void:
	var combined := normal * speed + impact_normal.normalized() * impact_speed
	if not combined.is_zero_approx():
		normal = combined.normalized()
	speed = maxf(speed, impact_speed)
	if source != impact_source:
		source = Source.MIXED
