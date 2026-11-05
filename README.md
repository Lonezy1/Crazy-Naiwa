# Crazy Naiwa

基于 Godot 4 的抽象奶蛙桌宠原型。

## 当前版本

`0.4.3`（甩飞按加速度增强并支持力度调节）

## 当前能力

- 透明、无边框、置顶窗口
- 使用 `assets/character/stand.png` 作为角色立绘，支持呼吸与动作弹性形变，拖动时保持立绘比例
- DVD 弹跳、任务栏蛄蛹、失重上浮后坠落
- 可配置长按模式：长按并移动可定位桌宠，或启用甩动整活；甩飞按末段鼠标速度和加速度计算初速度，并可在右键菜单选择 80%-180% 力度；低重力轨迹更持久，抵达工作区边缘后反弹；暂停自主整活时，手动触发的动作仍会完成
- 连续戳击充气并在第十次弹飞
- 大小菜单可设置 320、461、544、640 px；任意奶蛙可生成小一号后代，最多 100 只且无自动过期，可单独退出或一次清理全部
- 多只奶蛙使用共享固定步长物理，长按拖动作为碰撞源，碰撞可连锁传递并在各显示器工作区边缘反弹；松手后的奶蛙静止但仍可被撞动
- 最多 50 个本窗口内的物理分身，可用鼠标划动搅动；15 秒后自动清理，也可手动清理
- 右键菜单按动作、分身、偏好和窗口分组，提供图标、禁用态、音效开关与五档音量
- 音效由 `scripts/audio/PetAudio.gd` 统一管理，使用运行时短音效合成，不依赖来源未核实的外部音频素材
- `user://crazy_naiwa.cfg` 统一持久化置顶、整活开关、音效开关、音量、甩飞力度、窗口位置、主奶蛙尺寸、后代奶蛙位置/尺寸和碰撞参数

## 代码边界

- `scripts/app/Main.gd`：窗口、输入与菜单编排
- `scripts/ui/PetContextMenu.gd`：右键菜单结构、状态和命令信号
- `scripts/audio/PetAudio.gd`：音效总线、短音效生成、播放器池与限流
- `scripts/input/PetGesture.gd`：纯输入手势分类，识别长按、拖动和近期甩动速度
- `scripts/core/PetBehavior.gd`：不依赖场景节点的行为状态机
- `scripts/core/PetSettings.gd`：用户偏好持久化
- `scripts/platform/DesktopBounds.gd`：多屏工作区边界计算
- `scripts/entities/FrogVisual.gd`、`PetSwarm.gd`：角色表现与隔离的分身物理
- `scripts/entities/PetFleet.gd`：小奶蛙窗口生命周期、命令路由与现有设置持久化
- `scripts/entities/PetCollisionWorld.gd`：跨窗口统一碰撞、边界反弹和速度衰减
- `scripts/entities/FrogPetWindow.gd`、`scenes/FrogPetWindow.tscn`：小奶蛙独立透明窗口与局部菜单/输入
- `scripts/ui/PetTheme.gd`：菜单色彩、间距、阴影、悬浮样式与图标
- `scenes/FrogVisual.tscn`：角色图片节点，编辑器画布和运行时共用

主奶蛙数据流为“鼠标 → `PetGesture` 分类 → `PetBehavior` → 主窗口渲染”；小奶蛙数据流为“任一奶蛙菜单/鼠标 → `PetFleet` 生命周期与命令 → `PetCollisionWorld` 固定步长状态 → 多窗口位置与角色渲染”。设置继续统一写入 `PetSettings` 使用的 Godot `ConfigFile`，包含各奶蛙 ID、尺寸、位置与碰撞参数，不引入第二套设置存储。旧的限时 `PetSwarm` 分身玩法保持独立。

## 素材接入边界

站立立绘已接入；音效目前由运行时合成，未导入外部音频。未来素材放在 `assets/` 下并由对应资源模块接入；窗口逻辑与持久化逻辑保持独立。本地原始素材库 `奶蛙素材/` 被 Git 忽略，不会随代码提交。

素材归类约定见 [assets/README.md](assets/README.md)：角色、音效、字体和 UI 图标分开存放；每个外部素材需记录来源、授权和处理方式。

可复用的 Godot 桌宠起始工程、AI 起手提示词与编辑器嵌入设置说明见 [Godot4.4_桌宠标准模板库](templates/Godot4.4_桌宠标准模板库/README.md)。

## 运行

使用 Godot 4.7.2 打开项目根目录，运行主场景。短按主奶蛙触发戳击；长按并移动可抓取奶蛙并推动其他奶蛙。右键奶蛙可设置大小、生成后代、清理全部后代、调整碰撞强度或退出当前小奶蛙。

无界面运行自动化测试：

```powershell
godot --headless --path . --script res://tests/test_pet_system.gd
```
