---
name: weldone-current-urdf
description: 根据 Weldone roaming 配置自动定位当前项目对应的 URDF 文件并读取内容。适用于用户要求”先找当前项目对应的 urdf””根据 ProjectConfig 找 urdf””读取当前 DeviceEnv 里的 urdf””看当前项目加载的是哪个 urdf”等场景。
license: Apache-2.0
compatibility: Windows only. Requires Weldone installed at default roaming path.
metadata:
  author: weldone-team
  version: “1.0.0”
---

# Weldone Current Urdf

按下面顺序执行，优先直接读取，不要猜路径。

## Workflow

1. 读取 `C:/Users/mini-pc/AppData/Roaming/Roboticplus/Weldone/1.0.x/ProjectConfig.json`
2. 从中取出 `ProjectFolder`
3. 读取 `C:/Users/mini-pc/AppData/Roaming/Roboticplus/Weldone/1.0.x/<ProjectFolder>/RobotPlanSetting.json`
4. 从中取出 `UrdfFileName`
5. 读取 `C:/Users/mini-pc/AppData/Roaming/Roboticplus/Weldone/1.0.x/<ProjectFolder>/DeviceEnv/<UrdfFileName>.urdf`

## Output

向用户明确返回：

- `ProjectConfig.json` 路径
- `ProjectFolder` 值
- `RobotPlanSetting.json` 路径
- `UrdfFileName` 值
- 最终 `.urdf` 路径
- URDF 内容摘要

## Notes

- 当前环境是 Windows，路径使用上面的绝对路径。
- `RobotPlanSetting.json` 文件名按当前项目实际写法读取，不要自行改成别的大小写。
- 如果任一步文件不存在，直接说明缺少哪个路径，不要猜测替代文件。
- 读取 URDF 后，默认先给摘要；只有用户继续要求时，再展开完整关节树、base/tool0 关系或具体 XML 片段。
