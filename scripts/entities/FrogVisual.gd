extends Node2D

const PetTheme = preload("res://scripts/ui/PetTheme.gd")
const PetBehavior = preload("res://scripts/core/PetBehavior.gd")
const BASE_SIZE := 320.0
const BASE_IMAGE_SCALE := Vector2(0.403252, 0.403252)
const MAX_VISIBLE_INFLATION := 1.8
const GRAB_TEXTURE_PATH := "res://assets/character/drag_hold.png"
const STAND_TEXTURE: Texture2D = preload("res://assets/character/stand.png")

static var _texture_bounds_cache: Dictionary = {}

var velocity := Vector2.ZERO
var mode := PetBehavior.Mode.DVD_BOUNCE
var inflation_scale := 1.0
var impact_seconds := 0.0
var corner_flash_seconds := 0.0
var burst_seconds := 0.0
var drag_vector := Vector2.ZERO
var blink_seconds := 0.0
var idle_phase := 0.0
var base_scale := Vector2.ONE
var image_sprite: Sprite2D
var base_image_scale := Vector2.ONE
var stand_texture: Texture2D
var grab_texture: Texture2D
var display_size_scale := 1.0
var is_dragging := false
var idle_animation_enabled := true

func _ready() -> void:
	base_scale = scale
	image_sprite = get_node("CharacterImage") as Sprite2D
	stand_texture = image_sprite.texture
	grab_texture = load(GRAB_TEXTURE_PATH) as Texture2D if ResourceLoader.exists(GRAB_TEXTURE_PATH) else stand_texture
	image_sprite.scale = BASE_IMAGE_SCALE
	base_image_scale = image_sprite.scale
	image_sprite.z_index = -1

func _process(delta: float) -> void:
	if idle_animation_enabled:
		idle_phase += delta
	impact_seconds = maxf(0.0, impact_seconds - delta)
	corner_flash_seconds = maxf(0.0, corner_flash_seconds - delta)
	burst_seconds = maxf(0.0, burst_seconds - delta)
	blink_seconds = maxf(0.0, blink_seconds - delta)
	queue_redraw()
	if not idle_animation_enabled and impact_seconds <= 0.0 and corner_flash_seconds <= 0.0 and burst_seconds <= 0.0 and blink_seconds <= 0.0:
		set_process(false)

func set_idle_animation_enabled(enabled: bool) -> void:
	idle_animation_enabled = enabled
	if enabled:
		set_process(true)
	elif impact_seconds <= 0.0 and corner_flash_seconds <= 0.0 and burst_seconds <= 0.0 and blink_seconds <= 0.0:
		set_process(false)
	queue_redraw()

func apply_behavior(state: PetBehavior) -> void:
	mode = PetBehavior.Mode.DRAG if is_dragging else state.mode
	image_sprite.texture = grab_texture if is_dragging or state.mode == PetBehavior.Mode.DRAG else stand_texture
	velocity = state.velocity
	var inflation_progress := float(state.inflation_hits) / float(PetBehavior.MAX_POKE_COUNT - 1)
	inflation_scale = lerpf(1.0, MAX_VISIBLE_INFLATION, clampf(inflation_progress, 0.0, 1.0))
	scale = base_scale * inflation_scale
	impact_seconds = state.impact_seconds
	corner_flash_seconds = state.corner_flash_seconds
	drag_vector = state.drag_total

func set_display_size_scale(value: float) -> void:
	display_size_scale = maxf(0.15, value)
	base_scale = Vector2.ONE * display_size_scale
	scale = base_scale * inflation_scale

func set_dragging(value: bool) -> void:
	is_dragging = value
	if is_dragging:
		mode = PetBehavior.Mode.DRAG
	else:
		mode = PetBehavior.Mode.IDLE
	queue_redraw()

func play_burst() -> void:
	burst_seconds = 0.65
	set_process(true)
	play_blink()
	queue_redraw()

func play_impact() -> void:
	impact_seconds = 0.42
	set_process(true)
	queue_redraw()

func is_point_on_pet(viewport_position: Vector2) -> bool:
	var point := to_local(viewport_position)
	var normalized := Vector2(point.x / 78.0, point.y / 124.0)
	return normalized.length_squared() <= 1.0

func get_mouse_region() -> PackedVector2Array:
	var window_points := PackedVector2Array()
	for point in _content_outline():
		window_points.append(to_global(point))
	return window_points

func get_content_bounds() -> Rect2:
	if not is_instance_valid(image_sprite) or not is_instance_valid(image_sprite.texture):
		return Rect2(position, Vector2.ZERO)
	var texture_rect := _texture_local_bounds(image_sprite.texture)
	var sprite_transform := Transform2D(image_sprite.rotation, image_sprite.scale, 0.0, image_sprite.position)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for raw_point in [texture_rect.position, Vector2(texture_rect.end.x, texture_rect.position.y), texture_rect.end, Vector2(texture_rect.position.x, texture_rect.end.y)]:
		var point := Vector2(raw_point)
		var transformed: Vector2 = position + Vector2(sprite_transform * point) * scale
		minimum.x = minf(minimum.x, transformed.x)
		minimum.y = minf(minimum.y, transformed.y)
		maximum.x = maxf(maximum.x, transformed.x)
		maximum.y = maxf(maximum.y, transformed.y)
	return Rect2(minimum, maximum - minimum)

static func content_bounds_for_size(size: float) -> Rect2:
	var display_scale := size / BASE_SIZE
	var origin := Vector2(size * 0.55, size * 0.51)
	var base_rect := _texture_local_bounds(STAND_TEXTURE)
	var scale_factor := BASE_IMAGE_SCALE * display_scale
	var local_rect := Rect2(base_rect.position * scale_factor, base_rect.size * scale_factor)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for raw_point in [local_rect.position, Vector2(local_rect.end.x, local_rect.position.y), local_rect.end, Vector2(local_rect.position.x, local_rect.end.y)]:
		var point := Vector2(raw_point)
		var transformed: Vector2 = origin + point
		minimum.x = minf(minimum.x, transformed.x)
		minimum.y = minf(minimum.y, transformed.y)
		maximum.x = maxf(maximum.x, transformed.x)
		maximum.y = maxf(maximum.y, transformed.y)
	return Rect2(minimum, maximum - minimum)

static func _texture_local_bounds(texture: Texture2D) -> Rect2:
	var texture_id := texture.get_instance_id()
	if _texture_bounds_cache.has(texture_id):
		return _texture_bounds_cache[texture_id]
	var image := texture.get_image()
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		used_rect = Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	var local_rect := Rect2(
		Vector2(used_rect.position) - Vector2(texture.get_size()) * 0.5,
		Vector2(used_rect.size)
	)
	_texture_bounds_cache[texture_id] = local_rect
	return local_rect

static func _content_outline() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-22, -120), Vector2(18, -122), Vector2(49, -101),
		Vector2(69, -67), Vector2(78, -20), Vector2(75, 34),
		Vector2(62, 81), Vector2(45, 111), Vector2(16, 125),
		Vector2(-25, 116), Vector2(-54, 91), Vector2(-72, 53),
		Vector2(-79, 10), Vector2(-73, -42), Vector2(-56, -88)
	])

func play_blink() -> void:
	blink_seconds = 0.18
	set_process(true)
	queue_redraw()

func _draw() -> void:
	var is_dragging := mode == PetBehavior.Mode.DRAG
	var breathing := 0.0 if is_dragging or not idle_animation_enabled else sin(idle_phase * 2.0) * 0.025
	var stretch := 0.0
	var squish := 0.0
	var tilt := 0.0
	match mode:
		PetBehavior.Mode.SLITHER:
			stretch = 0.12 * sin((idle_phase + velocity.x * 0.001) * 12.0)
			squish = -absf(stretch) * 0.8
			tilt = 0.08 * sin(idle_phase * 6.0)
		PetBehavior.Mode.FLOAT:
			tilt = sin(idle_phase * 1.4) * 0.04
			squish = sin(idle_phase * 2.0) * 0.025
		PetBehavior.Mode.FALL, PetBehavior.Mode.LAUNCH:
			stretch = clampf(absf(velocity.y) / 1500.0, 0.0, 0.26)
			squish = -stretch * 0.58
			tilt = clampf(velocity.x / 1800.0, -0.18, 0.18)
		PetBehavior.Mode.DVD_BOUNCE:
			tilt = clampf(velocity.x / 2800.0, -0.08, 0.08)
	var scale_x := 1.0 + breathing + stretch - squish * 0.4
	var scale_y := 1.0 - breathing - stretch * 0.48 + squish
	if impact_seconds > 0.0 and not is_dragging:
		var impact := sin((0.42 - impact_seconds) * 24.0) * (impact_seconds / 0.42)
		scale_x *= 1.0 + impact * 0.23
		scale_y *= 1.0 - impact * 0.19
	image_sprite.scale = base_image_scale * Vector2(scale_x, scale_y)
	image_sprite.rotation = tilt
	var draw_transform := Transform2D(tilt, Vector2(scale_x, scale_y), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(draw_transform)
	_draw_frog()
	if corner_flash_seconds > 0.0:
		_draw_corner_burst()
	if burst_seconds > 0.0:
		_draw_burst()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frog() -> void:
	if blink_seconds > 0.0:
		draw_line(Vector2(-25, -98), Vector2(-8, -98), PetTheme.INK, 4.0, true)

func _draw_corner_burst() -> void:
	var strength := corner_flash_seconds
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var inner := Vector2(cos(angle), sin(angle)) * 78.0
		var outer := Vector2(cos(angle), sin(angle)) * (110.0 + 18.0 * sin(idle_phase * 24.0))
		draw_line(inner, outer, PetTheme.CREAM.lightened(0.18 * strength), 5.0)

func _draw_burst() -> void:
	var progress := 1.0 - burst_seconds / 0.65
	var radius := lerpf(62.0, 148.0, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, PetTheme.BODY_DARK, 8.0 * (1.0 - progress))
	for index in range(6):
		var angle := TAU * float(index) / 6.0 + idle_phase
		var point := Vector2(cos(angle), sin(angle)) * (radius * 0.72)
		draw_circle(point, 4.0 * (1.0 - progress), PetTheme.CREAM)
