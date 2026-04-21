---
name: weldone-mapmatrix-domain-knowledge
description: Weldone 项目 MapMatrix 扫描校准模块的领域知识库。涵盖 Calculator 策略矩阵、Break 端点处理、通长焊缝打断机制、peer 关联推算等核心概念。适用于分析 MapMatrix 相关代码、排查扫描校准问题、理解焊缝端点策略选择。
---

# Weldone MapMatrix 领域知识

## 1. 策略矩阵速查

`MapCalculatableFactory.Create(stIsBreak, edIsBreak, peerStIsBreak, peerEdIsBreak)` 的选择规则：

| 本侧 stBreak | 本侧 edBreak | 对侧状态 | Calculator |
|---|---|---|---|
| false | false | * | `BothVisionedCalculator` |
| true | true | * | `BothRobotRecordCalculator` |
| true | false | peer (false, false) | `StartBreakFullPeerCalculator` |
| true | false | peer (true, false) | `StartBreakPeerStVisionCalculator` |
| true | false | peer (false, true) | `StartBreakPeerEdVisionCalculator` |
| true | false | peer (true, true) | `StartBreakNoPeerCalculator` |
| false | true | peer (false, false) | `EndBreakFullPeerCalculator` |
| false | true | peer (true, false) | `EndBreakPeerStVisionCalculator` |
| false | true | peer (false, true) | `EndBreakPeerEdVisionCalculator` |
| false | true | peer (true, true) | `EndBreakNoPeerCalculator` |

**命名对照**：
- `FullPeer` = 对侧两端都是 Vision（无 Break）
- `PeerStVision` = 对侧起点是 Break、终点是 Vision（`peerStIsBreak=true, peerEdIsBreak=false`）
- `PeerEdVision` = 对侧起点是 Vision、终点是 Break（`peerStIsBreak=false, peerEdIsBreak=true`）
- `NoPeer` = 对侧两端都是 Break，强调"对侧无可用的 VCM 参考"

## 2. 核心分化原理

### 何时用 `CorrelatedPointBuilder`，何时用焊缝长度推算？

**`FullPeer`（对侧全 Vision）→ `CorrelatedPointBuilder.TryBuild`**

- `CorrelatedPointBuilder.TryBuild` 依赖对侧 peer 的**实测 VCM 点距** `peerLength`
- 只有对侧两端 VCM 都可靠时，`peerLength` 才准确
- 因此仅 `FullPeer` 场景继续使用它

**`PeerVision` / `NoPeer`（对侧至少一端 Break）→ 焊缝长度推算**

```csharp
// StartBreak 系列（终点可靠，反推起点）
var length = (float)data.Wsg.Length;   // 模型焊缝长度
Vector3 stPt = Vector3.Dot(oldVcmVector, direction) > 0
    ? edPt - length * direction
    : edPt + length * direction;

// EndBreak 系列（起点可靠，正推终点）
Vector3 edPt = Vector3.Dot(oldVcmVector, direction) > 0
    ? stPt + length * direction
    : stPt - length * direction;
```

- 对侧有 Break 端点时，peer VCM 实测数据不可靠
- 改用**模型定义的焊缝长度** + **焊缝方向**做几何推算
- 避免被不准确的 peer VCM 点距误导

**一句话总结**：对侧全 Vision 时用 peer 实测点距；对侧有 Break 时用模型长度 + 方向向量。

## 3. Break 端点处理机制

### 3.1 `_recordedPoseDict` 与 `ILIdx`

- `_recordedPoseDict` 的 key 是 `ILIdx`（焊缝索引 + 顶点索引）
- `ILIdx` 是值相等的 record：`public record ILIdx(int IlIdx, int IdxInIL)`
- `IdxInIL` 从 `cil.EndPointIdxsInIL` 取，是**全局索引**（跨焊缝共享）

### 3.2 相邻焊缝共享端点

打断后的相邻段在共享物理端点处使用**完全相同的 `ILIdx`**：

```
IL points: [P0, P1, P2, P3]
段 0: start=0, end=2  → 终点 ILIdx = (ilIdx=X, idxInIL=2)
段 1: start=2, end=3  → 起点 ILIdx = (ilIdx=X, idxInIL=2)
```

因此：
- 焊缝 A 的终点 robot record 被 `_recordedPoseDict[ILIdx(X,2)]` 写入
- 焊缝 B 的起点查询 `_recordedPoseDict[ILIdx(X,2)]` **命中同一条记录**
- 这是打断焊缝衔接处复用位姿信息的设计意图

### 3.3 `BothRobotRecordCalculator` 的取点流程

```csharp
var (found, masterNormal, sideNormal) = ops.GetRecordedNormal(data.Wsg, 0);
```

| 步骤 | 逻辑 |
|---|---|
| 起点法向量 | Break 点 → 查 `_recordedPoseDict[capturePointInfo.ILIdx]` |
| 终点法向量 | `edMn = stMn; edSn = stSn`（复用起点法向量）|
| 位置 | `CorrelatedPointBuilder.TryBuild(data)` 尝试 peer 推算 |
| 回退 | `builtSt ?? data.St.CorrelatedPoint` / `builtEd ?? data.Ed.CorrelatedPoint` |

## 4. 通长焊缝打断规则

| 问题 | 结论 |
|---|---|
| 相邻段是否共享端点对象？ | **否**。每段是独立的 `WeldSeamGroup`（有自己的 GUID 和顶点实例） |
| 相邻段是否共享位置数据？ | **是**。通过相同的 `ILIdx` 在 `_recordedPoseDict` 中共享 robot record |
| 段序是否影响机器人分配？ | **否**。机器人由 `WsgOrientation` + `IsDefaultOrientation` 决定，与段序无关 |
| 打断后是否交换机器人？ | **否**。同一条通长焊缝的所有段方向属性一致，保持同一机器人 |

## 5. 风险清单

| 风险 | 说明 |
|---|---|
| `CorrelatedPoint` 始终为 `null` | `MapMatrixData` 构造时 `CorrelatedPoint` 参数未传入，默认为 `null` |
| `BothRobotRecord` 对 `CorrelatedPointBuilder` 强依赖 | 若 `TryBuild` 失败，回退到 `null!.Value` 会抛 `NullReferenceException` |
| `StartBreak/EndBreak` 的 `PeerVision` 系列 Calculator 实现重复 | 4 个 Calculator（PeerStVision/PeerEdVision/NoPeer × Start/End）内部逻辑几乎完全相同，仅注释不同，未来应考虑抽象 |

## 6. 关键文件索引

| 文件 | 作用 |
|---|---|
| `src/Weldone.Application/Scanning/MapMatrix/MapCalculatableFactory.cs` | 策略工厂 |
| `src/Weldone.Application/Scanning/MapMatrix/Correlation/CorrelatedPointBuilder.cs` | 关联推算工具 |
| `src/Weldone.Application/Scanning/CapturePointManager.cs` | VCM 管理、robot record 存取 |
| `src/Weldone.Application.Contracts/Scanning/MapMatrix/MapMatrixData.cs` | 数据类型定义 |
| `src/Weldone.Application/Scanning/MapMatrix/Calculators/*.cs` | 各策略 Calculator 实现 |
