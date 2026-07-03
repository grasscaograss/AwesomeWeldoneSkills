# Weldone 配置文件参考

项目目录（`配置根目录/ProjectFolder`）下的可读 JSON 配置文件及其字段含义。
**重要**：以下字段含义为调试/排障时定位问题用，不要凭此改动生产配置；用户未明示要求时只读不改。

## 配置根目录级（配置根目录/）

| 文件 | 作用 |
|------|------|
| `ProjectConfig.json` | 指向当前激活的项目子目录（`ProjectFolder` 字段）、项目类型、支持的工件类型。**入口文件**。 |
| `DeviceSetting.json` | 全局设备清单：机器人/相机（粗定位、结构光、线激光）/焊枪的 IP、端口、TCP、标定参数。 |

## 项目子目录级（配置根目录/ProjectFolder/）

| 文件 | 作用 | 关键字段 |
|------|------|----------|
| `DeviceSetting.json` | 项目级设备覆盖配置 | `DeviceInfos[].Keyed`（RobotFanuc/CoarseVisionGeneral/AccurateMechMind/AccurateLaser）、`ConnectInfo.IP/Port`、`DeviceDetail.Tcp`、`ExtraInfo` |
| `RobotSetting.json` | 机器人通信与外轴标定 | `ConnectionPeriod`、`ExternalAxisAxisToRobotVecAngle` |
| `RobotPlanSetting.json` | 机器人规划参数 | `UrdfFileName`、`ArmSettings[].HomeJoint.Position`、`TcpSettings[]`（Weld/Transition/Vision 三种 TCP）、`UserFrame`（用户坐标系 4×4 矩阵） |
| `WorkspaceSetting.json` | 工位布局 | `WorkspaceList[]`（Id/Name/Points/InitialPosition/RobotHomePose）、`WorkpieceGap`、`WorkTableBaseHeight` |
| `PlanParamSetting.json` | 焊接规划工艺参数 | 焊枪姿态、摆动、速度等工艺细节 |
| `GeometryAlgorithmSetting.json` | 几何算法参数 | — |
| `RobotJointsMapping.json` | 关节映射 | — |
| `AccurateVisionSetting.json` / `CoarseVisionSetting.json` | 视觉算法配置 | — |
| `DigitalTwinSetting.json` | 数字孪生开关 | — |

## 日志格式（Logs/logs-YYYYMMDD[_HHMMSS].log）

Serilog 文本格式，每行：
```
2026-06-29 11:31:48.333 +08:00 [INF] 消息内容
└──── 时间戳 +08:00 ────┘ └级别┘ └── 内容 ──┘
```

级别标识（Serilog 缩写）：`[VRB]` Verbose、`[DBG]` Debug、`[INF]` Information、`[WRN]` Warning、`[ERR]` Error、`[FTL]` Fatal。排障优先看 `[ERR]`/`[FTL]`/`[WRN]`。

每行启动序列以 `欢迎使用 Weldone...` 开头（`[INF]`）。一次应用启动产生一个日志文件（含 `_HHMMSS` 后缀），同名无后缀的（如 `logs-20260417.log`）为按日滚动的旧格式。

## 0KB 日志文件处理

日志文件磁盘显示 0 字节不代表真空——文件系统未刷新文件大小元数据时 `stat().st_size` 可能报 0，实际打开读取仍有内容。处理规则：
- **永远不要**因为 size==0 就跳过日志。
- 必须实际打开文件读取（`Read` 工具或脚本读取）才能判定是否真空。
- 真正 0 字节通常意味着进程启动即崩溃/未写入任何内容，本身也是有价值的诊断信号。

## Debug 子目录（项目目录/Debug/）

存放规划中间结果 JSON（粗定位结果、扫描流程、规划前后、过渡段、工件等），是 `weld-plan-debug` skill 的主要数据源，本 skill 主要负责定位与列出，详细解读交由专用 skill。
