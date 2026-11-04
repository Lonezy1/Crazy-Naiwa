extends PopupMenu

const PetTheme = preload("res://scripts/ui/PetTheme.gd")

enum Command {
	DVD_BOUNCE = 1,
	SLITHER,
	FLOAT_FALL,
	SPAWN_CLONES,
	CLEAR_CLONES,
	MOVE_TO_CORNER,
	QUIT,
	TOGGLE_ANTICS,
	TOGGLE_ALWAYS_ON_TOP,
	TOGGLE_SOUND,
	SFX_VOLUME,
}

enum Setting {
	ANTICS_ENABLED,
	ALWAYS_ON_TOP,
	SOUND_ENABLED,
}

enum VolumeOption {
	MUTE = 100,
	QUARTER,
	HALF,
	THREE_QUARTERS,
	FULL,
}

signal command_selected(command: int)
signal setting_selected(setting: int, enabled: bool)
signal volume_selected(value: float)

const VOLUME_OPTIONS := [
	{"id": VolumeOption.MUTE, "value": 0.0, "label": "静音"},
	{"id": VolumeOption.QUARTER, "value": 0.25, "label": "25%"},
	{"id": VolumeOption.HALF, "value": 0.5, "label": "50%"},
	{"id": VolumeOption.THREE_QUARTERS, "value": 0.75, "label": "75%"},
	{"id": VolumeOption.FULL, "value": 1.0, "label": "100%"},
]

var volume_menu: PopupMenu
var _antics_enabled := true
var _always_on_top := true
var _sound_enabled := true

func _ready() -> void:
	theme = PetTheme.create_popup_theme()
	_build_items()
	id_pressed.connect(_on_menu_id_pressed)

func refresh_state(antics_enabled: bool, always_on_top: bool, sound_enabled: bool, sfx_volume: float, clone_count: int) -> void:
	_antics_enabled = antics_enabled
	_always_on_top = always_on_top
	_sound_enabled = sound_enabled
	set_item_checked(get_item_index(Command.TOGGLE_ANTICS), not antics_enabled)
	set_item_checked(get_item_index(Command.TOGGLE_ALWAYS_ON_TOP), always_on_top)
	set_item_checked(get_item_index(Command.TOGGLE_SOUND), sound_enabled)
	set_item_disabled(get_item_index(Command.CLEAR_CLONES), clone_count <= 0)
	_set_volume_checked(sfx_volume)

func _build_items() -> void:
	add_icon_item(PetTheme.menu_icon(0), "DVD 弹跳", Command.DVD_BOUNCE)
	add_icon_item(PetTheme.menu_icon(1), "立即蛄蛹", Command.SLITHER)
	add_icon_item(PetTheme.menu_icon(2), "顶端坠落", Command.FLOAT_FALL)
	add_separator()
	add_icon_item(PetTheme.menu_icon(3), "召唤 50 只分身", Command.SPAWN_CLONES)
	add_icon_item(PetTheme.menu_icon(4), "清理分身", Command.CLEAR_CLONES)
	add_separator()
	add_icon_check_item(PetTheme.menu_icon(7), "暂停整活", Command.TOGGLE_ANTICS)
	add_icon_check_item(PetTheme.menu_icon(8), "始终置顶", Command.TOGGLE_ALWAYS_ON_TOP)
	add_icon_check_item(PetTheme.menu_icon(10), "音效", Command.TOGGLE_SOUND)

	volume_menu = PopupMenu.new()
	volume_menu.name = "SfxVolumeMenu"
	volume_menu.theme = theme
	for option: Dictionary in VOLUME_OPTIONS:
		volume_menu.add_radio_check_item(option["label"], option["id"])
	volume_menu.id_pressed.connect(_on_volume_id_pressed)
	add_child(volume_menu)
	add_submenu_item("音效音量", volume_menu.name, Command.SFX_VOLUME)
	set_item_icon(get_item_index(Command.SFX_VOLUME), PetTheme.menu_icon(5))
	add_separator()
	add_icon_item(PetTheme.menu_icon(6), "回到屏幕右下角", Command.MOVE_TO_CORNER)
	add_icon_item(PetTheme.menu_icon(9), "退出奶蛙", Command.QUIT)

func _on_menu_id_pressed(id: int) -> void:
	match id:
		Command.TOGGLE_ANTICS:
			_antics_enabled = not _antics_enabled
			setting_selected.emit(Setting.ANTICS_ENABLED, _antics_enabled)
		Command.TOGGLE_ALWAYS_ON_TOP:
			_always_on_top = not _always_on_top
			setting_selected.emit(Setting.ALWAYS_ON_TOP, _always_on_top)
		Command.TOGGLE_SOUND:
			_sound_enabled = not _sound_enabled
			setting_selected.emit(Setting.SOUND_ENABLED, _sound_enabled)
		_:
			command_selected.emit(id)

func _on_volume_id_pressed(id: int) -> void:
	for option: Dictionary in VOLUME_OPTIONS:
		if option["id"] == id:
			volume_selected.emit(option["value"])
			return

func _set_volume_checked(value: float) -> void:
	var selected_value := clampf(roundf(value * 4.0) / 4.0, 0.0, 1.0)
	for option: Dictionary in VOLUME_OPTIONS:
		var item_index := volume_menu.get_item_index(option["id"])
		volume_menu.set_item_checked(item_index, is_equal_approx(float(option["value"]), selected_value))
