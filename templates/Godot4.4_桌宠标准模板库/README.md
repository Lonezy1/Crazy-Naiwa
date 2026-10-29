# Godot 4.4+ 桌宠标准模板

这是一个可独立打开、复制并继续开发的最小 Godot 桌宠项目，不是奶蛙游戏的副本。模板按 Godot 4.4+ 项目格式建立，并使用本仓库当前的 Godot 4.7.2 做过导入和场景冒烟测试。

## 目录

```text
Godot4.4_桌宠标准模板库/
├── AI_START_PROMPT.txt
├── project.godot
├── assets/character/       # 放运行时使用的透明角色图
├── scenes/Main.tscn        # 主场景及 Sprite2D 占位节点
├── scripts/Main.gd         # 窗口初始化、角色命中和拖动
└── tests/test_template.gd  # headless 场景冒烟测试
```

## 开始使用

1. 在文件管理器中复制整个模板目录到新项目的位置。
2. 用 Godot 项目管理器导入复制目录中的 `project.godot`。
3. 将透明 PNG 放入 `assets/character/`，在 `Main.tscn` 的 `Character` 节点上设置纹理并调整大小、位置。
4. 新桌宠若有独立的运动规则，再按数据链路将行为状态从 `Main.gd` 拆到单独模块；不要为了“看起来模块化”提前创建空壳。

模板没有内置角色图片、玩法菜单或持久化。空模板不会保存鼠标位置或用户设置；需求确认需要记住窗口位置、偏好时，再用 `ConfigFile` 写入 `user://`。简单偏好不需要数据库。

## 关键区别：两种嵌入设置

- 项目中的 `window/subwindows/embed_subwindows` 控制项目创建的子窗口是否嵌入主窗口。
- Godot 编辑器的 **Game Embedding / Embed Game on Next Play** 控制 F5 运行游戏是否嵌入编辑器。这是编辑器设置，不由 `project.godot` 的 `Embed Subwindows` 代替，也不会随项目 ZIP 自动携带。

桌宠依赖可移动的 Windows 顶层窗口。测试桌面拖动、透明和置顶时，在编辑器的 Game 设置中关闭 **Embed Game on Next Play**，停止旧运行实例，再按 F5；也可以从 Godot 命令行使用 `--path <项目目录>` 启动已配置的主场景。若游戏仍处于编辑器嵌入视图，窗口移动 API 不能把它变成独立系统窗口，不要在每帧强行移动它。

实际窗口移动集中在 `move_pet_window()`，使用 `DisplayServer.window_set_position(position, 0)`；屏幕坐标通过 `DisplayServer.mouse_get_position()` 和 `DisplayServer.window_get_position(0)` 读取。不要把视口局部坐标当成桌面坐标。窗口透明样式由 `Window` 设置，鼠标命中区域通过 `mouse_passthrough_polygon` 管理；接入图片后要按实际角色轮廓校准命中形状。

Headless 检查不能证明 Windows 透明、穿透、置顶或拖动效果正确，这些要在关闭 Game Embedding 的独立窗口里手动验证。

## 检查

在模板目录运行：

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_template.gd
```

第一条检查项目导入和脚本解析；第二条检查主场景结构。窗口移动和透明等平台行为仍需使用 Windows 独立窗口实测。

不在 Git 中提交 `.godot/` 导入缓存或重复 ZIP。需要分发时，可从此目录临时压缩 ZIP；Git 中保留可审查、可维护的源文件。
