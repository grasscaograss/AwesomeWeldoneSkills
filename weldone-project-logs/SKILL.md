---
name: weldone-project-logs
description: 读取 Weldone 焊接软件的项目日志与配置文件以辅助排障。当用户提到"看下 Weldone 日志"、"项目报错了"、"最近的运行日志"、"检查 DeviceSetting/RobotSetting 配置"、"KukaTest/JuLi 等项目出问题了"、"读取运行日志定位异常"等涉及 Weldone 运行时日志或设备/规划配置的场景时，应使用本 skill。它会动态定位配置根目录（基于 %APPDATA%，绝不写死用户名），解析当前激活项目，读取 Serilog 日志和各类 JSON 配置。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Weldone 项目日志与配置读取

## Overview

定位并读取 Weldone 焊接软件在本机的运行日志（Serilog 文本格式）和项目配置 JSON（DeviceSetting、RobotPlanSetting、WorkspaceSetting 等），用于排障、检查运行状态、核对设备/规划参数。所有路径基于 `%APPDATA%` 环境变量动态解析，不依赖任何写死的用户名。

## 路径解析规则（核心）

Weldone 的配置与日志位置由三层目录构成：

```
%APPDATA%\Roboticplus\Weldone\1.0.x\          ← 配置根目录（固定）
├── ProjectConfig.json                         ← 读 ProjectFolder 字段
├── DeviceSetting.json                         ← 全局设备清单
└── <ProjectFolder>\                           ← 当前项目子目录（如 KukaTest、JuLi）
    ├── *.json                                 ← 项目级配置（见 references）
    ├── Logs\logs-YYYYMMDD[_HHMMSS].log        ← 运行日志（本 skill 的主要目标）
    ├── Debug\                                 ← 规划中间结果 JSON
    └── ProductionData\                        ← 生产数据快照
```

**关键原则**：
- 配置根目录永远是 `%APPDATA%\Roboticplus\Weldone\1.0.x`，其中 `%APPDATA%` 在 Windows 等于 `C:\Users\<当前用户>\AppData\Roaming`。**禁止**在任何输出或脚本里写死 `mini-pc` 之类的用户名。
- 哪个项目是"当前项目"由 `ProjectConfig.json` 的 `ProjectFolder` 字段决定，不要假设；总是先读它。

## 执行流程

### 1. 定位路径与日志清单

优先运行脚本（确定性、token 高效）：

```bash
python "<skill>/scripts/resolve_project.py" --list
```

输出：配置根目录、当前项目名、项目目录、日志目录，以及日志文件按修改时间倒序的清单（含文件大小、修改时间，并对 0KB 文件标注提示）。

需要看其它项目时加 `--project <名字>`：
```bash
python "<skill>/scripts/resolve_project.py" --list --project JuLi
```

若手头没有可用的 Python，按上述路径规则用 `Bash` + `$APPDATA`/`Read` 工具自行定位（Git Bash 下用 `"$APPDATA/Roboticplus/Weldone/1.0.x"`）。

### 2. 读取日志

日志在 `<项目目录>/Logs/` 下。读取策略：

- **定位最近一次运行**：清单里修改时间最新、且带 `_HHMMSS` 后缀的文件通常就是最近一次启动。无后缀的（如 `logs-20260417.log`）是按日滚动的旧格式。
- **目标式检索优先**：大文件（数百 KB ~ 数 MB）不要整读。用 `Grep` 工具按级别或关键词过滤：
  - 按级别：`Grep` pattern `\[(ERR|FTL|WRN)\]` —— 排障时先抓异常和警告。
  - 按异常关键词：报错堆栈里的类名/方法名/异常类型。
  - 按时间窗口：先 `Grep` 出该次启动的时间范围，再读对应行。
- **中小文件**可直接用 `Read` 工具读取（默认 2000 行）。
- 日志行格式：`2026-06-29 11:31:48.333 +08:00 [INF] 消息`，级别缩写见 references。

### 3. 读取配置 JSON

项目目录与配置根目录下的 `*.json` 都可读。常见用途：
- 核对设备连接（`DeviceSetting.json`：`DeviceInfos[].ConnectInfo.IP/Port`）
- 核对机器人 TCP / 用户坐标系（`RobotPlanSetting.json`：`TcpSettings`、`UserFrame`）
- 核对工位布局（`WorkspaceSetting.json`）
- 核对当前激活项目（`ProjectConfig.json`）

字段含义速查见 `references/config-files.md`。

读取方式：直接用 `Read` 工具读绝对路径。路径用脚本输出的项目目录拼文件名，或用 `$APPDATA` 表达式。

## 重要行为约定

- **0KB 文件必须实读确认**：磁盘上 `size==0` 不代表真空——文件系统可能未刷新文件大小元数据，实际打开仍有内容。**永远不要**因 size==0 就跳过日志；必须真正 `Read`/打开才能判定。真 0 字节本身也是有价值的信号（通常意味着启动即崩溃）。
- **只读不改**：日志与配置文件是运行时产物。除非用户明确要求修改，只读不写。改动生产配置前必须向用户确认。
- **用户名动态化**：任何输出给用户的路径、生成的脚本、示例命令，都必须用 `%APPDATA%` 或 `$APPDATA` 表达，不得出现 `C:\Users\具体用户名`。
- **跨平台兜底**：脚本在 `APPDATA` 缺失时回退到 `USERPROFILE\AppData\Roaming`，再退到 `HOME`（用于 Git Bash 环境）。

## Resources

### scripts/
- `resolve_project.py` —— 从 `%APPDATA%` 动态解析配置根目录，读 `ProjectConfig.json` 取当前项目，列出日志（含 0KB 标注）。支持 `--list` 与 `--project <名>`。**所有路径解析的首选入口**。

### references/
- `config-files.md` —— 全部配置 JSON 的文件清单、关键字段含义、日志格式与级别缩写、0KB 处理规则、Debug 目录说明。读取配置或解读日志字段时加载此文档。
