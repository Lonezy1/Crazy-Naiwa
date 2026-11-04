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
	LONG_PRESS_MODE,
	SPAWN_SMALL_PET,
	CLEAR_SMALL_PETS,
	REMOVE_THIS_PET,
	FROG_SIZE,
	COLLISION_ENABLED,
	COLLISION_STRENGTH,
	FLEET_STATUS,
}

enum Setting {
	ANTICS_ENABLED,
	ALWAYS_ON_TOP,
	SOUND_ENABLED,
}

enum LongPressOption {
	MOVE = 0,
	TOSS,
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
signal long_press_mode_selected(mode: int)
signal fleet_command_selected(command: int)
signal size_selected(size: int)
signal collision_enabled_selected(enabled: bool)
signal collision_strength_selected(value: float)

const SIZE_OPTIONS := [320, 461, 544, 640]
const COLLISION_STRENGTH_OPTIONS := [0.65, 0.85, 1.0, 1.15]

const VOLUME_OPTIONS := [
	{"id": VolumeOption.MUTE, "value": 0.0, "label": "静音"},
	{"id": VolumeOption.QUARTER, "value": 0.25, "label": "25%"},
	{"id": VolumeOption.HALF, "value": 0.5, "label": "50%"},
	{"id": VolumeOption.THREE_QUARTERS, "value": 0.75, "label": "75%"},
	{"id": VolumeOption.FULL, "value": 1.0, "label": "100%"},
]

var volume_menu: PopupMenu
var long_press_menu: PopupMenu
var size_menu: PopupMenu
var collision_menu: PopupMenu
var _antics_enabled := true
var _always_on_top := true
var _sound_enabled := true
var _collision_enabled := true
var fleet_only := false

func _ready() -> void:
	theme = PetTheme.create_popup_theme()
	_build_items()
	id_pressed.connect(_on_menu_id_pressed)

func refresh_state(
	antics_enabled: bool,
	always_on_top: bool,
	sound_enabled: bool,
	sfx_volume: float,
	clone_count: int,
	long_press_mode: int,
	frog_size: int = 320,
	small_pet_count: int = 0,
	collisions_enabled: bool = true,
	collision_strength: float = 1.0,
	can_spawn: bool = true
) -> void:
	_antics_enabled = antics_enabled
	_always_on_top = always_on_top
	_sound_enabled = sound_enabled
	_collision_enabled = collisions_enabled
	_set_checked(Command.TOGGLE_ANTICS, not antics_enabled)
	_set_checked(Command.TOGGLE_ALWAYS_ON_TOP, always_on_top)
	_set_checked(Command.TOGGLE_SOUND, sound_enabled)
	_set_disabled(Command.CLEAR_CLONES, clone_count <= 0)
	if not fleet_only:
		_set_volume_checked(sfx_volume)
		_set_long_press_mode_checked(long_press_mode)
	if size_menu:
		_set_size_checked(frog_size)
	if collision_menu:
		_set_collision_checked(collision_strength)
	_set_checked(Command.COLLISION_ENABLED, collisions_enabled)
	_set_disabled(Command.SPAWN_SMALL_PET, not can_spawn)
	_set_disabled(Command.CLEAR_SMALL_PETS, small_pet_count <= 0)
	_set_text(Command.FLEET_STATUS, "小奶蛙 %d / %d" % [small_pet_count, 100])
	_set_disabled(Command.FLEET_STATUS, true)

func _build_items() -> void:
	if fleet_only:
		add_item("小奶蛙 0 / 100", Command.FLEET_STATUS)
		add_icon_item(PetTheme.menu_icon(3), "生小奶蛙", Command.SPAWN_SMALL_PET)
		add_icon_item(PetTheme.menu_icon(4), "清理全部小奶蛙", Command.CLEAR_SMALL_PETS)
		add_icon_item(PetTheme.menu_icon(9), "退出这只奶蛙", Command.REMOVE_THIS_PET)
		add_check_item("奶蛙间碰撞", Command.COLLISION_ENABLED)
		_build_size_menu()
		_build_collision_menu()
		return
	add_icon_item(PetTheme.menu_icon(0), "DVD 弹跳", Command.DVD_BOUNCE)
	add_icon_item(PetTheme.menu_icon(1), "立即蛄蛹", Command.SLITHER)
	add_icon_item(PetTheme.menu_icon(2), "顶端坠落", Command.FLOAT_FALL)
	add_separator()
	add_icon_item(PetTheme.menu_icon(3), "召唤 50 只分身", Command.SPAWN_CLONES)
	add_icon_item(PetTheme.menu_icon(4), "清理分身", Command.CLEAR_CLONES)
	add_icon_item(PetTheme.menu_icon(3), "生小奶蛙", Command.SPAWN_SMALL_PET)
	add_icon_item(PetTheme.menu_icon(4), "清理全部小奶蛙", Command.CLEAR_SMALL_PETS)
	add_item("小奶蛙 0 / 100", Command.FLEET_STATUS)
	add_check_item("奶蛙间碰撞", Command.COLLISION_ENABLED)
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

	long_press_menu = PopupMenu.new()
	long_press_menu.name = "LongPressModeMenu"
	long_press_menu.theme = theme
	long_press_menu.add_radio_check_item("移动桌宠", LongPressOption.MOVE)
	long_press_menu.add_radio_check_item("甩动整活", LongPressOption.TOSS)
	long_press_menu.id_pressed.connect(_on_long_press_mode_id_pressed)
	add_child(long_press_menu)
	add_submenu_item("长按模式", long_press_menu.name, Command.LONG_PRESS_MODE)
	set_item_icon(get_item_index(Command.LONG_PRESS_MODE), PetTheme.menu_icon(1))

	_build_size_menu()
	_build_collision_menu()
	add_submenu_item("反弹强度", collision_menu.name, Command.COLLISION_STRENGTH)
	set_item_icon(get_item_index(Command.COLLISION_STRENGTH), PetTheme.menu_icon(2))

	if fleet_only:
		set_item_disabled(get_item_index(Command.SPAWN_CLONES), true)
		set_item_disabled(get_item_index(Command.CLEAR_CLONES), true)
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
		Command.SPAWN_SMALL_PET, Command.CLEAR_SMALL_PETS, Command.REMOVE_THIS_PET:
			fleet_command_selected.emit(id)
		Command.COLLISION_ENABLED:
			_collision_enabled = not _collision_enabled
			collision_enabled_selected.emit(_collision_enabled)
		Command.COLLISION_STRENGTH:
			command_selected.emit(id)
		_:
			command_selected.emit(id)

func _on_volume_id_pressed(id: int) -> void:
	for option: Dictionary in VOLUME_OPTIONS:
		if option["id"] == id:
			volume_selected.emit(option["value"])
			return

func _on_long_press_mode_id_pressed(id: int) -> void:
	if id == LongPressOption.MOVE or id == LongPressOption.TOSS:
		long_press_mode_selected.emit(id)

func _on_size_id_pressed(id: int) -> void:
	if id in SIZE_OPTIONS:
		size_selected.emit(id)

func _on_collision_id_pressed(id: int) -> void:
	if id >= 10 and id < 10 + COLLISION_STRENGTH_OPTIONS.size():
		collision_strength_selected.emit(COLLISION_STRENGTH_OPTIONS[id - 10])

func _set_volume_checked(value: float) -> void:
	var selected_value := clampf(roundf(value * 4.0) / 4.0, 0.0, 1.0)
	for option: Dictionary in VOLUME_OPTIONS:
		var item_index := volume_menu.get_item_index(option["id"])
		volume_menu.set_item_checked(item_index, is_equal_approx(float(option["value"]), selected_value))

func _set_long_press_mode_checked(value: int) -> void:
	if not long_press_menu:
		return
	long_press_menu.set_item_checked(
		long_press_menu.get_item_index(LongPressOption.MOVE),
		value == LongPressOption.MOVE
	)
	long_press_menu.set_item_checked(
		long_press_menu.get_item_index(LongPressOption.TOSS),
		value == LongPressOption.TOSS
	)

func _set_size_checked(value: int) -> void:
	for size in SIZE_OPTIONS:
		size_menu.set_item_checked(size_menu.get_item_index(size), size == value)

func _set_collision_checked(strength: float) -> void:
	for index in range(COLLISION_STRENGTH_OPTIONS.size()):
		collision_menu.set_item_checked(
			collision_menu.get_item_index(10 + index),
			is_equal_approx(COLLISION_STRENGTH_OPTIONS[index], strength)
		)

func _build_size_menu() -> void:
	size_menu = PopupMenu.new()
	size_menu.name = "FrogSizeMenu"
	size_menu.theme = theme
	for size in SIZE_OPTIONS:
		size_menu.add_radio_check_item("%dpx" % size, size)
	size_menu.id_pressed.connect(_on_size_id_pressed)
	add_child(size_menu)
	add_submenu_item("大小", size_menu.name, Command.FROG_SIZE)
	set_item_icon(get_item_index(Command.FROG_SIZE), PetTheme.menu_icon(7))

func _build_collision_menu() -> void:
	collision_menu = PopupMenu.new()
	collision_menu.name = "CollisionMenu"
	collision_menu.theme = theme
	for index in range(COLLISION_STRENGTH_OPTIONS.size()):
		collision_menu.add_radio_check_item("反弹强度 %d%%" % roundi(COLLISION_STRENGTH_OPTIONS[index] * 100.0), 10 + index)
	collision_menu.id_pressed.connect(_on_collision_id_pressed)
	add_child(collision_menu)
	add_submenu_item("反弹强度", collision_menu.name, Command.COLLISION_STRENGTH)
	set_item_icon(get_item_index(Command.COLLISION_STRENGTH), PetTheme.menu_icon(2))

func _set_checked(command: int, checked: bool) -> void:
	var index := get_item_index(command)
	if index >= 0:
		set_item_checked(index, checked)

func _set_disabled(command: int, disabled: bool) -> void:
	var index := get_item_index(command)
	if index >= 0:
		set_item_disabled(index, disabled)

func _set_text(command: int, text_value: String) -> void:
	var index := get_item_index(command)
	if index >= 0:
		set_item_text(index, text_value)
