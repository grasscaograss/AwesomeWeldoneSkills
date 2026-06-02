---
name: modelbase-fsm
description: >
  ModelBase 状态机的完整架构参考。包含 FSM 拓扑图、节点枚举、转移事件、
  工作流数据结构、关键服务依赖、Yield API、图变换机制。
  当涉及状态机修改（增删节点、改转移、改节点逻辑、理解执行流程）时自动加载，
  避免每次反复读取源文件。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# ModelBase FSM 状态机参考

## 源文件位置

| 类别 | 路径 |
|------|------|
| FSM 脚本（拓扑定义） | `src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSM.FSMScript` |
| 枚举定义 | `src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMEngine_EnumDefine.cs` |
| Engine 类 | `src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMEngine.cs` |
| AppService | `src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMAppService.cs` |
| 节点实现 | `src/Weldone.Application/States/ModelBase/` |
| 工作流数据 | `src/Weldone.Application.Contracts/Workflows/ScanWeldWorkflowData.cs` |
| 全局数据 | `src/Weldone.Application.Contracts/Workflows/FullWorkflowData.cs` |

---

## 顶层状态图 (ModelBaseNode)

```
Init ──Init2WhileEvent──> While ──While2CoarseEvent──> Coarse ──Coarse2ScanWeldEvent──> ScanWeldPrepare
  │                         │                                                                      │
  └─Any2Exception──>Exn     └─While2ExitEvent──> Exit                               ScanWeldPrepare2WhileEvent
                                      ▲                                              │
                                      │                                              ▼
                          ScanWeldEnd ──ScanWeldEnd2WhileEvent──> ScanWeldWhile ──ScanWeldWhile2ExecuteEvent──> ScanWeldExecute
                                       (外层循环)         │
                                                          └─ScanWeldWhile2BreakEvent──> Exit
```

### 顶层枚举

```csharp
enum ModelBaseNode { Init, While, Coarse, ScanWeldPrepare, ScanWeldWhile, ScanWeldExecute, ScanWeldEnd, Exit, Exception }
enum ModelBaseEvent { Init2WhileEvent, While2CoarseEvent, While2ExitEvent, Coarse2ScanWeldEvent, ScanWeldPrepare2WhileEvent, ScanWeldWhile2ExecuteEvent, ScanWeldWhile2BreakEvent, ScanWeldExecute2EndEvent, ScanWeldEnd2WhileEvent, EndEvent, Any2ExceptionEvent }
```

### 三个 Executor

| Executor | 起始节点 | 终止事件 | 用途 |
|----------|----------|----------|------|
| `Executor` | Init | EndEvent | 完整流程 |
| `ScanWeldExecutor` | ScanWeldPrepare | EndEvent | 仅扫描焊接循环 |
| `CoarseExecutor` | Coarse | Coarse2ScanWeldEvent | 仅粗定位 |

---

## 内层 ScanWeld 状态图 (ScanWeldNode)

这是 `ScanWeldExecute` 节点 `[ScanWeldPlan -> ScanWeldEndEvent]` 的内部子状态机。

```
ScanWeldPlan ──SWPlan2Next──> ForeachScanWeld ──ForeachSW2Next──> ForeachScanUnit ──ForeachWS2Next──> CheckIfCG4S
  │                              │                      │              │                              │
  │                              │                      │              └──ForeachWS2Break──> ForeachWeldMultiPass
  │                              │                      │                                             │
  │                              └──ForeachSW2Break──> ScanWeldExit                                    │
  │                                                                                 ┌───────────┘
  │                                                                                 │
  │  ┌──────────────────── 循环回来 ──────────────────────┐                         │
  │  │                                                    │                         ▼
  │  ▼                                           ForeachWeldMultiPass ──ForeachMultiPass2Next──> CheckIfCG4W
  │ MoveToNextWeldSeam ──NextWeldSeam2Next──> ForeachScanWeld          │                    │
  │  ▲                                       (外层循环)    └──ForeachMultiPass2Break──> ForeachScanWeld
  │  │                                                                                      │
  │  │                      ScanTransPlan ◄──CGBackPlan4S── CG4SExecute ◄── CGTrans4S ◄── CGPrepare4S
  │  │                       │    ▲             │                     │             │
  └──┼── Scan2Failed ◄── ScanExecute/RhScanExecute                  └─CG4WExecute ◄── CGTrans4W ◄── CGPrepare4W
     │                     │    │
     │                  Scan2Next──> ForeachScanUnit
     │
     └── Weld2Failed ◄── WeldExecute/RhWeldExecute
            │    │
            │  Weld2Next──> ForeachWeldMultiPass
            │
            └── Weld2Break──> WeldUnrecognized
                                ├── WeldUnrecognized2Failed──> ScanTransPlan (重新扫描)
                                ├── WeldUnrecognized2Break──> MoveToNextWeldSeam (跳过)
                                └── WeldDeviationConfirmed──> WeldExecute (继续焊接)
```

### 内层枚举

```csharp
enum ScanWeldNode {
    ScanWeldPlan, ForeachScanWeld, ForeachScanUnit,
    ScanTransPlan, ScanTrans, ScanExecute, RhScanExecute,
    ForeachWeldMultiPass, WeldTransPlan, WeldTrans,
    WeldExecute, RhWeldExecute,
    CheckIfCleanGun, RobotCleanGun,
    MoveToNextWeldSeam, ScanWeldExit, Exception
}

enum ScanWeldEvent {
    SWPlan2Next, ForeachSW2Next, ForeachSW2Break,
    ForeachWS2Next, ForeachWS2Break,
    ScanTransPlan2Next, ScanTransPlan2Skip, ScanTrans2Next,
    Scan2Next, Scan2Failed,
    ForeachMultiPass2Next, ForeachMultiPass2Break,
    WeldTransPlan2Next, WeldTrans2Next,
    Weld2Next, Weld2Failed,
    NextWeldSeam2Next, ScanWeldEndEvent, Any2ExceptionEvent
}
```

---

## 图变换（Normal vs Complex Contour）

Engine 在运行时通过 `Transform2NormalConnect()` 或 `Transform2ComplexContourConnect()` 动态切换 Scan/Weld 节点：

| 模式 | Scan 节点 | Weld 节点 | CGBack 回归目标 |
|------|-----------|-----------|----------------|
| Normal | `ScanExecute` | `WeldExecute` | CGBack4S→ScanTransPlan, CGBack4W→WeldTransPlan |
| Complex (Rhino) | `RhScanExecute` | `RhWeldExecute` | CGBack4S→RhScanExecute, CGBack4W→RhWeldExecute |

---

## 清枪 (Clean Gun) 子流程

**扫描前清枪 (4S 分支):**
```
CheckIfCG4S ──CheckCG4S2Break──> ScanTransPlan (无需清枪)
             └──CheckCG4S2Next──> CGPrepare4S -> CGTrans4S -> CG4SExecute -> CGBackPlan4S -> ScanTransPlan
```

**焊接前清枪 (4W 分支):**
```
CheckIfCG4W ──CheckCG4W2Next──> WeldExecute (无需清枪)
             └──CheckClean2Next──> CGPrepare4W -> CGTrans4W -> CG4WExecute -> CGBackPlan4W -> WeldTransPlan
```

---

## Yield API

节点实现为 `IEnumerable<Yield>` 协程，通过 `yield return` 返回：

| Yield | 含义 | 对应 FSMScript 事件 |
|-------|------|---------------------|
| `Yield.Next` (值=1) | 正常推进到下一节点 | `xxx2Next` |
| `Yield.Break` (值=3) | 跳出循环/跳过 | `xxx2Break` / `xxx2Skip` |
| `Yield.Failed` (值=2) | 失败，走失败路径 | `xxx2Failed` |
| `Yield.Pause` | 暂停当前节点 | - |
| `Yield.Event(int)` | 发射自定义事件号 | FSMScript 中 `10086->WeldDeviationConfirmed` |
| `Yield.ToNodeStart` | 重新执行当前节点 | - |
| `Yield.Delay(ms)` | 延迟后继续 | - |
| `Yield.None` | 什么都不做，继续执行 | - |
| `Yield.RetryIfPaused(fn)` | 暂停恢复后重试 fn | - |
| `Yield.TryCatch(fn)` | 带错误捕获执行 fn | - |

---

## 节点实现速查

| 文件 | 节点 Type | 行数 | 职责 |
|------|-----------|------|------|
| `Plan/1.ScanWeldPlan.cs` | ScanWeldPlan | 348 | 规划：启动后台任务生成扫描焊接计划，通过 Channel 投喂任务 |
| `2.ForeachScanWeldExecute.cs` | ForeachScanWeldExecute | 98 | 迭代器：从 ExecuteTaskChannel 取焊缝对，初始化精定位任务 |
| `3.CheckScanState.cs` | CheckScanState | 41 | 判断：首次进→扫描，二次进→跳到焊接 |
| `3.ForeachScanUnit.cs` | ForeachScanUnit | 95 | 迭代器：遍历焊缝段，跳过已完成精定位的段 |
| `4.ScanTransitionPlan.cs` | ScanTransPlan | 129 | 规划：P2P 过渡到扫描起点 |
| `5.TransitionExecute.cs` | TransitionExecute | 52 | 执行：运行过渡路径（暂未使用） |
| `6.ScanExecute.cs` | ScanExecute | 518 | **核心**：精定位扫描，机器人运动+相机拍照+精定位计算 |
| `6-2.RhScanExecute.cs` | RhScanExecute | 99 | Rhino 变体扫描 |
| `7.ForeachWeldMultiPass.cs` | ForeachWeldMultiPass | 58 | 迭代器：遍历多层多道 |
| `8.WeldTransitionPlan.cs` | WeldTransitionPlan | 92 | 规划：P2P 过渡到焊接起点 |
| `10.WeldExecute.cs` | WeldExecute | 488 | **核心**：焊接执行，含 LS 文件生成、偏差检查、清枪判断 |
| `10-2.RhWeldExecute.cs` | RhWeldExecute | 97 | Rhino 变体焊接 |
| `10.1CheckIfCleanGun.cs` | CheckIfCleanGun | 112 | 判断：累计焊长/弧时是否达阈值 |
| `10.2CleanGunPrepare.cs` | CleanGunPrepare | 44 | 规划：到清枪站的过渡 |
| `10.5RobotCleanGun.cs` | RobotCleanGun | 50 | 执行：调用机器人清枪 |
| `10.6CleanGunPrepare.cs` | CleanGunBackPlan4Scan | 113 | 规划：清枪后回扫描位 |
| `10.9WeldUnrecognized.cs` | WeldUnrecognized | 103 | 错误处理：Cancel/Retry/Skip/Continue 四种结果 |
| `11.MoveToNextWeldSeam.cs` | MoveToNextWeldSeam | 74 | 恢复：同步关节位置，发布失败状态 |
| `12.ScanWeldExit.cs` | ScanWeldExit | 31 | 终止：发布 TaskInfoUpdateEvent |
| `EHomeTransitionPlan.cs` | - | 48 | E-Home 过渡规划 |
| `MoveNext.cs` | - | 24 | 递增 ExecuteIndex |
| `TakeExecuteTask.cs` | - | 45 | 阻塞式从 ExecuteTaskCollection 取任务 |

---

## 关键服务依赖

节点通过 DI 注入以下服务：

| 服务 | 用途 | 使用节点 |
|------|------|----------|
| `IRobotManagementAppService` | 机器人管理（Home位姿、清枪、过渡执行） | ScanTransPlan, CleanGun*, TransitionExecute |
| `IVisionRobotAppService` | 视觉机器人（拍照、精定位） | ScanExecute, ScanWeldPlan |
| `IWeldRobotAppService` | 焊接机器人（焊接执行） | WeldExecute, WeldTransPlan, RhWeldExecute |
| `DualPrecisePositionAppService` | 精定位服务 | ScanExecute, WeldExecute, ScanWeldPlan |
| `PrecisePositioningManager` | 精定位管理器 | ScanTransPlan |
| `PlanManager` | 规划管理器 | ScanWeldPlan, ScanTransPlan |
| `SolverContextRepository` | 几何/工艺数据 | ScanWeldPlan, ForeachScanUnit, ForeachWeldMultiPass, WeldExecute |
| `AccumulatorForCleanGunAppService` | 清枪累计器 | CheckIfCleanGun, RobotCleanGun |
| `VisionCaptureManager` | 视觉拍照管理 | ScanExecute |
| `ISettingProvider` | 配置读取 | WeldExecute, CheckIfCleanGun |

---

## 工作流数据结构

### FullWorkflowData（全局，Context.Data）

```
FullWorkflowData
├── Tasks: List<TaskFlowData>           # 自动排单任务列表
├── WpItems: List<WorkpieceFlowData>    # 手动排单工件列表
├── SkipList: List<Guid>                # 跳过列表
├── CurrentWorkpieces: List<Guid>       # 当前工件
├── Template: PlateTemplate             # 模板
├── Coarses: Dict<Guid, Matrix4x4>      # 粗定位结果
├── CurrentScanWeldFlowData             # 当前扫描焊接数据
├── PosBeforeExecute: JointPoseDto      # 执行前位姿
└── ScanWeldWorkflowDataDict            # 按工件Guid索引的扫描焊接数据
```

### ScanWeldWorkflowData（内层，通过 Dict 按 Guid 取）

```
ScanWeldWorkflowData
├── Id, WorkpieceId, Round
├── WsgIds: List<Guid>                  # 全部焊缝组ID
├── SuccessWsgIds: List<Guid>           # 已成功焊缝组ID
├── SkipScan: bool                      # 是否跳过扫描
├── SkipList: List<Guid>                # 跳过列表
├── ArmJointPoses: Dict<int, JointPoseDto>  # 各机械臂关节位姿
├── TransitionProcess: Process          # 过渡工艺
├── ExecuteTaskChannel: Channel<Guid>   # 异步任务队列
├── CurrentWeldSeamPair: WeldSeamPairContext  # 当前焊缝对（双机）
├── CurrentPassIndex: int               # 多层多道当前道次
├── CrtCraftId: Guid                    # 当前工艺ID
├── NeedRePlanScanTrans / NeedRePlanWeldTrans  # 重规划标记
├── DeviationConfirmed: bool            # 偏差已确认
├── ScanCaches / ScanTransCaches        # 扫描缓存
├── WeldCaches / WeldTransCaches        # 焊接缓存
├── PreciseCaches                       # 精定位缓存
└── ExternalCaches                      # 外部轴缓存
```

---

## 注意事项

1. **FSMScript 是单一真相源**：节点名、Type、转移关系都在 `.FSMScript` 文件中定义。新增/修改节点必须同步更新此文件。
2. **节点 Type 映射**：`def ScanExecute(ScanExecute)` 中括号内是 Type，用于 DI 创建节点实例。多个 def 可共享同一个 Type（如 `CG4SExecute` 和 `CG4WExecute` 都用 `RobotCleanGun`）。
3. **图变换是运行时的**：`Transform2NormalConnect()` / `Transform2ComplexContourConnect()` 在 Engine 初始化后调用，修改连线关系，不修改节点定义。
4. **Deprecated 字段**：`CurrentWSGID`、`CrtScanWsgIds`、`ArmIndex` 已废弃，应使用 `CurrentWeldSeamPair` 相关 API。
