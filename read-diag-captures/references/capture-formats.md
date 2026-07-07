# 诊断采集产物的格式与解读

dotnet 诊断工具链产出的四类文件，分别怎么读。文件落点约定见 SKILL.md「捕获目录约定」。

## ⚠️ 安全提示（先看）

| 文件类型 | 敏感度 | 说明 |
|---|---|---|
| `.dmp` | **高** | 进程内存快照，含工件坐标、设备 IP/端口、可能的连接串、配置全文。**外发（贴出、上传第三方、提交到仓库）前必须向用户确认。** |
| `.nettrace` | 中 | 事件参数值，可能含 workpieceId、位姿数值、IP；不含全部堆对象。 |
| `.speedscope.json` | 中 | 同 `.nettrace`（是其转换产物），且为明文 JSON，更易泄露。 |
| `.csv` | 低 | 仅聚合指标（计数、均值、时长），通常无业务数据。 |

`.gitignore` 应排除整个 `Diagnostics/` 目录——这些产物只在本机排障用，不进版本库。

---

## 1. `.nettrace` — dotnet-trace 事件流

二进制格式，**不能直接 Read/Grep**。两种读法：

### 方式 A：转 speedscope（推荐，本 skill 主路径）

```bash
dotnet-trace convert --format speedscope <文件>.nettrace
# 产出 <文件>.speedscope.json，见下节解读
```

转换后可直接用 Read/Grep 处理 JSON，适合没有 PerfView 的环境（Linux/WSL/macOS）。

### 方式 B：PerfView（Windows，功能最全）

用 PerfView 打开 `.nettrace`，看事件时间线、按 provider 过滤、统计事件频率。适合深度分析。

### 方式 C：转 traceevent CSV（脚本批处理）

```bash
dotnet-trace convert --format speedscope <文件>.nettrace   # 或用 TraceEvent 库二次开发
```

---

## 2. `.speedscope.json` — 可视化事件流（明文）

`.nettrace` 转换后的产物，**可直接 Read/Grep**。结构（speedscope v0.0.x schema）：

```jsonc
{
  "$schema": "https://www.speedscope.app/file-format-schema.json",
  "shared": {
    "frames": [
      { "name": "Robim-WeldPlanning/PoseCalcStart" },   // name = "<EventSource名>/<事件方法名>"
      ...
    ]
  },
  "profiles": [
    {
      "type": "evented",
      "name": "...",
      "unit": "microseconds",
      "startValue": 123456,
      "endValue": 789012,
      "events": [
        { "type": "O", "at": 123500, "frame": 0, "arg": { ... } },   // O = 事件开始
        { "type": "C", "at": 124000, "frame": 0 }                    // C = 事件结束
      ]
    }
  ],
  "activeProfileIndex": 0,
  "exporter": "dotnet-trace"
}
```

### 解读要点

- **`frame.name`** 格式是 `"<EventSource名>/<事件方法名>"`（如 `Robim-WeldPlanning/GenPathsEnd`）。事件流里每个事件引用 `frame` 索引。
- **`events[].arg`** 是该次触发的参数值（key 为参数名）。读 `arg` 即可看到当时 workpieceId、durationMs 等的实际值。
- **Grep 技巧**：`Grep "Robim-WeldPlanning"` 抓所有规划事件；`Grep "\"frame\":0"` 抓 frame[0] 的全部触发。
- 事件方法名 → 参数含义查 [`eventsource-catalog.md`](./eventsource-catalog.md)。

### 大文件处理

`.speedscope.json` 可能数 MB~数十 MB（长采集）。**不要整读**：
- 先 `Grep "frame"` 看有哪些 frame（事件类型）
- 锁定关心的 frame index 后 `Grep "\"frame\":<n>"` 拿该事件的全部触发点
- 或用脚本 `jq` 抽取特定事件

也可以直接上传到 https://www.speedscope.app 浏览器可视化（但注意前面「安全提示」——上传 = 外发）。

---

## 3. `.dmp` — dotnet-dump 进程内存快照

二进制，用 `dotnet-dump analyze` 交互式排查：

```bash
dotnet-dump analyze <文件>.dmp
```

进入交互后常用 SOS 命令（按排障场景分组）：

### 线程与调用栈（最常用）

| 命令 | 作用 |
|---|---|
| `clrthreads` | 列出所有托管线程（找卡住的线程先看这里） |
| `clrstack` | 当前线程的托管调用栈（需先 `~<tid>s` 切到目标线程） |
| `~<tid>s` | 切换到线程 `<tid>`（clrstack 看的就是当前线程） |
| `clrstack -a` | 调用栈 + 局部变量 + 参数 |
| `syncblk` | 查看锁持有情况（死锁排查） |

### 异常

| 命令 | 作用 |
|---|---|
| `pe` | 打印当前/最近的托管异常（PrintException） |
| `pe <异常地址>` | 打印指定异常对象 |

### 堆与对象

| 命令 | 作用 |
|---|---|
| `dumpheap -stat` | 按类型统计堆对象数量/大小（找内存泄漏、看某类型实例数） |
| `dumpheap -mt <MethodTable地址>` | 列出某类型的所有实例 |
| `dumpobj <对象地址>` (`do`) | 打印对象的字段值 |
| `gcroot <对象地址>` | 查对象被谁引用（为什么没被 GC） |

### GC 与诊断

| 命令 | 作用 |
|---|---|
| `eeheap -gc` | GC 堆各代大小 |
| `dbgnearobj <地址>` | 找最近的有效对象（地址勘误） |

> **没有 dotnet-dump 时**：`.dmp` 是标准 Windows minidump/full dump，Visual Studio、WinDbg、lldb（带 SOS）都能开。WSL 内无法直接读 `.dmp`，需在 Windows 侧分析。

---

## 4. `.csv` — dotnet-counters 指标表

`dotnet-counters collect --counters <provider> --format csv` 产出，**可直接 Read/Grep**。

典型列（dotnet-counters CSV 表头）：

| 列 | 含义 |
|---|---|
| `Provider` | EventSource 名（如 `Robim-WeldPlanning`） |
| `Counter Name` | 指标名（如 `PoseCalc Duration`） |
| `DisplayName` | 展示名 |
| `Mean` | 区间均值 |
| `Incremental` | 自上次以来的增量 |
| `Interval` | 采样间隔 |
| `Counter Type` | `Metric`（连续值，如时长/计数）或 `Rate`（每秒速率） |

weldone 的 EventSource 目前以**离散事件**为主（`[Event]` 方法），不一定暴露 EventCounter。`.csv` 主要捕获 runtime 内置计数器（`System.Runtime` 的 GC/ThreadPool/CPU）。若需看自定义计数器，确认 EventSource 类里定义了 `[EventCounter]` / `[IncrementingEventCounter]`。

---

## 工具链速查

| 产物 | 产生命令 | 读法 |
|---|---|---|
| `.nettrace` | `dotnet-trace collect -p <PID> --providers <Name> --duration <H:MM:SS>` | 转 speedscope 或 PerfView |
| `.speedscope.json` | `dotnet-trace convert --format speedscope <file>.nettrace` | 直接 Read/Grep（本 skill 主路径） |
| `.dmp` | `dotnet-dump collect -p <PID>` 或 dotnet-monitor 崩溃规则触发 | `dotnet-dump analyze <file>` |
| `.csv` | `dotnet-counters collect -p <PID> --counters <Name> --format csv` | 直接 Read/Grep |
