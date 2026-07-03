# 诊断埋点详细指南

本文件是 SKILL.md 的参考资料，包含事件设计原则、参数约束、weldone 已有 EventSource 清单和真实代码示例。埋点前必读。

## 一、weldone EventSource 清单

维护本表，新增 EventSource 或事件时更新。截止 2026-07-03：

> 事件目录的**权威版本**见 `read-diag-captures/references/eventsource-catalog.md`（基于实际 `*EventSource.cs` 源码核对，含参数顺序与语义）。本文件从埋点视角描述，两份 guide 保持同步。

| EventSource 名 | 文件位置 | 业务域 | 状态 |
|---|---|---|---|
| `Robim-WeldPlanning` | src/Weldone.Domain/Welding/ToolPlanning/WeldPlanningEventSource.cs | 焊缝规划/姿态计算/生成焊缝/工艺列表/规划编排 | ✅ 已落地，已用 event id: 1-11 |
| `Robim-VisionScan` | src/Weldone.Application/Scanning/VisionScanEventSource.cs | 扫描姿态规划/视觉单元 | ✅ 已落地，已用 event id: 1-6 |
| `Robim-Workflow` | src/Weldone.Application/StateEngines/WorkflowEventSource.cs | FSM 状态机流转/节点进入离开/执行器生命周期 | ✅ 已落地，已用 event id: 1-5 |

### `Robim-WeldPlanning` 已定义事件

| id | 方法 | 埋点位置 | 说明 |
|---|---|---|---|
| 1 | `PlanGroupStart` | WeldPoseSolverManager.CalculateWeldToolPoses 入口 | wsgName/cilIdx/wsgIndex/mode/isMerged |
| 2 | `PlanGroupEnd` | CalculateWeldToolPoses 两个 return 前（正常+早期） | wsgName/cilIdx/success/durationMs/basePoseCount/multiPassCount |
| 3 | `PlanGroupSlow`（Warning） | CalculateWeldToolPoses 正常 return 前（>3s） | wsgName/cilIdx/durationMs/basePoseCount |
| 4 | `NativeCalcResult` | TryCalculateWeldToolPoses 调用后 | wsgName/cilIdx/nativeSuccess/resultPointCount/durationMs |
| 5 | `NativeCalcFallback`（Warning） | 三处降级点（merged/empty/exception） | wsgName/cilIdx/reason |
| 6 | `GenPathsStart` | FlexBeamWorkpieceManager.GenerateWeldPathsAsync 入口 | workpieceId/workpieceType/isSymmetricSplited/isLengthBreak |
| 7 | `GenPathsEarlyReturn` | GenerateWeldPathsAsync 两处提前返回（native几何/CIL 生成失败） | workpieceId/reason |
| 8 | `GenPathsEnd` | GenerateWeldPathsAsync 出口 | workpieceId/wsgCount/seamCount/wrapPairCount/durationMs |
| 9 | `CraftListBuilt` | GenerateCraftList+ChangeCraftListWithSelected+合并后（GenerateWeldPathsAsync 末段） | workpieceId/craftCount/mergedCount/isWrapOn/durationMs |
| 10 | `PlanOrchestratorStart` | WeldPlanAppService.WeldToolPosePlanAsync 入口 | workpieceId/totalWsgCount/wrapPairCount/reCalculate |
| 11 | `PlanOrchestratorEnd` | WeldPlanAppService.WeldToolPosePlanAsync 出口 | workpieceId/resultCount/cacheHitCount/failedCount/templateMatchMs/totalDurationMs |

**后续 `Robim-WeldPlanning` 追加事件从 id=12 起编号。**

### `Robim-VisionScan` 已定义事件

| id | 方法 | 埋点位置 | 说明 |
|---|---|---|---|
| 1 | `ScanPlanStart` | VisionCaptureAppService.VisionToolPosesPlanParallel 入口 | workpieceId/totalWsgCount/hybridCount/nativeCount |
| 2 | `NativeVcdResult` | CreateVisionCaptureData 调用后 | workpieceId/unitCount/durationMs |
| 3 | `VisionUnitProcessed` | ProcessVisionUnitWeldSeamGroup 后（成功+异常两路） | workpieceId/unitId/success/capPoseCount/validation |
| 4 | `NativeVcdFallback` | native VCD 解析异常 catch | workpieceId/reason/hasHybridEndpoint |
| 5 | `HybridUnitBuilt` | CreateHybridVisionUnitAsync 后 | workpieceId/wsgId/capPoseCount/validation |
| 6 | `ScanPlanEnd` | VisionToolPosesPlanParallel 出口 | workpieceId/totalDtos/durationMs |

**后续 `Robim-VisionScan` 追加事件从 id=7 起编号。**

### `Robim-Workflow` 已定义事件

覆盖全部 55 个 `[FSMNode]` 节点——**通过 FSMExecutor 的 StateTrackInfo 单一汇聚点捕获，无需逐节点埋点**。埋点位置：`FSMAppService.SetFSM` 的 Rx pipeline + 各 `StartXxxAsync` 方法 + `Executor_FSMStateChanged` 回调。

| id | 方法 | 埋点位置 | 说明 |
|---|---|---|---|
| 1 | `RunStart` | FSMAppService 的 5 个 StartXxxAsync 方法（RestartAsync 前） | fsmType/executorRole/workpieceIds（逗号分隔） |
| 2 | `NodeEnter` | SetFSM 的 Rx Select，StateTrackInfo.IsEnter=true 分支 | fsmType/nodeName/prevNode（首次为空） |
| 3 | `NodeLeave` | SetFSM 的 Rx Select，StateTrackInfo.IsEnter=false 分支 | fsmType/nodeName/durationMs（节点停留时长） |
| 4 | `NodeStuck` | SetFSM 的 Rx Select，NodeLeave 后 durationMs>30000 时 | fsmType/nodeName/durationMs（Warning 级别） |
| 5 | `StateChanged` | FSMAppService.Executor_FSMStateChanged 回调 | fsmType/state/prevState（Running/Paused/Stopped/Finished） |

**后续 `Robim-Workflow` 追加事件从 id=6 起编号。**

**FSM 节点停留时长机制**：`FSMAppService` 维护 `_nodeEnterWatches` 字典（节点名→Stopwatch）。NodeEnter 时启动计时，NodeLeave 时停止并算出 durationMs。切换执行器（SetFSM）时清空。这能直接诊断"卡在哪个节点多久"——例如 `FineLocExceptionHandler` 等待用户决议、`WeldExecute` 设备通信超时。

**典型诊断场景**：
- FSM 卡死：NodeEnter 没有配对的 NodeLeave → 卡在哪个节点一目了然
- 节点慢：NodeLeave 的 durationMs 超长（设备通信/人工等待）
- 异常转移：NodeEnter 的 prevNode=ExceptionNode → 哪个节点抛了异常
- 循环死锁：同一 nodeName 反复 Enter/Leave 且不推进 → 业务逻辑死循环

**规划中应覆盖的 EventSource（按业务域）：**

| 名 | 业务域 | 状态 |
|---|---|---|
| `Robim-WeldPlanning` | 焊接姿态/规划/生成焊缝/工艺列表/规划编排 | ✅ 已落地（id 1-11，见上表） |
| `Robim-VisionScan` | 扫描姿态规划/视觉单元 | ✅ 已落地（id 1-6，见上表） |
| `Robim-Workflow` | FSM 状态机流转（覆盖全部 55 节点） | ✅ 已落地（id 1-5，见上表） |
| `Robim-RobotControl` | 机器人运动规划/执行 | ⬜ 待落地。关键方法：RobotPlanSolver.TrySolveMoveLWithExternal, RobotPostExtension.MoveJ/MoveL |
| `Robim-VisionPositioning` | 粗/精定位 | ⬜ 待落地。关键方法：粗定位/精定位 FSM 节点 |

**新增事件 id 分配规则**：每个 EventSource 内部，`[Event(id)]` 的 id 从 1 开始递增，新增事件取当前最大 id + 1。跨 EventSource 不共享 id 空间。

## 二、参数设计

### 2.1 核心原则：带变量值，不是只发信号

EventSource 的价值在于**结构化地携带变量值**。只发 `Start()`/`End()` 信号和 ILogger 没有本质区别。每个事件必须带上定位问题所需的**输入参数和输出关键字段**。

判断"该带哪些变量"的方法：问自己"如果这个方法出问题（慢/错/卡），我最想看哪些值？"——那些值就是事件参数。

### 2.2 WriteEvent 参数类型硬限制

`EventSource.WriteEvent` 只接受以下类型：

- `string`、`char`
- `int`、`uint`、`long`、`ulong`、`short`、`ushort`、`byte`、`sbyte`
- `float`、`double`
- `bool`
- `decimal`（.NET 5+）
- 上述类型的**一维数组**（`int[]`、`string[]`、`double[]` 等）
- `IntPtr`、`Guid`、`DateTime`（特殊处理）

**不能传**：自定义 class、struct（除非是上面列的基础类型）、interface、Dictionary、嵌套集合、`Matrix4x4`、`WsWeldPosParam` 等业务对象。

**违反约束的后果**：编译能过（WriteEvent 接收 `object` 重载），但运行时抛 `EventSourceException` 或静默丢弃事件。

### 2.3 复杂对象拆解规则

#### 位姿 / 矩阵（weldone 最高频）

weldone 大量使用 `Matrix4x4`、`Pose`、`JointPoseDto`。埋点时拆解：

```csharp
// ❌ 不能整体传 Matrix4x4
[Event(1)] public void PoseReady(string id, Matrix4x4 pose) => WriteEvent(1, id, pose);

// ✅ 拆成位置 + 旋转
// 方式 A：旋转矩阵 9 分量（调试姿态最直观）
[Event(1)] public void PoseReady(
    string workpieceId, int seamIndex,
    double posX, double posY, double posZ,
    double r11, double r12, double r13,
    double r21, double r22, double r23,
    double r31, double r32, double r33)
    => WriteEvent(1, workpieceId, seamIndex,
                  posX, posY, posZ,
                  r11, r12, r13, r21, r22, r23, r31, r32, r33);

// 方式 B：四元数 4 分量（参数少，但不如旋转矩阵直观）
[Event(1)] public void PoseReadyQuat(
    string workpieceId, int seamIndex,
    double posX, double posY, double posZ,
    double qx, double qy, double qz, double qw)
    => WriteEvent(1, workpieceId, seamIndex, posX, posY, posZ, qx, qy, qz, qw);
```

**weldone 的 Matrix4x4 取值**（System.Numerics.Matrix4x4）：
- 位置：`pose.Translation.X/Y/Z`
- 旋转矩阵：`pose.M11/M12/M13/M21/.../M33`

**调用点拆解**：
```csharp
var p = resultPose;
WeldPlanningEventSource.Log.PoseReady(
    workpieceId, seamIndex,
    p.Translation.X, p.Translation.Y, p.Translation.Z,
    p.M11, p.M12, p.M13,
    p.M21, p.M22, p.M23,
    p.M31, p.M32, p.M33);
```

#### 集合

```csharp
// ❌ 不能传 List<Matrix4x4> 或 List<自定义类型>
[Event(1)] public void PosesReady(string id, List<Matrix4x4> poses) => ...

// ✅ 传 Count + 摘要（前几个元素的某个标量特征）
[Event(1)] public void PosesReady(
    string workpieceId, int seamIndex, int poseCount, double firstX, double firstY, double firstZ)
    => WriteEvent(1, workpieceId, seamIndex, poseCount, firstX, firstY, firstZ);
```

**集合摘要策略**：
- `List<Pose>` → `Count` + 第一个/最后一个 pose 的位置（判断起止点是否合理）
- `List<WeldSeam>` → `Count` + 前几个的 `SeamIndex`
- `byte[]`（如 orientationParam） → `Length` + 前几个值（`param[0]`、`param[1]`、`param[2]`）
- `float[]`（如 shortSeamParams） → `Length` + 前几个值

#### 业务对象

```csharp
// ❌ 不能传 WsWeldPosParam
[Event(1)] public void CalcStart(WsWeldPosParam param) => ...

// ✅ 提取关键标量字段
[Event(1)] public void CalcStart(
    string workpieceId, int seamIndex, int totalSeams, int mode, double angle, double gap)
    => WriteEvent(1, workpieceId, seamIndex, totalSeams, mode, angle, gap);
```

### 2.4 每类事件的必备参数

| 事件类型 | 必备参数 | 用途 |
|---|---|---|
| 所有事件 | `businessId`（workpieceId / seamIndex / taskName） | 关联同一业务流程的不同事件 |
| End 事件 | `success`（bool）、`durationMs`（double） | 判断是否异常、是否慢 |
| Slow 事件 | `durationMs`、`context`（触发慢的关键因素） | 慢操作定位 |
| 分支事件 | `branchName`、`conditionValue` | 确认走了哪条路 |

## 三、weldone 真实埋点示例

### 3.1 WeldPoseSolver（核心算法）

文件：`src/Robim.Algorithm.Weld/Solver/WeldPoseSolver.cs`

```csharp
public bool TryCalculateWeldToolPoses(WsWeldPosParam weldPoseParam, PoseCalculationMode mode,
    byte[] orientationParam, float[] shortSeamParams, out WsWeldPosRes wsWeldPosRes, string? debugDir = null)
{
    // === 埋点开始 ===
    var sw = Stopwatch.StartNew();
    WeldPlanningEventSource.Log.PoseCalcStart(
        workpieceId: weldPoseParam.WorkpieceId ?? "unknown",
        seamIndex: weldPoseParam.SeamIndex,
        totalSeams: weldPoseParam.TotalSeams,
        mode: mode.ToString(),
        orientationCount: orientationParam.Length,
        shortSeamParam0: shortSeamParams.Length > 0 ? shortSeamParams[0] : 0);
    // === 埋点结束 ===

    wsWeldPosRes = new();
    // ... 原有逻辑全部不变 ...

    // 返回前
    bool success = calSuc >= 0;
    int pointCount = ptsSize / Marshal.SizeOf<SomePointType>(); // 按实际算

    // === 埋点开始 ===
    WeldPlanningEventSource.Log.PoseCalcEnd(
        seamIndex: weldPoseParam.SeamIndex,
        success: success,
        durationMs: sw.Elapsed.TotalMilliseconds,
        pointCount: pointCount);
    if (sw.Elapsed.TotalMilliseconds > 3000)
        WeldPlanningEventSource.Log.PoseCalcSlow(
            seamIndex: weldPoseParam.SeamIndex,
            durationMs: sw.Elapsed.TotalMilliseconds,
            pointCount: pointCount);
    // === 埋点结束 ===

    return success;
}
```

**为什么带这些值**：
- `WorkpieceId + SeamIndex`：定位是哪个工件的哪条焊缝
- `mode + orientationCount + shortSeamParam0`：算法输入，不同 mode/参数可能触发不同性能/正确性分支
- `success + pointCount`：算法是否成功、产出了多少点（pointCount=0 但 success=true 就是可疑）
- `durationMs`：判断是否慢

### 3.2 FSM 状态节点（Workflow 流转）

文件：`src/Weldone.Application/States/ModelBase/10.WeldExecute.cs`

```csharp
[FSMNode("WeldExecute", [1, 2], ["Next", "Failed"])]
public partial class WeldExecute : AsyncEnumFSMNode<ScanWeldWorkflowData>
{
    public override async Task<Enum> ExecuteAsync(CancellationToken ct)
    {
        // === 埋点 ===
        var sw = Stopwatch.StartNew();
        var data = this.GetWorkflowData();
        WorkflowEventSource.Log.NodeEnter(
            nodeName: "WeldExecute",
            workpieceId: data.WorkpieceId ?? "unknown",
            currentSeamIndex: data.CurrentSeamIndex,
            totalSeams: data.TotalSeams);
        // === 埋点结束 ===

        // ... 原有逻辑 ...

        // 返回前
        var result = /* Next 或 Failed */;
        // === 埋点 ===
        WorkflowEventSource.Log.NodeLeave(
            nodeName: "WeldExecute",
            result: result.ToString(),
            durationMs: sw.Elapsed.TotalMilliseconds,
            currentSeamIndex: data.CurrentSeamIndex);
        // === 埋点结束 ===
        return result;
    }
}
```

**为什么带这些值**：FSM 卡死时，`NodeEnter` 没有 `NodeLeave` 配对 → 立刻知道卡在哪个节点。`durationMs` 超长 → 节点内部某步慢。

### 3.3 RobotPlanSolver（设备通信，死锁高发区）

文件：`src/Robim.Devices.Robot/Plan/Solver/RobotPlanSolver.cs`

```csharp
public bool TrySolveMoveLWithExternal(List<Pose> poses, string name, double[] externals, ...)
{
    var sw = Stopwatch.StartNew();
    RobotControlEventSource.Log.PlanStart(
        solverName: "MoveLWithExternal",
        moveName: name,
        poseCount: poses.Count,
        externalCount: externals.Length,
        firstPosX: poses.Count > 0 ? poses[0].Translation.X : 0,
        lastPosX: poses.Count > 0 ? poses[^1].Translation.X : 0);

    // ... 原有逻辑（这里有 await 设备响应，是卡死高发区）...

    RobotControlEventSource.Log.PlanEnd(
        solverName: "MoveLWithExternal",
        moveName: name,
        success: success,
        durationMs: sw.Elapsed.TotalMilliseconds);
    if (sw.Elapsed.TotalMilliseconds > 5000)
        RobotControlEventSource.Log.PlanSlow(
            solverName: "MoveLWithExternal", moveName: name,
            durationMs: sw.Elapsed.TotalMilliseconds, poseCount: poses.Count);
    return success;
}
```

## 四、FSM 状态门控（dotnet-monitor 配置必读）

weldone 涉及机器人运动控制。`dotnet-dump` 抓全量 dump 会触发 GC "Stop-The-World"，冻结所有线程几百毫秒到数秒。**如果焊接正在进行（机器人运动中），冻结 = 可能撞机或工件报废。**

### 门控规则

配置 dotnet-monitor Collection Rule 时，重型诊断（CollectDump / CollectTrace）必须加状态条件：

```
允许触发重型诊断的 FSM 状态：
  - WorkflowInit（初始化）
  - 空闲/等待态
  - ScanWeld 之前的准备态

禁止触发重型诊断的 FSM 状态（机器人运动中）：
  - WeldExecute（焊接执行中）
  - ScanExecute（扫描运动中）
  - TransitionExecute（过渡运动中）
  - 任何机器人 MoveJ/MoveL 执行期间
```

### 实现方式

方式 A（推荐）：在 dotnet-monitor 的 Collection Rule 的 Trigger 条件里，用一个自定义 EventCounter 暴露当前 FSM 状态，规则判断"状态非焊接态"时才触发。

方式 B：在 Program.cs 的 `UnhandledException` handler 里，先检查 FSM 当前状态再决定是否抓 dump：

```csharp
AppDomain.CurrentDomain.UnhandledException += (s, e) =>
{
    var currentState = FsmContext.CurrentStateName; // 按实际获取
    if (IsSafeToDump(currentState))
    {
        DumpCollector.Collect($"Weldone_crash_{DateTime.Now:yyyyMMddHHmmss}.dmp");
    }
    else
    {
        // 焊接中崩溃，只记日志不抓 dump（避免二次事故）
        FileLogger.Log($"Crash during {currentState}, dump skipped for safety");
    }
};
```

## 五、EventSource 验证方法

埋点完成后，按此验证：

```bash
# 1. 编译
dotnet build src/Robim.Algorithm.Weld/

# 2. 启动 Weldone

# 3. 另开终端，列出所有 .NET 进程
dotnet-counters ps

# 4. 监听自定义 EventSource（验证事件能正常发出）
dotnet-counters monitor -p <PID> --counters Robim-WeldPlanning

# 或用 trace 抓详细事件流
dotnet-trace collect -p <PID> --providers Robim-WeldPlanning --duration 00:00:30 --format speedscope

# 5. 触发对应业务操作（如执行一次焊缝规划）

# 6. 查看 .speedscope.json 中的事件流，确认事件名、参数值正确出现
```

若事件未出现，排查清单：
- EventSource 的 `Name` 是否和 `--providers` 参数一致
- `[Event(id)]` 的 id 是否唯一
- 参数类型是否符合「WriteEvent 参数类型硬限制」
- 调用点是否真的被执行到（加断点或 ILogger 确认）
