---
name: weldone-wsg-merge-domain-knowledge
description: Weldone 项目 WeldSeamGroup 合并机制的领域知识库。涵盖双层表示设计（原始 WSG / 合并 WSG）、MergedSources 数据结构、MergeWsgs 合并规则、分段精定位映射、状态通知适配等。适用于分析 WSG 合并相关代码、排查对称打断场景焊接问题、理解双机多 WSG 执行流程。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# WeldSeamGroup 合并领域知识

## 1. 设计背景

FlexBeam 对称打断场景下，双机各需焊接多条 WSG。状态机 `WeldSeamPairContext` 原先硬编码 Robot0/Robot1 各一条，`GetDualArmWsgPair` 要求恰好 2 个。为支持 N:M 双机焊接，引入 **双层表示 + 合并 WSG** 方案。

### 核心约束
- 合并后模板只有一组起弧/收弧安全点
- 精定位映射必须分段计算（曲线+直线+曲线场景，全局 MapMatrix 精度不够）
- 前端零耦合（前端基于任意长度 GUID 列表）
- 状态机拓扑不改（仍以包角对为单位）

---

## 2. 双层表示

| 层级 | 位置 | 内容 | 消费者 |
|------|------|------|--------|
| **原始 WSG** | `wp.WeldSeamGroups` | 几何、扫描、CilIdx 映射 | VisionCaptureManager, CapturePointManager, MapMatrix |
| **合并 WSG** | `WrapPairsDict` / `WsgDicts` | 模板、焊接规划、执行 | WeldPlanAppService, WeldPoseSolverManager, WeldExecute |

**关键规则**：`wp.WeldSeamGroups` 始终保留原始 WSG，不被合并替换。合并 WSG 仅存在于工艺列表字典中。

通过 `MergedSources` 建立双向引用，信息零损失。

---

## 3. 数据结构

### 3.1 MergedWsgSource

**文件**: `src/Weldone.Domain/WeldProcedure/Procedure/Entities/WeldSeamGroup.cs`

```csharp
public class MergedWsgSource
{
    public Guid OriginalWsgId { get; init; }   // 原始 WSG Id
    public int CilIdx { get; init; }            // 原始 CilIdx（C++ 算法用的索引）
    public int Order { get; init; }             // 在合并路径中的顺序（0=最前）
    public int VertexOffset { get; init; }      // 该段在合并 WeldSeams 中的起始顶点索引
    public int VertexCount { get; init; }       // 该段的顶点数量
}
```

### 3.2 WeldSeamGroup.MergedSources

```csharp
// 非空 → 本 WSG 由多个原始 WSG 合并而成
// 为空/null → 本 WSG 是原始 WSG
public List<MergedWsgSource>? MergedSources { get; set; }
```

**判断是否合并 WSG**：`wsg.MergedSources != null && wsg.MergedSources.Count > 1`

### 3.3 WeldSeamExecutionContext.OriginalWsgIds

**文件**: `src/Weldone.Application.Contracts/Workflows/ScanWeldWorkflowData.cs`

```csharp
public List<Guid> OriginalWsgIds { get; set; } = new();
```

扫描阶段逐个处理原始 WSG，焊接阶段使用合并 WSG。为空时直接使用 `WsgId`。

---

## 4. MergeWsgs 合并规则

**方法签名**: `WeldSeamGroup.MergeWsgs(IReadOnlyList<WeldSeamGroup> ordered, Guid newId)`

| 属性 | 取值来源 |
|------|----------|
| Type / Direction / Position / Feature / Shape | 第一个 WSG |
| IsClosed | `false` |
| TemplateDimensionKey | 第一个 WSG |
| WeldLegHeight / BevelType / BevelHeight / BevelDepth / GapWidth / BluntEdgeLength | 第一个 WSG |
| IsDefaultOrientation / TrackingMode / IsTrackingModeCustomized | 第一个 WSG |
| StartEdgeInfo | 第一个 WSG 的 StartEdgeInfo |
| EndEdgeInfo | 最后一个 WSG 的 EndEdgeInfo |
| WeldSeams | 所有原始 WSG 的 WeldSeams 拼接（每条 deep clone，新 GUID） |
| CilIdx | 第一个 WSG 的 CilIdx（用于模板匹配和 PathItems 索引） |
| MergedSources | 各原始 WSG 的 Id/CilIdx/Order/VertexOffset/VertexCount |

**VertexOffset 计算方式**：累加前序 WSG 的 WeldSeamVertices 总数。

---

## 5. 合并时机与流程

**文件**: `src/Weldone.Domain/WorkpieceManager/FlexBeamWorkpieceManager.cs` — `GenerateCraftList()`

### 两个独立功能

| 功能 | 触发条件 | 操作 | 显示符号 |
|------|----------|------|----------|
| **组合包角** | 始终执行 | `GetWsgsWithWrappingInfo` → 筛选 Dominant → 存入 `WrapPairsDict` | `&`（如 `1_W1 & 2_W3`） |
| **合并焊缝** | `IsSymmetricSplited` | `MergeSameRobotWsgs` → 同机器人 WSG 合并 → 替换 `OrderedWeldSeamGroups` 中的 ID | `+`（如 `1_W1+3_W2`） |

### GenerateCraftList 流程

```
1. GetWsgsWithWrappingInfo → originList（包角配对）
2. 筛选 Dominant 条目 → dominantInfos（组合包角）
3. IsSymmetricSplited 时按 RobotIndex 排序
4. 存入 WrapPairsDict
5. IsSymmetricSplited 时调用 MergeSameRobotWsgs（合并焊缝，独立步骤）
6. 后续不变（诊断检查、ChangeCraftListWithSelected 等）
```

**不改 `wp.WeldSeamGroups`** — 原始 WSG 始终保留在这里。

### MergeSameRobotWsgs 方法

私有方法，按 `GetRobotIndex()` 分桶，对 2+ 条 WSG 调用 `MergeWsgs`。合并 WSG 注册到 `WsgDicts`，替换 `wrapInfo.OrderedWeldSeamGroups` 中的 ID。

---

## 6. 下游模块适配

### 6.1 不需要改的模块

| 模块 | 原因 |
|------|------|
| 前端所有组件 | 零耦合，基于任意长度 GUID 列表 + per-WSG 状态事件 |
| `VisionCaptureManager` | 从 `wp.WeldSeamGroups`（原始）构建 CilIdx→WSG 字典 |
| `CapturePointManager` | 扫描阶段收到的是原始 WSG |
| `WeldPoseSolverManager` | 基于合并 WSG 的 CilIdx 计算，自然适配 |
| `WeldPlanAppService` | 模板匹配循环遍历合并 WSG，每机一个模板 |
| `ForeachWeldMultiPass` | 遍历多道，不关心 WSG 合并 |
| `CheckScanState` | 基于 CrtCraftId |

### 6.2 需要适配的模块

| 模块 | 改动 |
|------|------|
| `GetDualArmWsgPair` | 放宽约束：按 RobotIndex 分桶，不再要求 ==2 |
| `ForeachScanWeldExecute` | 构建上下文时从 MergedSources 提取 OriginalWsgIds |
| `ForeachScanUnit` | 遍历 OriginalWsgIds 而非合并 WSG 的 GetWsgIds() |
| `ScanExecute` | PrepareScanData 收集所有原始 WSG ID |
| `WeldExecute` | 分段精定位映射（见下节） |
| 10 个状态通知节点 | 检查 MergedSources，为每个原始 WSG 发布状态事件 |

---

## 7. 分段精定位映射（Per-Segment MapMatrix）

**文件**: `src/Weldone.Application/States/ModelBase/10.WeldExecute.cs`

### 问题
曲线+直线+曲线路径，全局 MapMatrix（仅基于起末点计算）会导致中间直线段精度不足。

### 解决方案

```csharp
var mergedWsg = _solverContextRepository.WsgDicts[wsgId];
var sources = mergedWsg.MergedSources ?? [new MergedWsgSource { OriginalWsgId = wsgId }];

foreach (var src in sources)
{
    var (matrix, mmData) = await GetMapMatrixAsync(src.OriginalWsgId, token);
    mmDatas.Add(mmData);

    // 只对这一段的 TargetPoints 应用变换
    ApplyPrecisePositioningMatrixToSegment(currentItem, matrix, src.VertexOffset, src.VertexCount);
}
```

### ApplyPrecisePositioningMatrixToSegment

**文件**: `src/Weldone.Application/Welding/WeldRobotAppService.cs`

类似 `ApplyPrecisePositioningMatrix`，但只处理 `TargetPoints[vertexOffset..vertexOffset+vertexCount)`，并将该段的 `SeamTValues` 重新归一化到 [0,1]。

---

## 8. 状态通知适配

焊接完成 / 扫描完成时，需为每个原始 WSG 发布状态变更事件（保证前端进度正确）：

```csharp
if (mergedWsg.MergedSources is { Count: > 1 })
{
    foreach (var src in mergedWsg.MergedSources)
    {
        await localEventBus.PublishAsync(new WeldSeamGroupStatusChanged(
            orderId, src.OriginalWsgId, status));
    }
}
else
{
    await localEventBus.PublishAsync(new WeldSeamGroupStatusChanged(
        orderId, wsgId, status));
}
```

**涉及文件**（10 个节点）：
- `7.ForeachWeldMultiPass.cs`
- `10.WeldExecute.cs`, `10-2.RhWeldExecute.cs`
- `10.5RobotCleanGun.cs`, `10.9WeldUnrecognized.cs`
- `6.ScanExecute.cs`, `6-2.RhScanExecute.cs`
- `4.ScanTransitionPlan.cs`, `8.WeldTransitionPlan.cs`
- `Plan/ScanWeldPlanner.cs`

---

## 9. CilIdx 索引关系

```
原始 WSG: wp.WeldSeamGroups[0..N], 各有 CilIdx = C++ 算法的 CIL 索引
合并 WSG: CilIdx = 第一个原始 WSG 的 CilIdx
```

| 消费者 | 使用方式 |
|--------|----------|
| `WeldPoseSolverManager.CreateWeldPosParam` | `wsg.CilIdx` → 匹配模板 PathItems |
| `VisionCaptureManager` | 从原始 WSG 建 `CilIdx → WSG` 字典 |
| `WeldPlanAppService.PrepareTemplateForDualArm` | 遍历合并 WSG，用 CilIdx 索引模板 |

---

## 10. 包角与合并焊缝的关系（两个独立功能）

### 组合包角（`&`）

- 数据源：`WrapGuidPair` → `GetWsgsWithWrappingInfo` → graph 聚类
- 结果：`WsgsWithWrappingInfo` 的 Dominant/Recessive 对，存入 `WrapPairsDict`
- 前端显示：`1_W1 & 2_W3`（用 `&` 连接工艺名）
- `ChangeCraftListWithSelected` 切换包角状态时操作此层

### 合并焊缝（`+`）

- 数据源：`GetRobotIndex()` 分桶（同机器人的多条 WSG）
- 结果：调用 `MergeWsgs` 创建合并 WSG，注册到 `WsgDicts`，替换 `OrderedWeldSeamGroups` 中的 ID
- 前端显示：`1_W1+3_W2`（合并 WSG 的 Name，用 `+` 拼接原始名称）
- 仅在 `IsSymmetricSplited` 时触发，作为包角之后的独立后处理步骤

### 两者的关系

```
WrapGuidPair → 组合包角 → WrapPairsDict（Dominant 条目）
                              ↓
                  合并焊缝 → 替换 OrderedWeldSeamGroups 中同机器人的多条 ID 为合并 ID
```

两者顺序不可颠倒：先确定包角对，再在每个对内合并同机器人的 WSG。

---

## 11. 关键文件索引

| 文件 | 作用 |
|------|------|
| `src/Weldone.Domain/WeldProcedure/Procedure/Entities/WeldSeamGroup.cs` | MergedWsgSource 类、MergedSources 属性、MergeWsgs 方法 |
| `src/Weldone.Domain/WorkpieceManager/FlexBeamWorkpieceManager.cs` | GenerateCraftList（组合包角 + 合并焊缝）、MergeSameRobotWsgs |
| `src/Weldone.Application.Contracts/Workflows/ScanWeldWorkflowData.cs` | WeldSeamExecutionContext.OriginalWsgIds |
| `src/Weldone.Domain/Cache/SolverContextRepository.cs` | GetDualArmWsgPair、WsgDicts |
| `src/Weldone.Application/States/ModelBase/2.ForeachScanWeldExecute.cs` | 上下文构建，提取 OriginalWsgIds |
| `src/Weldone.Application/States/ModelBase/3.ForeachScanUnit.cs` | 扫描迭代适配 |
| `src/Weldone.Application/States/ModelBase/6.ScanExecute.cs` | 扫描数据准备适配 |
| `src/Weldone.Application/States/ModelBase/10.WeldExecute.cs` | 分段精定位映射 |
| `src/Weldone.Application/Welding/WeldRobotAppService.cs` | ApplyPrecisePositioningMatrixToSegment |

---

## 12. 常见陷阱

| 陷阱 | 说明 |
|------|------|
| 修改 `wp.WeldSeamGroups` | 原始 WSG 列表必须保持不动，否则 VisionCaptureManager 和扫描流程会出错 |
| 混用合并 WSG Id 和原始 WSG Id | 扫描阶段用原始 WSG Id（通过 OriginalWsgIds），焊接阶段用合并 WSG Id |
| 忘记为原始 WSG 发布状态事件 | 前端通过原始 WSG Id 跟踪进度，只发布合并 WSG 的事件会导致进度不更新 |
| 全局 MapMatrix 用于合并 WSG | 曲线+直线+曲线场景必须分段计算，否则中间段精度不足 |
| CilIdx 不匹配 | 合并 WSG 的 CilIdx 取自第一个原始 WSG，模板匹配和 PathItems 索引依赖此值 |
