extends RefCounted

enum Kind { AVATAR, FORTUNE }

const MAX_AVATAR_FILE_BYTES := 12 * 1024 * 1024
const MAX_AVATAR_DIMENSION := 8192
const MAX_AVATAR_PIXELS := 16777216
const AVATAR_SIZE := 256
const STICKER_PIXEL_SIZES := [48, 64, 80]
const SUPPORTED_IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp"]

const AVATAR_OUTCOMES := [
	{"badge": "蛙友认证", "line_1": "进蛙友圈", "line_2": "今日贴贴"},
	{"badge": "本蛙盖章", "line_1": "桌面队友", "line_2": "准你摸鱼"},
	{"badge": "正式入编", "line_1": "摸鱼岗位", "line_2": "观察员蛙"},
	{"badge": "蛙蛙特聘", "line_1": "气氛组长", "line_2": "全场可爱"},
	{"badge": "扫描通过", "line_1": "人类合格", "line_2": "欢迎来蛙"},
	{"badge": "幸运加成", "line_1": "今日任务", "line_2": "和蛙贴贴"},
]

const FORTUNES := [
	{"badge": "摸鱼上签", "line_1": "先喝口水", "line_2": "再开文档"},
	{"badge": "小吉", "line_1": "好消息来啦", "line_2": "午饭快到"},
	{"badge": "蛙蛙预言", "line_1": "今日运势", "line_2": "就是这条"},
	{"badge": "宜下班", "line_1": "今天优秀", "line_2": "准时收工"},
	{"badge": "幸运色", "line_1": "奶蛙黄", "line_2": "看它一眼"},
	{"badge": "稳中带蛙", "line_1": "会好起来", "line_2": "别刷刷新"},
	{"badge": "大吉", "line_1": "好运很近", "line_2": "奶蛙也近"},
	{"badge": "宜专注", "line_1": "关个标签", "line_2": "大胜利"},
	{"badge": "蛙签提醒", "line_1": "先等等吧", "line_2": "吃点东西"},
	{"badge": "好运加载中", "line_1": "保持耐心", "line_2": "别狂点啦"},
	{"badge": "宜放松", "line_1": "够努力了", "line_2": "蛙准休息"},
	{"badge": "贵人运", "line_1": "贵人可能", "line_2": "刚散会了"},
	{"badge": "小小胜利", "line_1": "窗口会找到", "line_2": "就在那边"},
	{"badge": "蛙蛙守护", "line_1": "烦恼少点", "line_2": "蛙蛙陪你"},
	{"badge": "宜摸鱼", "line_1": "灵感来了", "line_2": "偷偷游来"},
	{"badge": "上上签", "line_1": "有人觉得", "line_2": "你很靠谱"},
]

static func supports_image_path(path: String) -> bool:
	return SUPPORTED_IMAGE_EXTENSIONS.has(path.get_extension().to_lower())

static func load_avatar(path: String) -> Dictionary:
	if not supports_image_path(path):
		return _failure("请选择 PNG、JPG、WebP 或 BMP 图片。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("图片无法读取，请换一张再试。")
	var file_size := file.get_length()
	file.close()
	if file_size <= 0 or file_size > MAX_AVATAR_FILE_BYTES:
		return _failure("图片文件为空或超过 12 MB。")

	var source := Image.new()
	if source.load(path) != OK:
		return _failure("奶蛙没认出这张图片，请换一张再试。")
	var width := source.get_width()
	var height := source.get_height()
	if width <= 0 or height <= 0 or width > MAX_AVATAR_DIMENSION or height > MAX_AVATAR_DIMENSION:
		return _failure("图片尺寸过大，请使用 8192 像素以内的图片。")
	if width * height > MAX_AVATAR_PIXELS:
		return _failure("图片分辨率过高，请换一张小一些的图片。")

	var fit_scale := minf(float(AVATAR_SIZE) / float(width), float(AVATAR_SIZE) / float(height))
	var fitted_size := Vector2i(
		maxi(1, roundi(width * fit_scale)),
		maxi(1, roundi(height * fit_scale))
	)
	source.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
	var avatar := Image.create(AVATAR_SIZE, AVATAR_SIZE, false, Image.FORMAT_RGBA8)
	avatar.fill(Color(0.0, 0.0, 0.0, 0.0))
	var destination := Vector2i((AVATAR_SIZE - fitted_size.x) / 2, (AVATAR_SIZE - fitted_size.y) / 2)
	avatar.blit_rect(source, Rect2i(Vector2i.ZERO, fitted_size), destination)
	return {"ok": true, "image": avatar}

static func create_avatar_result(
	avatar_texture: Texture2D,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var outcome := _pick(AVATAR_OUTCOMES, rng)
	var sticker_texture := _make_avatar_sticker(avatar_texture, rng)
	return {
		"kind": Kind.AVATAR,
		"title": "头像投喂",
		"badge": outcome["badge"],
		"line_1": outcome["line_1"],
		"line_2": outcome["line_2"],
		"avatar_texture": sticker_texture,
	}

static func draw_fortune(rng: RandomNumberGenerator = null) -> Dictionary:
	var fortune := _pick(FORTUNES, rng)
	return {
		"kind": Kind.FORTUNE,
		"title": "今日蛙签",
		"badge": fortune["badge"],
		"line_1": fortune["line_1"],
		"line_2": fortune["line_2"],
	}

static func _pick(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	var index := _pick_index(options.size(), rng)
	return options[index].duplicate(true)

static func _make_avatar_sticker(texture: Texture2D, rng: RandomNumberGenerator) -> Texture2D:
	if not is_instance_valid(texture):
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var pixel_size := int(STICKER_PIXEL_SIZES[_pick_index(STICKER_PIXEL_SIZES.size(), rng)])
	image.resize(pixel_size, pixel_size, Image.INTERPOLATE_NEAREST)
	image.resize(AVATAR_SIZE, AVATAR_SIZE, Image.INTERPOLATE_NEAREST)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var average := (color.r + color.g + color.b) / 3.0
			color.r = clampf(roundf((average + (color.r - average) * 1.35) * 3.0) / 3.0 * 1.06, 0.0, 1.0)
			color.g = clampf(roundf((average + (color.g - average) * 1.35) * 3.0) / 3.0 * 1.04, 0.0, 1.0)
			color.b = clampf(roundf((average + (color.b - average) * 1.35) * 3.0) / 3.0 * 0.92, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func _pick_index(option_count: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, option_count - 1) if rng else randi_range(0, option_count - 1)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
