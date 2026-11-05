extends PopupMenu

const PetTheme = preload("res://scripts/ui/PetTheme.gd")
const PetSettingsStore = preload("res://scripts/core/PetSettings.gd")
const PetThrowProfile = preload("res://scripts/core/PetThrowProfile.gd")

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
	THROW_STRENGTH,
	THROW_STYLE,
	THROW_DURATION,
	THROW_DAMPING,
	THROW_GRAVITY,
	THROW_BOUNCE,
	STOP_THROW,
	SPAWN_SMALL_PET,
	CLEAR_SMALL_PETS,
	REMOVE_THIS_PET,
	FROG_SIZE,
	COLLISION_ENABLED,
	FLEET_STATUS,
	FALL_ON_SLOW_RELEASE,
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
signal fall_on_slow_release_selected(enabled: bool)
signal throw_strength_selected(value: float)
signal throw_style_selected(style: int)
signal throw_duration_selected(seconds: int)
signal throw_tuning_selected(tuning: int, value: float)
signal fleet_command_selected(command: int)
signal size_selected(size: int)
signal collision_enabled_selected(enabled: bool)

const SIZE_OPTIONS := [320, 461, 544, 640]

const VOLUME_OPTIONS := [
	{"id": VolumeOption.MUTE, "value": 0.0, "label": "静音"},
	{"id": VolumeOption.QUARTER, "value": 0.25, "label": "25%"},
	{"id": VolumeOption.HALF, "value": 0.5, "label": "50%"},
	{"id": VolumeOption.THREE_QUARTERS, "value": 0.75, "label": "75%"},
	{"id": VolumeOption.FULL, "value": 1.0, "label": "100%"},
]

var volume_menu: PopupMenu
var long_press_menu: PopupMenu
var throw_strength_menu: PopupMenu
var throw_style_menu: PopupMenu
var throw_duration_menu: PopupMenu
var throw_tuning_menus: Dictionary = {}
var size_menu: PopupMenu
var _command_menus: Dictionary = {}
var _antics_enabled := true
var _always_on_top := true
var _sound_enabled := true
var _collision_enabled := true
var _fall_on_slow_release := false
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
	can_spawn: bool = true,
	throw_strength: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["strength"],
	throw_damping: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["damping"],
	throw_gravity_scale: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["gravity_scale"],
	throw_bounce: float = PetThrowProfile.PRESETS[PetThrowProfile.Style.STANDARD]["bounce"],
	throw_style: int = PetThrowProfile.DEFAULT_STYLE,
	throw_duration_seconds: int = PetThrowProfile.DEFAULT_DURATION,
	throw_active: bool = false,
	fall_on_slow_release: bool = false
) -> void:
	_antics_enabled = antics_enabled
	_always_on_top = always_on_top
	_sound_enabled = sound_enabled
	_collision_enabled = collisions_enabled
	_fall_on_slow_release = fall_on_slow_release
	_set_checked(Command.TOGGLE_ANTICS, not antics_enabled)
	_set_checked(Command.TOGGLE_ALWAYS_ON_TOP, always_on_top)
	_set_checked(Command.TOGGLE_SOUND, sound_enabled)
	_set_disabled(Command.CLEAR_CLONES, clone_count <= 0)
	if not fleet_only:
		_set_volume_checked(sfx_volume)
		_set_long_press_mode_checked(long_press_mode)
		_set_checked(Command.FALL_ON_SLOW_RELEASE, fall_on_slow_release)
		_set_disabled(Command.FALL_ON_SLOW_RELEASE, long_press_mode != LongPressOption.TOSS)
		_set_throw_strength_checked(throw_strength)
		_set_throw_style_checked(throw_style)
		_set_throw_duration_checked(throw_duration_seconds)
		_set_throw_tuning_checked(PetSettingsStore.ThrowTuning.DAMPING, throw_damping)
		_set_throw_tuning_checked(PetSettingsStore.ThrowTuning.GRAVITY_SCALE, throw_gravity_scale)
		_set_throw_tuning_checked(PetSettingsStore.ThrowTuning.BOUNCE, throw_bounce)
		_set_disabled(Command.THROW_DURATION, throw_style != PetThrowProfile.Style.MADNESS)
	_set_disabled(Command.STOP_THROW, not throw_active)
	if size_menu:
		_set_size_checked(frog_size)
	_set_checked(Command.COLLISION_ENABLED, collisions_enabled)
	_set_disabled(Command.SPAWN_SMALL_PET, not can_spawn)
	_set_disabled(Command.CLEAR_SMALL_PETS, small_pet_count <= 0)
	_set_text(Command.FLEET_STATUS, "小奶蛙 %d / %d" % [small_pet_count, 100])
	_set_disabled(Command.FLEET_STATUS, true)

func _build_items() -> void:
	if fleet_only:
		_build_fleet_items()
		return
	var behavior_menu := _build_group("行为", "BehaviorMenu", 0)
	_add_item(behavior_menu, "DVD 弹跳", Command.DVD_BOUNCE)
	_add_item(behavior_menu, "立即蛄蛹", Command.SLITHER)
	_add_item(behavior_menu, "顶端坠落", Command.FLOAT_FALL)
	_add_item(behavior_menu, "回到屏幕右下角", Command.MOVE_TO_CORNER)
	behavior_menu.add_separator()
	_add_item(behavior_menu, "停止甩飞", Command.STOP_THROW)

	_build_throw_menu()

	var fleet_menu := _build_group("分身与碰撞", "FleetMenu", 3)
	_add_item(fleet_menu, "召唤 50 只分身", Command.SPAWN_CLONES)
	_add_item(fleet_menu, "清理分身", Command.CLEAR_CLONES)
	_add_item(fleet_menu, "生小奶蛙", Command.SPAWN_SMALL_PET)
	_add_item(fleet_menu, "清理全部小奶蛙", Command.CLEAR_SMALL_PETS)
	_add_item(fleet_menu, "小奶蛙 0 / 100", Command.FLEET_STATUS)
	_add_check_item(fleet_menu, "奶蛙间碰撞", Command.COLLISION_ENABLED)

	_build_preferences_menu()
	add_separator()
	_add_item(self, "退出奶蛙", Command.QUIT, 9)

func _build_fleet_items() -> void:
	var current_menu := _build_group("当前奶蛙", "CurrentPetMenu", 3)
	_add_item(current_menu, "生小奶蛙", Command.SPAWN_SMALL_PET)
	_add_item(current_menu, "清理全部小奶蛙", Command.CLEAR_SMALL_PETS)
	_build_size_menu(current_menu)

	var fleet_menu := _build_group("分身与碰撞", "FleetMenu", 4)
	_add_item(fleet_menu, "小奶蛙 0 / 100", Command.FLEET_STATUS)
	_add_check_item(fleet_menu, "奶蛙间碰撞", Command.COLLISION_ENABLED)
	add_separator()
	_add_item(self, "退出这只奶蛙", Command.REMOVE_THIS_PET, 9)

func _build_group(label: String, menu_name: String, icon_index: int) -> PopupMenu:
	var group_menu := PopupMenu.new()
	group_menu.name = menu_name
	group_menu.theme = theme
	group_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(group_menu)
	add_submenu_item(label, group_menu.name, -1)
	set_item_icon(get_item_count() - 1, PetTheme.menu_icon(icon_index))
	return group_menu

func _add_item(target_menu: PopupMenu, label: String, command: int, icon_index: int = -1) -> void:
	if icon_index >= 0:
		target_menu.add_icon_item(PetTheme.menu_icon(icon_index), label, command)
	else:
		target_menu.add_item(label, command)
	_command_menus[command] = target_menu

func _add_check_item(target_menu: PopupMenu, label: String, command: int) -> void:
	target_menu.add_check_item(label, command)
	_command_menus[command] = target_menu

func _build_throw_menu() -> void:
	var throw_menu := _build_group("甩动手感", "ThrowMenu", 1)
	throw_style_menu = PopupMenu.new()
	throw_style_menu.name = "ThrowStyleMenu"
	throw_style_menu.theme = theme
	throw_style_menu.add_radio_check_item("标准", PetThrowProfile.Style.STANDARD)
	throw_style_menu.add_radio_check_item("弹力球", PetThrowProfile.Style.BOUNCY)
	throw_style_menu.add_radio_check_item("疯癫循环", PetThrowProfile.Style.MADNESS)
	throw_style_menu.id_pressed.connect(_on_throw_style_id_pressed)
	add_child(throw_style_menu)
	_add_submenu(throw_menu, "玩法风格", throw_style_menu, Command.THROW_STYLE)

	throw_duration_menu = PopupMenu.new()
	throw_duration_menu.name = "ThrowDurationMenu"
	throw_duration_menu.theme = theme
	throw_duration_menu.add_radio_check_item("10 秒", PetThrowProfile.Duration.TEN_SECONDS)
	throw_duration_menu.add_radio_check_item("30 秒", PetThrowProfile.Duration.THIRTY_SECONDS)
	throw_duration_menu.add_radio_check_item("持续运行", PetThrowProfile.Duration.CONTINUOUS)
	throw_duration_menu.id_pressed.connect(_on_throw_duration_id_pressed)
	add_child(throw_duration_menu)
	_add_submenu(throw_menu, "疯癫时长", throw_duration_menu, Command.THROW_DURATION)

	long_press_menu = PopupMenu.new()
	long_press_menu.name = "LongPressModeMenu"
	long_press_menu.theme = theme
	long_press_menu.add_radio_check_item("移动桌宠", LongPressOption.MOVE)
	long_press_menu.add_radio_check_item("甩动整活", LongPressOption.TOSS)
	long_press_menu.id_pressed.connect(_on_long_press_mode_id_pressed)
	add_child(long_press_menu)
	_add_submenu(throw_menu, "长按模式", long_press_menu, Command.LONG_PRESS_MODE)
	_add_check_item(throw_menu, "慢速松手后下坠", Command.FALL_ON_SLOW_RELEASE)

	throw_strength_menu = PopupMenu.new()
	throw_strength_menu.name = "ThrowStrengthMenu"
	throw_strength_menu.theme = theme
	for index in range(PetThrowProfile.STRENGTH_OPTIONS.size()):
		var strength: float = PetThrowProfile.STRENGTH_OPTIONS[index]
		throw_strength_menu.add_radio_check_item("%d%%" % roundi(strength * 100.0), 50 + index)
	throw_strength_menu.id_pressed.connect(_on_throw_strength_id_pressed)
	add_child(throw_strength_menu)
	_add_submenu(throw_menu, "甩飞力度", throw_strength_menu, Command.THROW_STRENGTH)

	_build_throw_tuning_menu(
		throw_menu,
		PetSettingsStore.ThrowTuning.DAMPING,
		Command.THROW_DAMPING,
		"甩动与碰撞阻尼",
		"ThrowDampingMenu",
		PetThrowProfile.DAMPING_OPTIONS
	)
	_build_throw_tuning_menu(
		throw_menu,
		PetSettingsStore.ThrowTuning.GRAVITY_SCALE,
		Command.THROW_GRAVITY,
		"甩飞重力",
		"ThrowGravityMenu",
		PetThrowProfile.GRAVITY_SCALE_OPTIONS,
		true
	)
	_build_throw_tuning_menu(
		throw_menu,
		PetSettingsStore.ThrowTuning.BOUNCE,
		Command.THROW_BOUNCE,
		"甩动与碰撞回弹",
		"ThrowBounceMenu",
		PetThrowProfile.BOUNCE_OPTIONS,
		true,
		true
	)

func _build_preferences_menu() -> void:
	var preference_menu := _build_group("偏好设置", "PreferencesMenu", 7)
	_add_check_item(preference_menu, "暂停整活", Command.TOGGLE_ANTICS)
	_add_check_item(preference_menu, "始终置顶", Command.TOGGLE_ALWAYS_ON_TOP)
	_add_check_item(preference_menu, "音效", Command.TOGGLE_SOUND)
	_build_size_menu(preference_menu)
	volume_menu = PopupMenu.new()
	volume_menu.name = "SfxVolumeMenu"
	volume_menu.theme = theme
	for option: Dictionary in VOLUME_OPTIONS:
		volume_menu.add_radio_check_item(option["label"], option["id"])
	volume_menu.id_pressed.connect(_on_volume_id_pressed)
	add_child(volume_menu)
	_add_submenu(preference_menu, "音效音量", volume_menu, Command.SFX_VOLUME)

func _add_submenu(parent_menu: PopupMenu, label: String, child_menu: PopupMenu, command: int) -> void:
	var old_parent := child_menu.get_parent()
	if old_parent != parent_menu:
		if old_parent:
			old_parent.remove_child(child_menu)
		parent_menu.add_child(child_menu)
	parent_menu.add_submenu_item(label, child_menu.name, command)
	_command_menus[command] = parent_menu



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
		Command.FALL_ON_SLOW_RELEASE:
			_fall_on_slow_release = not _fall_on_slow_release
			fall_on_slow_release_selected.emit(_fall_on_slow_release)
		Command.THROW_DAMPING, Command.THROW_GRAVITY, Command.THROW_BOUNCE:
			pass
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

func _on_throw_style_id_pressed(id: int) -> void:
	if id >= PetThrowProfile.Style.STANDARD and id <= PetThrowProfile.Style.MADNESS:
		throw_style_selected.emit(id)

func _on_throw_duration_id_pressed(id: int) -> void:
	if PetThrowProfile.is_valid_duration(id):
		throw_duration_selected.emit(id)

func _on_throw_strength_id_pressed(id: int) -> void:
	var option_index := id - 50
	if option_index >= 0 and option_index < PetThrowProfile.STRENGTH_OPTIONS.size():
		throw_strength_selected.emit(PetThrowProfile.STRENGTH_OPTIONS[option_index])

func _on_throw_tuning_id_pressed(id: int, tuning: int) -> void:
	var tuning_menu: PopupMenu = throw_tuning_menus.get(tuning, {}).get("menu")
	var options: Array = throw_tuning_menus.get(tuning, {}).get("options", [])
	if tuning_menu == null or id < 0 or id >= options.size():
		return
	throw_tuning_selected.emit(tuning, float(options[id]))

func _on_size_id_pressed(id: int) -> void:
	if id in SIZE_OPTIONS:
		size_selected.emit(id)

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

func _set_throw_strength_checked(value: float) -> void:
	if not throw_strength_menu:
		return
	for index in range(PetThrowProfile.STRENGTH_OPTIONS.size()):
		var strength: float = PetThrowProfile.STRENGTH_OPTIONS[index]
		throw_strength_menu.set_item_checked(
			throw_strength_menu.get_item_index(50 + index),
			is_equal_approx(strength, value)
		)

func _set_throw_style_checked(value: int) -> void:
	for style in range(throw_style_menu.get_item_count()):
		throw_style_menu.set_item_checked(style, style == value)

func _set_throw_duration_checked(value: int) -> void:
	for index in range(throw_duration_menu.get_item_count()):
		throw_duration_menu.set_item_checked(
			index,
			throw_duration_menu.get_item_id(index) == value
		)

func _set_throw_tuning_checked(tuning: int, value: float) -> void:
	var entry: Dictionary = throw_tuning_menus.get(tuning, {})
	var tuning_menu: PopupMenu = entry.get("menu")
	var options: Array = entry.get("options", [])
	if tuning_menu == null:
		return
	for index in range(options.size()):
		tuning_menu.set_item_checked(index, is_equal_approx(float(options[index]), value))

func _build_throw_tuning_menu(
	parent_menu: PopupMenu,
	tuning: int,
	command: int,
	label: String,
	menu_name: String,
	options: Array,
	show_percent: bool = false,
	show_off: bool = false
) -> void:
	var tuning_menu := PopupMenu.new()
	tuning_menu.name = menu_name
	tuning_menu.theme = theme
	for index in range(options.size()):
		var value := float(options[index])
		var option_label := "%.1f" % value
		if show_percent:
			option_label = "%d%%" % roundi(value * 100.0)
		if show_off and is_zero_approx(value):
			option_label = "关闭"
		tuning_menu.add_radio_check_item(option_label, index)
	tuning_menu.id_pressed.connect(_on_throw_tuning_id_pressed.bind(tuning))
	add_child(tuning_menu)
	throw_tuning_menus[tuning] = {"menu": tuning_menu, "options": options}
	_add_submenu(parent_menu, label, tuning_menu, command)

func _set_size_checked(value: int) -> void:
	for size in SIZE_OPTIONS:
		size_menu.set_item_checked(size_menu.get_item_index(size), size == value)

func _build_size_menu(parent_menu: PopupMenu) -> void:
	size_menu = PopupMenu.new()
	size_menu.name = "FrogSizeMenu"
	size_menu.theme = theme
	for size in SIZE_OPTIONS:
		size_menu.add_radio_check_item("%dpx" % size, size)
	size_menu.id_pressed.connect(_on_size_id_pressed)
	add_child(size_menu)
	_add_submenu(parent_menu, "大小", size_menu, Command.FROG_SIZE)

func _set_checked(command: int, checked: bool) -> void:
	var target_menu: PopupMenu = _command_menus.get(command, self)
	var index := target_menu.get_item_index(command)
	if index >= 0:
		target_menu.set_item_checked(index, checked)

func _set_disabled(command: int, disabled: bool) -> void:
	var target_menu: PopupMenu = _command_menus.get(command, self)
	var index := target_menu.get_item_index(command)
	if index >= 0:
		target_menu.set_item_disabled(index, disabled)

func _set_text(command: int, text_value: String) -> void:
	var target_menu: PopupMenu = _command_menus.get(command, self)
	var index := target_menu.get_item_index(command)
	if index >= 0:
		target_menu.set_item_text(index, text_value)
