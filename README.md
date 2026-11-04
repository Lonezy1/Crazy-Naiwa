# Crazy Naiwa

基于 Godot 4 的抽象奶蛙桌宠原型。

## 当前版本

`0.3.0`（升级右键菜单并新增音效支持）

## 当前能力

- 透明、无边框、置顶窗口
- 使用 `assets/character/stand.png` 作为角色立绘，支持呼吸与拖动弹性形变
- DVD 弹跳、任务栏蛄蛹、失重上浮后坠落、拖拽弹射
- 连续戳击充气并在第十次弹飞
- 最多 50 个本窗口内的物理分身，可用鼠标划动搅动；15 秒后自动清理，也可手动清理
- 右键菜单按动作、分身、偏好和窗口分组，提供图标、禁用态、音效开关与五档音量
- 音效由 `scripts/audio/PetAudio.gd` 统一管理，使用运行时短音效合成，不依赖来源未核实的外部音频素材
- `user://crazy_naiwa.cfg` 持久化置顶、整活开关、音效开关、音量和窗口位置

## 代码边界

- `scripts/app/Main.gd`：窗口、输入与菜单编排
- `scripts/ui/PetContextMenu.gd`：右键菜单结构、状态和命令信号
- `scripts/audio/PetAudio.gd`：音效总线、短音效生成、播放器池与限流
- `scripts/core/PetBehavior.gd`：不依赖场景节点的行为状态机
- `scripts/core/PetSettings.gd`：用户偏好持久化
- `scripts/platform/DesktopBounds.gd`：多屏工作区边界计算
- `scripts/entities/FrogVisual.gd`、`PetSwarm.gd`：角色表现与隔离的分身物理
- `scripts/ui/PetTheme.gd`：菜单色彩、间距、阴影、悬浮样式与图标
- `scenes/FrogVisual.tscn`：角色图片节点，编辑器画布和运行时共用

数据流为“鼠标/菜单输入 → `PetBehavior` 状态 → 窗口与角色渲染”，声音反馈由 `PetAudio` 消费行为事件；分身通过独立的 `PetSwarm` 实体模块接收鼠标扰动。配置继续统一使用现有 Godot `ConfigFile`，不引入第二套设置存储。

## 素材接入边界

站立立绘已接入；音效目前由运行时合成，未导入外部音频。未来素材放在 `assets/` 下并由对应资源模块接入；窗口逻辑与持久化逻辑保持独立。本地原始素材库 `奶蛙素材/` 被 Git 忽略，不会随代码提交。

素材归类约定见 [assets/README.md](assets/README.md)：角色、音效、字体和 UI 图标分开存放；每个外部素材需记录来源、授权和处理方式。

可复用的 Godot 桌宠起始工程、AI 起手提示词与编辑器嵌入设置说明见 [Godot4.4_桌宠标准模板库](templates/Godot4.4_桌宠标准模板库/README.md)。

## 运行

使用 Godot 4.7.2 打开项目根目录，运行主场景。右键奶蛙可选择动作、分身、行为/置顶/音效开关、音效音量、返回角落或退出。

无界面运行自动化测试：

```powershell
godot --headless --path . --script res://tests/test_pet_system.gd
```
