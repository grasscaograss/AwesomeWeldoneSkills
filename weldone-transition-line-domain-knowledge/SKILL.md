---
name: weldone-transition-line-domain-knowledge
description: Weldone 项目 TransitionLine 过渡段统一模型的领域知识库。涵盖 PoseRef 位姿引用、TransitionLine 连接线模型、ArmTransitionState 存储结构、FSM 节点消费流程、位姿解析路由、双臂三段式过渡规划等核心概念。适用于分析过渡段规划/查询代码、排查扫描/焊接过渡问题、理解 FSM 中 TransitionPlan 节点逻辑。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Weldone TransitionLine 过渡段领域知识

## 1. 核心类型

### PoseRef — 位姿引用

三元组 `(SegmentId, PoseRole, Tag?)`，精确定位到某工艺段的某个语义位姿，用作 TransitionLine 的端点和字典 key。

```csharp
public readonly struct PoseRef
{
    public Guid SegmentId { get; }   // WSG/焊缝的 GUID，全局位姿用 Guid.Empty
    public PoseRole Role { get; }    // 语义角色
    public string? Tag { get; }      // 细分标记（如 "Pass1", "Seg0", "Cap2", "Arm0"）
}
```

### PoseRole 枚举

| 角色 | 含义 | SegmentId | Tag 格式 |
|---|---|---|---|
| `Home` | 机器人默认 Home 位 | `Guid.Empty` | 无 |
| `SafetyPoint` | 安全点 | WSG ID | 同 ArcStart |
| `ArcStart` | 焊接起弧点 | WSG ID | `"Pass{N}"` |
| `ArcEnd` | 焊接收弧点 | WSG ID | `"Pass{N}"` |
| `ScanStart` | 扫描起点 | WSG ID | `"Seg{i}"` 或无 |
| `ScanEnd` | 扫描终点 | WSG ID | `"Seg{i}"` 或无 |
| `ScanPoint` | 单点重扫目标 | WSG ID | `"Cap{N}"` |
| `WorkpieceEnd` | 工件结束位（外部轴Home） | `Guid.Empty` | `"Arm{N}"` |
| `EHome` | 中间 Home（过渡用） | `Guid.Empty` | `"Arm{N}"` 或无 |
| `CleanGun` | 清枪位 | `Guid.Empty` | `"Arm{N}"` |
| `ActualPosition` | 机器人当前实际位置 | `Guid.Empty` | 无 |

### TransitionLine — 连接线

连接两个 PoseRef 的过渡路径，类似图的边。Id 由 `(Source, Target)` MD5 确定性计算，外部不需要感知 Id。

```csharp
public class TransitionLine
{
    public Guid Id { get; }                // MD5(Source + Target) 确定性计算
    public PoseRef Source { get; }         // 起点
    public PoseRef Target { get; }         // 终点
    public Process? Process { get; set; }       // 规划出的机器人运动路径
    public Process? ApproachProcess { get; set; } // 进近路径
    public bool? Validation { get; set; }       // 是否有效
}
```

## 2. 存储结构

```
ScanWeldWorkflowData
├── ArmTransStateDict: Dict<int, ArmTransitionState>  // 每条臂一个
│   ├── [0] ArmTransitionState (左臂)
│   │   ├── CurrentPoseRef      // 当前位姿引用
│   │   ├── TargetPoseRef       // 目标位姿引用（FSM上游节点设置）
│   │   ├── ActualPoses         // Dict<PoseRef, JointPose> 实际位姿缓存
│   │   └── PlannedTransitions  // List<TransitionLine> 已规划的过渡段
│   └── [1] ArmTransitionState (右臂)
│       └── ...
├── AllTransitionLines           // 扁平视图：SelectMany(PlannedTransitions)
├── ScanCaches[unitId]           // 扫描缓存（含 Process）
├── WeldCaches[segmentId]        // 焊接缓存（含 MultiPlanCacheItems）
└── AddTransitionLine(armIdx, line)  // 按臂号归档
```

### ArmTransitionState 关键方法

| 方法 | 作用 |
|---|---|
| `SetCurrent(poseRef, jointPose)` | 设置当前位置并缓存到 ActualPoses |
| `SetTarget(target)` | 设置目标位姿（FSM 上游写入，TransitionPlan 消费） |
| `SetTargetPinned()` | 将目标锁定为当前位置（用于无目标场景） |
| `SaveTarget() / RestoreTarget()` | 保存/恢复目标（清枪等临时中断场景） |

## 3. FSM 流程

### 扫描过渡

```
ForeachScanWeldExecute
    └── SetTarget(new PoseRef(wsgId, ScanStart))   // 设置扫描目标
            ↓
    ScanTransPlan (TransitionPlan 节点)
        ├── 清空 arm.PlannedTransitions
        ├── source = arm.CurrentPoseRef（或 Home）
        ├── PlanForArmAsync(source, target)
        │   ├── 先查缓存: TryGetLine(data, source, target)
        │   └── 未命中 → PlanTransitionAsync(实时规划)
        └── 补充 finish line: ScanEnd → EHome
            ↓
    ScanExecuteRouter → 扫描执行
```

### 焊接过渡

```
ForeachWeldMultiPass
    └── SetTarget(new PoseRef(wsgId, ArcStart, "Pass1"))   // 设置焊接目标
            ↓
    WeldTransPlan (TransitionPlan 节点)
        ├── 同上逻辑
        └── 补充 finish line: ArcEnd → EHome
            ↓
    WeldExecute → 焊接执行
```

### 清枪过渡

```
CheckIfCleanGun
    └── SetTarget(PoseRef.CleanGun(armIdx))   // 目标改为清枪位
            ↓
    CGPrepare4W / CGPrepare4S (TransitionPlan)
            ↓
    CGTrans4W / CGTrans4S (TransitionExecute)
            ↓
    CleanGunExecute → 清枪完成 → RestoreTarget() → 恢复原目标
```

### 过渡段在 FSM 中的所有节点

| FSM 节点 | Type | 场景 |
|---|---|---|
| `ScanTransPlan` | TransitionPlan | 扫描前过渡（到 ScanStart） |
| `SingleScanTransPlan` | TransitionPlan | 单点扫描前过渡 |
| `WeldTransPlan` | TransitionPlan | 焊接前过渡（到 ArcStart） |
| `CGPrepare4W` | TransitionPlan | 清枪前过渡（焊接场景） |
| `CGPrepare4S` | TransitionPlan | 清枪前过渡（扫描场景） |
| `TransitionExecute` | TransitionExecute | 执行已规划的过渡段 |
| `CGTrans4W` / `CGTrans4S` | TransitionExecute | 清枪过渡执行 |

## 4. 查询 API（PlanManager.TransitionLine.cs）

| 方法 | 用途 |
|---|---|
| `TryGetLine(data, source, target)` | 按源/目标精确查一条（MD5 Id 匹配） |
| `GetOutgoingLines(data, source)` | 某位姿出发的所有过渡 |
| `GetIncomingLines(data, target)` | 到达某位姿的所有过渡 |
| `GetLinesBySegment(data, segmentId)` | 与某 WSG 相关的所有过渡 |
| `GetAllLines(data)` | 全部过渡段 |
| `CollectSegmentTransitions(data, wsgId)` | 收集某 WSG 的段间扫描过渡（`Seg{i}` Tag，按序排列） |

## 5. 位姿解析路由（TryResolvePose）

PoseRef → JointPoseDto 的解析链：

```
TryResolvePose(data, poseRef)
│
├── 1. ActualPoses 缓存命中 → 直接返回
│
├── 2. WorkpieceEnd / EHome / CleanGun
│       → TryResolveGlobalPose → GetHomePose(armIndex) → 缓存到 ActualPoses
│
├── 3. Home → GetHomePose(0, [0,0,0])
│
├── 4. ScanStart / ScanEnd / ScanPoint
│       → TryResolveScanPose
│       ├── Tag="Seg{i}" → 段内位姿（ParseProcess 取第 i 段的 ArmPlanData 首/末点）
│       ├── Tag="Cap{N}" → 拍照位姿（所有段的 ArmPlanData 按序展平取第 N 个）
│       └── 无 Tag → CreateVisionPlanJoint 取整体首/末
│
└── 5. ArcStart / ArcEnd / SafetyPoint
        → TryResolveWeldPose
        ├── 从 Tag 解析 passIndex（"Pass{N}" 或纯数字）
        ├── WeldCaches[segmentId].MultiPlanCacheItems 匹配 passIndex
        └── CreateWeldPlanJoint 取首/末
```

## 6. 双臂过渡规划（PlanDualArmTransitionCore）

三段式安全过渡路径：

```
start → EHome(current externals) → EHome(target externals) → target
  P1              P2                        P3
```

- **P1**: start → EHome（当前外部轴位置）
- **P2**: EHome（当前外部轴）→ EHome（目标外部轴）— 仅外部轴不同时执行
- **P3**: EHome（目标外部轴）→ target

**跳过优化**：
- start 已在 EHome 且外部轴相同 → 跳过 P1
- 两步 EHome 的关节+外部轴完全一致 → 跳过 P2
- 外部轴不同时 `viaEHome` 强制为 true

**单臂/简化过渡**：`WorkpieceEnd/EHome/CleanGun` 始终使用单臂 `SolveP2PProcesses`。

## 7. 扫描段间过渡（PlanScanSegmentTransitionsAsync）

多段推扫的段间过渡规划：

```
ScanEnd[Seg0] → ScanStart[Seg1]    // 段 0→1 过渡
ScanEnd[Seg1] → ScanStart[Seg2]    // 段 1→2 过渡
...
```

- 遍历相邻段，用 `SolveP2PAsync` 规划关节空间过渡路径
- 结果存入 `AllTransitionLines`，逐段容错（失败跳过，后处理 fallback 到 GroupMoveL）
- Tag 格式：`"Seg{i}"` 标识段内位姿

## 8. 关键文件索引

| 文件 | 作用 |
|---|---|
| `src/Weldone.Domain/Cache/TransitionLineTypes.cs` | PoseRef / TransitionLine / PoseRole 定义 |
| `src/Weldone.Domain/Cache/ArmTransitionState.cs` | 单臂过渡状态（CurrentPoseRef、PlannedTransitions） |
| `src/Weldone.Application/Plan/PlanManager.TransitionLine.cs` | 查询、规划、存储的核心实现 |
| `src/Weldone.Application.Contracts/Workflows/ScanWeldWorkflowData.cs` | AllTransitionLines / AddTransitionLine |
| `src/Weldone.Application/States/ModelBase/TransitionPlan.cs` | FSM 统一 TransitionPlan 节点 |
| `src/Weldone.Application/States/ModelBase/5.TransitionExecute.cs` | 过渡段执行节点 |
| `src/Weldone.Application/States/ModelBase/2.ForeachScanWeldExecute.cs` | 设置 ScanStart 目标 |
| `src/Weldone.Application/States/ModelBase/7.ForeachWeldMultiPass.cs` | 设置 ArcStart 目标 |
| `src/Weldone.Application/States/ModelBase/10.1CheckIfCleanGun.cs` | 清枪目标切换 |
| `src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSM.FSMScript` | FSM 图定义 |
| `src/Weldone.Domain/Cache/PoseRefJsonConverter.cs` | PoseRef JSON 序列化 |

## 9. 风险与注意事项

| 风险 | 说明 |
|---|---|
| PoseRef 相等性 | 结构体值比较，依赖 `SegmentId + Role + Tag` 三元组全等 |
| TransitionLine Id 碰撞 | MD5 计算理论上极低概率碰撞，实际可忽略 |
| 缓存一致性 | ActualPoses 缓存了 GetHomePose 结果，若 Home 位在运行中变化需注意 |
| 双臂外部轴 | 外部轴不同时强制走 EHome，直接跳过 P2 会导致路径错误 |
| 段间过渡容错 | `PlanScanSegmentTransitionsAsync` 失败段会被跳过，后续后处理 fallback 到 GroupMoveL |
