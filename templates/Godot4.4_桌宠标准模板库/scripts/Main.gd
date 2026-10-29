extends Node2D

const PET_WINDOW_ID := 0
const PET_WINDOW_SIZE := Vector2i(320, 320)

@onready var character: Sprite2D = $Character

var dragging := false
var drag_offset := Vector2i.ZERO

func _ready() -> void:
	var pet_window := get_window()
	pet_window.size = PET_WINDOW_SIZE
	pet_window.borderless = true
	pet_window.transparent = true
	pet_window.always_on_top = true
	_update_mouse_region()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _contains_character(event.position):
				dragging = true
				drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position(PET_WINDOW_ID)
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		move_pet_window(DisplayServer.mouse_get_position() - drag_offset)

func move_pet_window(screen_position: Vector2i) -> void:
	DisplayServer.window_set_position(screen_position, PET_WINDOW_ID)

func _contains_character(viewport_position: Vector2) -> bool:
	if character.texture == null:
		return false
	return character.get_rect().has_point(character.to_local(viewport_position))

func _update_mouse_region() -> void:
	if character.texture == null:
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return

	var character_rect := character.get_rect()
	var points := PackedVector2Array([
		character.to_global(character_rect.position),
		character.to_global(Vector2(character_rect.end.x, character_rect.position.y)),
		character.to_global(character_rect.end),
		character.to_global(Vector2(character_rect.position.x, character_rect.end.y))
	])
	get_window().mouse_passthrough_polygon = points
