extends RefCounted

const INK := Color("#14221a")
const BODY := Color("#8ebf55")
const BODY_DARK := Color("#5f8f3c")
const CREAM := Color("#fbf7ef")
const HOVER := Color("#e8f1dc")
const SHADOW := Color(0.05, 0.10, 0.07, 0.16)
const MENU_ICON_ATLAS: Texture2D = preload("res://assets/ui/menu-icons.svg")

static func create_popup_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", BODY_DARK)
	theme.set_color("font_separator_color", "PopupMenu", BODY_DARK)
	theme.set_font_size("font_size", "PopupMenu", 14)
	theme.set_constant("h_separation", "PopupMenu", 10)
	theme.set_constant("v_separation", "PopupMenu", 2)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)
	theme.set_stylebox("panel", "PopupMenu", _panel_style())
	theme.set_stylebox("hover", "PopupMenu", _row_style(HOVER))
	theme.set_stylebox("separator", "PopupMenu", _separator_style())
	_set_control_styles(theme)
	return theme

static func create_result_card_style() -> StyleBoxFlat:
	var style := _panel_style()
	style.border_color = BODY_DARK
	style.set_border_width_all(2)
	style.shadow_size = 14
	return style

static func menu_icon(index: int) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = MENU_ICON_ATLAS
	texture.region = Rect2(index * 16, 0, 16, 16)
	return texture

static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BODY_DARK
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = SHADOW
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func _row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func _set_control_styles(theme: Theme) -> void:
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", BODY_DARK)
	for button_type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", button_type, _row_style(CREAM))
		theme.set_stylebox("hover", button_type, _row_style(HOVER))
		theme.set_stylebox("pressed", button_type, _row_style(BODY))
		theme.set_stylebox("disabled", button_type, _row_style(CREAM))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_stylebox("normal", "LineEdit", _input_style())
	theme.set_stylebox("focus", "LineEdit", _input_style(true))
	theme.set_stylebox("read_only", "LineEdit", _input_style())
	theme.set_stylebox("panel", "Tree", _panel_style())
	theme.set_stylebox("hover", "Tree", _row_style(HOVER))
	theme.set_stylebox("selected", "Tree", _row_style(HOVER))
	theme.set_stylebox("selected_focus", "Tree", _row_style(HOVER))

static func _input_style(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BODY_DARK if focused else BODY
	style.set_border_width_all(2 if focused else 1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func _separator_style() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = BODY_DARK
	style.thickness = 1
	style.grow_begin = 4
	style.grow_end = 4
	return style
