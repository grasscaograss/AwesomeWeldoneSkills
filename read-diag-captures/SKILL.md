---
name: read-diag-captures
description: 读取并解读 Weldone 的 .NET 动态诊断采集产物（dotnet-trace / dotnet-dump / dotnet-counters 抓取的 .nettrace / .dmp / .csv / .speedscope.json）。是 add-diag-instrumentation（埋 EventSource 事件源、采集诊断数据）的配套读取器：那个 skill 负责"埋点和采集"，本 skill 负责"定位文件并解读内容"。触发场景：(1) 用户要求"看 dotnet-trace""解读 .nettrace""speedscope 怎么看""dump 怎么分析""counters csv 解读"；(2) 用户贴出 EventID（如"Robim-WeldPlanning 的 EventID=8 是什么"）需翻译成事件名和参数含义；(3) 排查偶发问题/性能瓶颈/FSM 卡死，已有 EventSource 采集产物需解读。仅读取和解读，不改业务代码、不改诊断配置。不含 Serilog 文本日志（那是 weldone-project-logs 的职责）。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# 读取诊断采集产物

读取并解读 .NET 动态诊断工具链（`dotnet-trace`/`dotnet-dump`/`dotnet-counters`）抓取的采集产物。与 `add-diag-instrumentation` 配对：那个 skill 埋 EventSource 事件、跑采集命令产出文件，本 skill 定位这些文件、把事件 ID 翻译成业务含义、按文件类型给出解读方法。

与 `weldone-project-logs` 的分工：那个读 Serilog **文本日志**（一直在记、`[INF]/[ERR]` 那种），本 skill 读 **EventSource 结构化事件产物**（默认不记、运行时动态开抓、带类型化参数）。

## 捕获目录约定（核心）

诊断采集产物落在当前项目目录下与 `Logs/` 并列的 `Diagnostics/` 子目录：

```
%APPDATA%\Roboticplus\Weldone\1.0.x\          ← 配置根目录（%APPDATA% = C:\Users\<当前用户>\AppData\Roaming）
├── ProjectConfig.json                         ← 读 ProjectFolder 字段定当前项目
└── <ProjectFolder>\                           ← 当前项目子目录（如 KukaTest、JuLi）
    ├── Logs\logs-YYYYMMDD[_HHMMSS].log        ← Serilog 文本日志（weldone-project-logs）
    ├── Debug\                                 ← 规划中间结果 JSON（weld-plan-debug）
    ├── ProductionData\                         ← 生产数据快照
    └── Diagnostics\                           ← 本 skill 的目标（新增约定）
        ├── *.nettrace                         ← dotnet-trace 事件流（二进制）
        ├── *.speedscope.json                  ← nettrace 转换产物（明文，可直接读）
        ├── *.dmp                              ← dotnet-dump 进程内存快照（含敏感数据）
        └── *.csv                              ← dotnet-counters 指标表
```

**关键原则**：
- 配置根目录永远是 `%APPDATA%\Roboticplus\Weldone\1.0.x`。**禁止**在任何输出或脚本里写死 `mini-pc` 之类的用户名。
- 哪个项目是"当前项目"由 `ProjectConfig.json` 的 `ProjectFolder` 字段决定，不要假设；总是先读它。
- **`Diagnostics/` 目录约定由本 skill 确立，尚未在代码中强制创建**。从未用过 `dotnet-trace`/`dotnet-dump` 时此目录不存在是正常的。建议采集时用 `--output` 指向此目录，让产物统一落点：

  ```bash
  # 示例（实际采集走 add-diag-instrumentation 的流程，本 skill 只负责读结果）
  dotnet-trace collect -p <PID> --providers Robim-WeldPlanning --duration 00:00:30 \
    --output "%APPDATA%\Roboticplus\Weldone\1.0.x\<ProjectFolder>\Diagnostics\trace.nettrace"
  ```

## 执行流程

### 1. 定位目录与采集文件清单

优先跑脚本（确定性、token 高效，与 `weldone-project-logs` 同一套路径规则）：

```bash
python "<skill>/scripts/resolve_diag.py" --list
```

输出：配置根目录、当前项目名、项目目录、诊断目录，以及 `Diagnostics/` 下采集文件按修改时间倒序的清单（含文件大小、修改时间、**按扩展名分类的类型标签**，并对 0KB 文件标注提示）。

需要看其它项目时加 `--project <名字>`：
```bash
python "<skill>/scripts/resolve_diag.py" --list --project JuLi
```

若手头没有可用的 Python，按上述路径规则用 `Bash` + `$APPDATA`/`Read` 工具自行定位（Git Bash 下用 `"$APPDATA/Roboticplus/Weldone/1.0.x"`）。

Diagnostics 目录不存在时脚本会给出可操作提示（不是报错），并建议用 `--output` 让后续采集落到此处。

### 2. 把 EventID 翻译成事件名 + 参数含义

读到事件流（speedscope/PerfView）或事件引用后，事件以 **EventSource名 + 方法名** 标识，参数是位置式（speedscope 的 `arg` 带 key）。查 [`references/eventsource-catalog.md`](./references/eventsource-catalog.md) 把：
- `frame.name = "Robim-WeldPlanning/GenPathsEnd"` → id 8，参数顺序 `workpieceId, wsgCount, seamCount, wrapPairCount, durationMs`
- `Robim-Workflow` 的 `NodeEnter` 没有配对的 `NodeLeave` → FSM 卡在 `nodeName`

四个 EventSource：`Robim-WeldPlanning`（焊缝规划）、`Robim-VisionScan`（扫描姿态）、`Robim-Workflow`（FSM 状态机）、`Robim-RobotControl`（机器人寄存器握手）。完整事件表 + 参数语义 + 典型诊断场景在 catalog 文件里。

### 3. 按文件类型解读

查 [`references/capture-formats.md`](./references/capture-formats.md) 取对应格式的解读方法：
- `.nettrace` → 转 speedscope（`dotnet-trace convert --format speedscope`）后读 JSON，二进制不可直读
- `.speedscope.json` → 直接 Read/Grep，结构 + Grep 技巧在 references 里
- `.dmp` → `dotnet-dump analyze` + SOS 命令速查（`clrstack`/`pe`/`dumpheap -stat`/`gcroot`）
- `.csv` → 直接 Read/Grep，列含义速查

**大文件原则**：采集产物常达数 MB~数十 MB。**不要整读**——先 `Grep` 框定关心的 provider/frame/事件，再针对性读片段。speedscope 可读 `frame` 索引表再按 frame 抓触发点。

## 重要行为约定

- **只读不改**：采集产物是排障现场快照。除非用户明确要求，只读不写、不删、不重命名。改 dotnet-monitor 配置等采集侧设置是 `add-diag-instrumentation` 的职责。
- **用户名动态化**：任何输出给用户的路径、生成的脚本、示例命令，都必须用 `%APPDATA%` 或 `$APPDATA` 表达，不得出现 `C:\Users\具体用户名`。
- **0KB 文件必须实读确认**：磁盘上 `size==0` 不代表真空——文件系统可能未刷新大小元数据。**永远不要**因 size==0 就跳过；必须真正 `Read`/打开才能判定。真 0 字节本身也是有价值的信号。
- **dump 含敏感内存数据**：`.dmp` 是进程内存快照，含工件坐标、设备 IP/端口、可能的连接串、配置全文。**外发（贴到对话、上传第三方、提交版本库）前必须向用户确认。** `Diagnostics/` 应被 `.gitignore` 排除。

## 与其他 skill 的关系

| 维度 | add-diag-logs | weldone-project-logs | add-diag-instrumentation | 本 skill (read-diag-captures) |
|---|---|---|---|---|
| 对象 | ILogger 文本日志代码 | Serilog 运行时文本日志 | EventSource 事件源代码 + 采集配置 | 诊断采集产物（nettrace/dump/csv） |
| 动作 | 注入（改源码） | 读取 | 埋点 + 采集（改源码/配置） | **读取 + 解读** |
| 触发态 | 默认一直在记 | 默认一直在记 | 默认关，运行时动态开 | 产物已存在，需解读 |
| 内容 | 代码里的日志语句 | `[INF]/[ERR]` 文本行 | 结构化事件 + 类型化参数 | 事件流/内存快照/指标表 |
| 典型场景 | 一次性 bug 加日志 | 看运行报错、查设备配置 | 偶发问题埋深度探针 | **解读采集到的事件流、定位卡死/慢** |

四个 skill 覆盖"埋点 → 采集 → 读取"全链路：add-diag-logs/weldone-project-logs 是文本日志侧（注入+读取），add-diag-instrumentation/本 skill 是结构化诊断侧（埋点采集+读取）。

## Resources

### scripts/
- `resolve_diag.py` —— 从 `%APPDATA%` 动态解析配置根目录，读 `ProjectConfig.json` 取当前项目，列出 `<项目目录>/Diagnostics/` 下采集文件（按修改时间倒序、按扩展名分类、含 0KB 标注）。支持 `--list` 与 `--project <名>`。**定位采集产物的首选入口**。路径规则与 `weldone-project-logs/scripts/resolve_project.py` 一致。

### references/
- `eventsource-catalog.md` —— 四个 EventSource（`Robim-WeldPlanning`/`Robim-VisionScan`/`Robim-Workflow`/`Robim-RobotControl`）的全部事件表：id、方法名、Level、参数顺序与语义、埋点位置、典型诊断场景。**解读事件流时加载此文档**。本表基于实际 `*EventSource.cs` 源码核对，是事件目录的权威版本。
- `capture-formats.md` —— 四类采集文件（`.nettrace`/`.speedscope.json`/`.dmp`/`.csv`）的格式说明、读取方法、SOS 命令速查、大文件处理技巧、安全提示。**解读具体文件时加载此文档**。
