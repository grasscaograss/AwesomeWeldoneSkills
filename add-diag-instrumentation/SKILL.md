---
name: add-diag-instrumentation
description: 为 .NET 代码（weldone 项目优先）添加 EventSource 结构化诊断事件源 + dotnet-monitor 崩溃自动 dump 配置。是 add-diag-logs（改源码加 ILogger 文本日志）的升级版：埋点一次性完成、平时零开销、运行时按需动态开启、不用为加日志重新发版。触发场景：(1) 用户要求"加事件源""加 EventSource""埋诊断点""加 instrumentation""配置崩溃 dump""加动态诊断"；(2) 调查需要长期反复收集数据的偶发问题（加 ILogger 成本太高）；(3) 实施飞书文档「源码保护设计方案」第九章 .NET 动态诊断工具链；(4) 用户要求把某个方法/流程"可追踪""可观测"。仅添加诊断代码，不修改业务逻辑。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# 诊断埋点（EventSource + dotnet-monitor）

为 .NET 代码添加**运行时动态诊断能力**。与 `add-diag-logs`（注入 ILogger 文本日志，每次要改源码发版）互补：本 skill 埋的是 **EventSource 结构化事件**，编译期一次性完成，运行时默认零开销，出问题时用 `dotnet-trace`/`dotnet-monitor` 远程动态开启抓取，无需重新发版。

详细的事件设计原则、参数约束、weldone 已有 EventSource 清单，见 [`references/instrumentation-guide.md`](./references/instrumentation-guide.md)。**埋点前必读。**

## 核心判断：先决定用哪种诊断

收到埋点请求后，先判断问题形态，决定工具，不要无脑加 EventSource：

| 问题形态 | 工具 | 本 skill 是否适用 |
|---|---|---|
| 一次性 bug，加几条日志就能定位 | **add-diag-logs**（ILogger） | ❌ 用 add-diag-logs，本 skill 杀鸡用牛刀 |
| 偶发问题，需长期反复收集数据 | **EventSource**（本 skill） | ✅ 正是为此设计 |
| 需要全流程性能剖析（哪一步慢） | **dotnet-trace** + EventSource | ✅ 两者配合 |
| 需要看某个对象全部字段值（含未埋点的） | **dotnet-dump** | ⚠️ 不需要埋点，直接抓 dump |
| 崩溃后需自动留现场 | **dotnet-monitor Collection Rule** | ✅ 用本 skill 的 dump 配置流程 |

**决策原则**：能用 ILogger 解决的别上 EventSource；偶发/难复现/需长期观测的才上 EventSource；要看未埋点对象的字段值用 dump。

## 工作流程

### 步骤一：分析埋点目标

1. 读取用户指定的方法/流程源码，理解：输入参数、输出、内部关键分支、外部调用、循环
2. 识别"出问题时最想知道什么"——这是事件参数的设计依据（见下文"参数设计"）
3. 检查目标类是否已有 EventSource 引用（grep `EventSource` in 目标文件及同目录）

### 步骤二：选择或创建 EventSource

判断目标代码所属业务域，匹配现有 EventSource 或新建：

1. 读 [`references/instrumentation-guide.md`](./references/instrumentation-guide.md) 的「weldone EventSource 清单」章节，看目标域是否已有 EventSource
2. **已有** → 在其中追加 `[Event(id)]` 方法，id 接续现有最大值 +1
3. **没有** → 新建 EventSource 文件，命名用**业务域**（`Robim-WeldPlanning`），不用类名/方法名
   - 放在目标代码所在工程下的 `Diagnostics/` 或根目录
   - `[EventSource(Name = "Robim-{业务域}")]`

**命名约束（混淆兼容）**：EventSource 的 `Name` 是字符串常量，不受代码混淆影响。务必用业务语义命名（`Robim-WeldPlanning`、`Robim-RobotControl`、`Robim-VisionPositioning`），这样混淆后照样能 `dotnet-trace --providers Robim-WeldPlanning` 开启。

### 步骤三：设计事件参数（最关键）

EventSource 的价值在于**带变量值**，不是只发"进入/离开"信号。光有调用关系无法定位——必须带上问题定位所需的输入输出值。详细规则见 [`references/instrumentation-guide.md`](./references/instrumentation-guide.md) 的「参数设计」章节，核心要点：

1. **WriteEvent 参数类型硬限制**：只接受 `string/int/long/float/double/bool/byte` + 这些类型的一维数组。**不能传自定义类、struct（含 Matrix4x4）、接口、字典**。复杂对象必须拆解为基础类型。
2. **位姿/矩阵拆解**：weldone 大量用 `Matrix4x4`、`Pose`。埋点时拆成 `posX,posY,posZ` + 旋转矩阵 9 个分量（或四元数 4 个分量），别整体传。
3. **集合取摘要**：`List<T>` 传 `Count` + 前几个关键元素（如前 3 个焊缝的 seamIndex），别传整个集合。
4. **每类事件至少带**：业务 ID（workpieceId/seamIndex，用于关联同一流程）、success/durationMs（用于判断是否异常）。

### 步骤四：埋点（改业务代码）

在目标方法的关键位置插入 EventSource 调用。**不修改任何业务逻辑**，只添加事件触发语句。

埋点位置（按优先级）：

1. **方法入口** — `XxxStart(businessId, keyInputParams...)`
2. **方法返回前** — `XxxEnd(businessId, success, durationMs, keyOutputValues...)`
3. **慢操作阈值** — 超过阈值时发 `XxxSlow(businessId, durationMs, context)`（warning 级别）
4. **关键分支** — 走了哪个分支 + 判断条件值
5. **外部调用（P/Invoke、设备通信、DB）前后** — 入参 + 返回值 + 耗时

耗时测量用 `Stopwatch`，**必须用 `System.Diagnostics.Stopwatch`**，不要用 `DateTime.Now` 相减（精度差且有夏令时问题）。

```csharp
// 标准埋点模式
public bool TryCalculateWeldToolPoses(WsWeldPosParam param, PoseCalculationMode mode, ...)
{
    var sw = Stopwatch.StartNew();
    WeldPlanningEventSource.Log.PoseCalcStart(param.WorkpieceId, param.SeamIndex, param.TotalSeams, mode.ToString());

    // ... 原有业务逻辑完全不变 ...

    bool success = calSuc >= 0;
    WeldPlanningEventSource.Log.PoseCalcEnd(
        param.SeamIndex, success, sw.Elapsed.TotalMilliseconds, resultPoints.Count);
    if (sw.Elapsed.TotalMilliseconds > 3000)
        WeldPlanningEventSource.Log.PoseCalcSlow(param.SeamIndex, sw.Elapsed.TotalMilliseconds, resultPoints.Count);
    return success;
}
```

### 步骤五：dotnet-monitor 配置（仅崩溃 dump 任务）

若用户要求配置崩溃自动 dump / 性能自动 trace，走此步骤：

1. 确认目标机器已安装 dotnet-monitor（作为 Windows 服务，不随主程序启动）
2. 生成或更新 `settings.json` 的 `CollectionRules` 段
3. **必须配置 FSM 状态门控**：weldone 涉及机器人运动，抓 dump 会冻结进程（STW）几百 ms~数秒。**焊接进行中（FSM.State == Welding 相关态）禁止触发重型诊断**，否则可能撞机。门控逻辑见 [`references/instrumentation-guide.md`](./references/instrumentation-guide.md) 的「FSM 状态门控」章节
4. 鉴权：诊断 API 等于进程控制权，必须配 API Key，禁止裸暴露端口
5. 配置 dump 滚动保留（最近 3-5 个，旧的自动删，避免磁盘爆满）

## 执行约束

- **不修改任何业务逻辑**，只添加诊断代码（EventSource 调用、Stopwatch、EventSource 类定义）
- EventSource 类本身和 `[Event]` 方法是纯增量，不影响现有逻辑
- `WriteEvent` 在未被监听时开销纳秒级（直接 return），生产环境零负担——但**不要在每秒执行上万次的热循环里埋点**，累积开销不可忽略
- 复杂对象拆解为基础类型时，避免在拆解过程中做昂贵的序列化/计算——EventSource 参数应该是廉价取值（属性访问、字段读取）
- Stopwatch 创建在方法栈上，无分配压力，可放心使用

## 输出格式

完成后输出埋点报告：

```
已添加诊断埋点：
- EventSource: Robim-WeldPlanning（src/Robim.Algorithm.Weld/Diagnostics/WeldPlanningEventSource.cs）
  - 新增事件：PoseCalcStart(8)/PoseCalcEnd(9)/PoseCalcSlow(10)
- 埋点位置：
  - src/Robim.Algorithm.Weld/Solver/WeldPoseSolver.cs::TryCalculateWeldToolPoses — 入口+出口+慢阈值 (3s)
  - src/Weldone.Domain/PostProcessing/CoarsePostProcessGenerator.cs::Generate — 入口+出口

验证方式：
1. 编译：dotnet build src/Robim.Algorithm.Weld/...
2. 运行程序后另开终端：dotnet-trace collect -p <PID> --providers Robim-WeldPlanning --duration 00:00:30
3. 复现问题，查看 .speedscope.json 或 nettrace 中的事件流
```

## 与 add-diag-logs 的关系

| 维度 | add-diag-logs (ILogger) | 本 skill (EventSource) |
|---|---|---|
| 触发方式 | 一直在记 | 默认关，运行时动态开 |
| 开销 | 有 IO 开销 | 未启用≈0 |
| 内容 | 文本日志 | 结构化事件，带类型化参数 |
| 修改成本 | 每次改源码+发版 | 一次性编译期，之后不再改 |
| 适用 | 日常审计、粗粒度流程、一次性定位 | 偶发问题、深度诊断、性能剖析 |

**两者并存**：ILogger 做日常厚日志，EventSource 做深度诊断探针。一个流程可以同时有两者的埋点。

## 配套读取器：read-diag-captures

本 skill 负责**埋点和采集**（写 EventSource、跑 dotnet-trace/dump 抓数据），产物落点约定在 `<项目目录>/Diagnostics/`。**解读这些产物**用配套 skill `read-diag-captures`：它定位 Diagnostics 目录、把事件 ID 翻译成事件名+参数含义（见 [`references/instrumentation-guide.md`](./references/instrumentation-guide.md) 与 `read-diag-captures/references/eventsource-catalog.md`，两份保持同步）、按文件类型（`.nettrace`/`.dmp`/`.csv`/`.speedscope.json`）给出解读方法。

| 阶段 | 文本日志线 | 结构化诊断线 |
|---|---|---|
| 埋点/注入 | add-diag-logs | **本 skill（add-diag-instrumentation）** |
| 读取/解读 | weldone-project-logs | **read-diag-captures** |

一个偶发问题的完整排查路径：先用本 skill 埋 EventSource → 复现时 dotnet-trace 抓取 → 用 read-diag-captures 解读事件流定位。
