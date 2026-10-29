# Crazy Naiwa

基于 Godot 4 的抽象奶蛙桌宠原型。

## 当前版本

`0.2.0`（抽象行为原型）

## 当前能力

- 透明、无边框、置顶窗口
- 程序绘制的奶蛙占位角色：呼吸、追视、悬浮反馈与弹性形变
- DVD 弹跳、任务栏蛄蛹、失重上浮后坠落、拖拽弹射
- 连续戳击充气并在第十次弹飞；闲置像素化，触碰恢复
- 舌头仅作本窗口内的视觉互动，不更改系统鼠标速度或拦截其他应用输入
- 最多 50 个本窗口内的物理分身，可用鼠标划动搅动；15 秒后自动清理，也可手动清理
- 右键菜单统一奶油色/绿/墨色主题；透明区域继续穿透
- `user://crazy_naiwa.cfg` 仅持久化置顶、整活开关和窗口位置

## 代码边界

- `scripts/app/Main.gd`：窗口、输入与菜单编排
- `scripts/core/PetBehavior.gd`：不依赖场景节点的行为状态机
- `scripts/core/PetSettings.gd`：用户偏好持久化
- `scripts/platform/DesktopBounds.gd`：多屏工作区边界计算
- `scripts/entities/FrogVisual.gd`、`PetSwarm.gd`：角色表现与隔离的分身物理
- `scripts/ui/PetTheme.gd`：菜单颜色与悬浮样式
- `shaders/idle_pixelate.gdshader`：闲置降维视觉效果

数据流为“鼠标/菜单输入 → `PetBehavior` 状态 → 窗口、角色和着色器”；分身通过独立的 `PetSwarm` 实体模块接收鼠标扰动。配置只有少量用户偏好，因此使用 Godot `ConfigFile`，不引入数据库。没有设置下拉框或弹窗，不添加无用控件状态。

## 素材接入边界

角色图片、音效和字体尚未纳入工程。正式素材放在 `assets/` 下并由角色资源模块接入；窗口逻辑与持久化逻辑保持独立。本地 `奶蛙素材/` 被 Git 忽略，不会随代码提交。

素材归类约定见 [assets/README.md](assets/README.md)：角色、音效、字体和 UI 图标分开存放；每个外部素材需记录来源、授权和处理方式。

## 运行

使用 Godot 4.7.2 打开项目根目录，运行主场景。右键奶蛙可选择单项整活、暂停行为、置顶、返回角落或退出。

无界面运行自动化测试：

```powershell
godot --headless --path . --script res://tests/test_pet_system.gd
```
