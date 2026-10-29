extends RefCounted

const INK := Color("#14221a")
const BODY := Color("#8ebf55")
const BODY_DARK := Color("#5f8f3c")
const CREAM := Color("#f4e9d2")
const HOVER := Color("#e1ecd4")
const TONGUE := Color("#cf7067")
const SHADOW := Color(0.05, 0.10, 0.07, 0.16)

static func create_popup_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", BODY_DARK)
	theme.set_color("font_separator_color", "PopupMenu", BODY_DARK)
	theme.set_font_size("font_size", "PopupMenu", 14)
	theme.set_stylebox("panel", "PopupMenu", _panel_style())
	theme.set_stylebox("hover", "PopupMenu", _row_style(HOVER))
	theme.set_stylebox("separator", "PopupMenu", _separator_style())
	return theme

static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BODY_DARK
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func _row_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func _separator_style() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = BODY_DARK
	style.thickness = 1
	style.grow_begin = 4
	style.grow_end = 4
	return style
