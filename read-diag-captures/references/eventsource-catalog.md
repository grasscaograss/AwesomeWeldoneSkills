# weldone EventSource 目录（权威版）

解读 dotnet-trace / speedscope 采集到的事件流时，用本表把 **EventID 翻译成事件名 + 参数顺序与语义**。

> **权威性说明**：本表基于实际 `*EventSource.cs` 源码核对（2026-07-03）。`add-diag-instrumentation/references/instrumentation-guide.md` 的早期版本把 `Robim-Workflow` 列为"待落地"、且对 `Robim-VisionScan` 的 id 3/id 4 参数描述有误——**以本文件为准**。两份 guide 已同步修正，后续新增事件两边一起更新。

所有 EventSource 的 `Name` 是字符串常量，**不受代码混淆影响**。混淆后照样能用 `dotnet-trace --providers <Name>` 按名开启。

## 总览

| EventSource 名 | 文件位置 | 业务域 | 状态 |
|---|---|---|---|
| `Robim-WeldPlanning` | `src/Weldone.Domain/Welding/ToolPlanning/WeldPlanningEventSource.cs` | 焊缝规划/姿态计算/生成焊缝/工艺列表/规划编排 | ✅ 已落地，已用 event id: 1-11 |
| `Robim-VisionScan` | `src/Weldone.Application/Scanning/VisionScanEventSource.cs` | 扫描姿态规划/视觉单元 | ✅ 已落地，已用 event id: 1-6 |
| `Robim-Workflow` | `src/Weldone.Application/StateEngines/WorkflowEventSource.cs` | FSM 状态机流转（55 个 `[FSMNode]` 节点的进入/离开，单一汇聚点捕获） | ✅ 已落地，已用 event id: 1-5 |
| `Robim-RobotControl` | `src/Weldone.Application/Robot/RobotControlEventSource.cs` | 机器人寄存器读写/握手等待/关节位姿读取 | ✅ 已落地，已用 event id: 1-8 |

---

## `Robim-WeldPlanning`（id 1-11）

采集命令：`dotnet-trace collect -p <PID> --providers Robim-WeldPlanning --duration 00:00:30`

事件 id 1-5 的前两个参数恒为 `wsgName`（焊缝组名）、`cilIdx`（CIL 指定序号），用于关联同一焊缝组的多次计算。id 6 起改用 `workpieceId` 作为业务标识。

| id | 方法 | Level | 参数（顺序） | 埋点位置 | 说明 |
|---|---|---|---|---|---|
| 1 | `PlanGroupStart` | Info | `wsgName, cilIdx, wsgIndex, mode, isMerged` | `WeldPoseSolverManager.CalculateWeldToolPoses` 入口 | wsgIndex=焊缝组序号，mode=规划模式枚举名，isMerged=是否合并焊缝组 |
| 2 | `PlanGroupEnd` | Info | `wsgName, cilIdx, success, durationMs, basePoseCount, multiPassCount` | `CalculateWeldToolPoses` 两个 return 前（正常 + 早期返回） | basePoseCount=基础姿态数，multiPassCount=多层多道数 |
| 3 | `PlanGroupSlow` | Warning | `wsgName, cilIdx, durationMs, basePoseCount` | `CalculateWeldToolPoses` 正常 return 前（>3s） | 慢操作阈值告警 |
| 4 | `NativeCalcResult` | Info | `wsgName, cilIdx, nativeSuccess, resultPointCount, durationMs` | `TryCalculateWeldToolPoses` 调用后 | native 算法调用结果 |
| 5 | `NativeCalcFallback` | Warning | `wsgName, cilIdx, reason` | 三处降级点（merged/empty/exception） | native 失败降级原因 |
| 6 | `GenPathsStart` | Info | `workpieceId, workpieceType, isSymmetricSplited, isLengthBreak` | `FlexBeamWorkpieceManager.GenerateWeldPathsAsync` 入口 | workpieceType=工件类型，两个 bool 是几何拆分开关 |
| 7 | `GenPathsEarlyReturn` | Warning | `workpieceId, reason` | `GenerateWeldPathsAsync` 两处提前返回（native 几何/CIL 生成失败） | 提前退出原因 |
| 8 | `GenPathsEnd` | Info | `workpieceId, wsgCount, seamCount, wrapPairCount, durationMs` | `GenerateWeldPathsAsync` 出口 | wsgCount=焊缝组数，seamCount=焊缝数，wrapPairCount=包角对数 |
| 9 | `CraftListBuilt` | Info | `workpieceId, craftCount, mergedCount, isWrapOn, durationMs` | `GenerateCraftList`+`ChangeCraftListWithSelected`+合并后（`GenerateWeldPathsAsync` 末段） | craftCount=工艺数，mergedCount=合并后工艺数 |
| 10 | `PlanOrchestratorStart` | Info | `workpieceId, totalWsgCount, wrapPairCount, reCalculate` | `WeldPlanAppService.WeldToolPosePlanAsync` 入口 | reCalculate=是否强制重算 |
| 11 | `PlanOrchestratorEnd` | Info | `workpieceId, resultCount, cacheHitCount, failedCount, templateMatchMs, totalDurationMs` | `WeldToolPosePlanAsync` 出口 | resultCount=产出结果数，cacheHitCount=缓存命中数，failedCount=失败数 |

**后续追加事件从 id=12 起编号。**

---

## `Robim-VisionScan`（id 1-6）

采集命令：`dotnet-trace collect -p <PID> --providers Robim-VisionScan --duration 00:00:30`

| id | 方法 | Level | 参数（顺序） | 埋点位置 | 说明 |
|---|---|---|---|---|---|
| 1 | `ScanPlanStart` | Info | `workpieceId, totalWsgCount, hybridCount, nativeCount` | `VisionCaptureAppService.VisionToolPosesPlanParallel` 入口 | hybridCount=走拍照点规划的焊缝组数，nativeCount=走 native 推扫的焊缝组数 |
| 2 | `NativeVcdResult` | Info | `workpieceId, unitCount, durationMs` | `CreateVisionCaptureData` 调用后 | unitCount=产出的视觉单元数 |
| 3 | `VisionUnitProcessed` | Info | `workpieceId, unitId, success, capPoseCount, validation` | `ProcessVisionUnitWeldSeamGroup` 后（成功 + 异常两路） | **validation**=-1=未校验, 0=失败, 1=成功；capPoseCount=拍照点数 |
| 4 | `NativeVcdFallback` | Warning | `workpieceId, reason, hasHybridEndpoint` | native VCD 解析异常 catch | **hasHybridEndpoint**=是否含混合拍照端点 |
| 5 | `HybridUnitBuilt` | Info | `workpieceId, wsgId, capPoseCount, validation` | `CreateHybridVisionUnitAsync` 后 | validation 同上 |
| 6 | `ScanPlanEnd` | Info | `workpieceId, totalDtos, durationMs` | `VisionToolPosesPlanParallel` 出口 | totalDtos=产出 DTO 总数 |

**后续追加事件从 id=7 起编号。**

> ⚠️ instrumentation-guide.md 早期版本对 id 3、id 4 的参数描述（漏 `validation`、漏 `hasHybridEndpoint`）已过时，以上为准。

---

## `Robim-Workflow`（id 1-5）

采集命令：`dotnet-trace collect -p <PID> --providers Robim-Workflow --duration 00:00:30`

所有事件第一个参数 `fsmType` 区分多个并发 FSM 执行器（枚举名，如 ModelBase / ModelFree）。

| id | 方法 | Level | 参数（顺序） | 说明 |
|---|---|---|---|---|
| 1 | `RunStart` | Info | `fsmType, executorRole, workpieceIds` | FSM 运行启动（`RestartAsync`）。executorRole=执行角色，workpieceIds=逗号分隔的工件 ID（可能为空） |
| 2 | `NodeEnter` | Info | `fsmType, nodeName, prevNode` | 节点进入。prevNode=来源节点（首次为空）；异常转移时 prevNode=抛异常的节点 |
| 3 | `NodeLeave` | Info | `fsmType, nodeName, durationMs` | 节点离开。durationMs=该节点从进入到离开的停留时长（含人工等待/设备 IO） |
| 4 | `NodeStuck` | Warning | `fsmType, nodeName, durationMs` | 节点停留超阈值（默认 30s，含人工等待节点会更长）。用于快速定位卡住的节点 |
| 5 | `StateChanged` | Info | `fsmType, state, prevState` | FSM 执行器状态变化（Running/Paused/Stopped/Finished） |

**后续追加事件从 id=6 起编号。**

### `Robim-Workflow` 典型诊断场景（解读事件流时套用）

- **FSM 卡死**：`NodeEnter` 没有配对的 `NodeLeave` → 立刻知道卡在哪个 `nodeName`。
- **节点慢**：`NodeLeave` 的 `durationMs` 超长 → 该节点内部某步慢（通常是设备通信/人工等待）。
- **异常转移**：`NodeEnter` 的 `prevNode=ExceptionNode` → 知道是哪个节点抛的异常。
- **循环死锁**：同一 `nodeName` 反复 Enter/Leave 且不推进 → 业务逻辑死循环。

---

## `Robim-RobotControl`（id 1-8）

采集命令：`dotnet-trace collect -p <PID> --providers Robim-RobotControl --duration 00:00:30`

覆盖机器人控制器寄存器读写——weldone 与物理机器人控制器通信的核心路径，偶发卡死高发区（寄存器握手等待示教器刷新）。埋点位置：`RobotManagementAppService` 的寄存器握手方法。所有事件以 `register`（寄存器号）为关联键。

| id | 方法 | Level | 参数（顺序） | 埋点位置 | 说明 |
|---|---|---|---|---|---|
| 1 | `RegWrite` | Info | `register, value` | `RunTransition` 内 `WriteIntRegisterAsync` 后 | 整数寄存器写入 |
| 2 | `RegWaitStart` | Info | `register, expectValue, timeoutSec` | `RunTransition` 内 `WaitIntRegisterAsync` 前 | 开始等待寄存器达到期望值 |
| 3 | `RegWaitResult` | Info | `register, success, durationMs` | `RunTransition` 内 `WaitIntRegisterAsync` 后 | 等待结果（success=是否达到期望值） |
| 4 | `RegWaitTimeout` | Warning | `register, expectValue, durationMs` | `WaitIntRegisterAsync` 返回 false 时 | 等待超时（机器人未在预期内响应） |
| 5 | `RegReadFloat` | Info | `register, value, durationMs` | `ReadArcEndPosition`/`GetLaserPointInRobotCoord` 的 `ReadFloatRegisterAsync` 后 | 浮点寄存器读取 |
| 6 | `RegReadInt` | Info | `register, value` | `CheckTeachPendantOffAsync` 的 `ReadIntRegisterAsync` 后 | 整数寄存器读取 |
| 7 | `JointPoseRead` | Info | `source, robotIndex, j0, j1, j2, j3, j4, j5, e0, e1, e2` | `GetJointPoseFromRegistersAsync`/`ReadArcEndPositionFromRegistersAsync` 出口 | 关节位姿读取（6 关节 + 3 外轴，共 9 值） |
| 8 | `HandshakeDone` | Info | `operation, success, durationMs, step` | `RunTransition` 出口（成功/失败两路） | 握手协议完成；step=卡在的步骤名 |

**后续追加事件从 id=9 起编号。**

**寄存器握手协议**：weldone 与机器人控制器通过"写寄存器→等寄存器达到期望值"的握手协议通信（如 `RunTransition`：写 Process→等 TransitionFile=UploadRequest→上传→写 UploadSuccess→等 TransitionJob=RobotStart→写 HostResponseStart→等 RobotFinish）。每一步的 `WaitIntRegisterAsync` 都是阻塞等待，是卡死高发区（代码注释："bug 这里写了 示教器也有值 但是卡住了没有下一步"）。埋点让每一步等待的耗时、是否超时完全可见。

### `Robim-RobotControl` 典型诊断场景（解读事件流时套用）

- **握手卡死**：`RegWaitStart` 没有配对的 `RegWaitResult` → 卡在等哪个 `register`、等什么 `expectValue`。
- **握手超时**：`RegWaitTimeout`（success=false）→ 机器人没在预期时间内响应。
- **关节读取异常**：`JointPoseRead` 的 `j0..j5` 值越界/NaN → 通信干扰或寄存器映射错位。
- **定位失败步骤**：`HandshakeDone` 的 `step` 字段 → 知道卡在握手协议的哪一步。

---

## 新增事件 id 分配规则

每个 EventSource 内部，`[Event(id)]` 的 id 从 1 开始递增，新增事件取当前最大 id + 1。**跨 EventSource 不共享 id 空间**（三个 EventSource 各有独立的 id 1、2、3…）。

新增事件时：
1. 改对应 `*EventSource.cs`（加 `[Event(id)]` 方法）
2. 更新本文件对应表（补 id 行）
3. 同步更新 `add-diag-instrumentation/references/instrumentation-guide.md` 的对应清单
