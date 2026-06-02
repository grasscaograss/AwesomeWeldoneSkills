---
name: weld-seam-normal-vectors
description: >
  焊缝法向量（MasterPlateNormal / SidePlateNormal）的领域知识库。涵盖：
  (1) 焊接坐标系的构建原理（Z=主板法向, Y=子板法向修正, X=焊接方向）；
  (2) 法向量在焊前规划（WeldPoseSolver）和精定位（MapCalculator / VCM提取）中的完整调用链；
  (3) 平焊缝 Master/SidePlate 自动校正（swap）机制。
  当涉及以下代码修改时使用：WeldSeamVertex 的法向量赋值、WeldCoordinateUtils 坐标系变换、
  精定位 MapMatrix 校正、VCM 法向量提取、BuildWeld2Model、DoublePlateWeldPoseSolver、
  MasterPlate/SidePlate 分配逻辑、AssignWsgDirection、ParseIntermidiateILs。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# 焊缝法向量领域知识

## 核心概念

焊接坐标系由两个板面法向量 + 焊接方向定义：

```
Z 轴 = MasterPlateNormal  （主板法向量，应指向工作面外侧）
X 轴 = 焊接方向           （起点到终点）
Y 轴 = Cross(Z, X)        符号由 SidePlateNormal 修正，确保 Y 朝子板一侧
```

这个坐标系是焊枪姿态、多层多道偏移、精定位校正矩阵的基础。

## 数据结构

```
WeldSeamVertex
  ├── Point            (3D 位置)
  ├── MasterPlateNormal (主板法向量 → Z 轴)
  ├── SidePlateNormal   (子板法向量 → Y 轴方向修正)
  └── PointType

WeldSeam
  ├── MasterPlate  (WeldPlate: BodyIndex, PlateIndex, FaceIndex)
  ├── SidePlate    (WeldPlate?)
  └── WeldSeamVertices[]
```

## 法向量来源

### H-Beam / Flex-Beam（视觉模型工件）

C++ 算法解析 STEP/STL → 提取 `PlateFaceSetsInOneWp`（面片数据），`AssignWsgDirection` 从面片的 `OriIn3D` 矩阵第三行提取法向量，按 MasterPlate/SidePlate 的 (BodyIndex, PlateIndex, FaceIndex) 索引查表赋值。

### DoublePlate（重磅板）

解析计算：`MasterPlateNormal = plane.ZAxis`，`SidePlateNormal = 圆心到顶点方向`。

### C++ 层 Master/Side 分配（不可修改）

`ParseIntermidiateILs` 中硬编码：`BodyPlateFaceIdxs[0:2] → SidePlate`，`[3:5] → MasterPlate`。这个映射由 C++ 算法决定。

## 平焊缝 Master/SidePlate 自动校正（Swap）

### 背景

护圈等特殊工件中，C++ 分配的 MasterPlate 法向量与工作面垂直（非同向），而 SidePlateNormal 才与工作面同向。导致 Z 轴方向错误。

### 实现位置

`WorkpieceManagerBase.SwapMasterSidePlateForFlatWelds()` — 在 `AssignWsgDirection` 之后、数据写入 Workpiece 之前调用（仅 FlexBeam）。

### 判定条件

仅对 `Direction == Horizontal` 的焊缝组：
```
|SidePlateNormal · workFaceNormal| > |MasterPlateNormal · workFaceNormal|
```
取绝对值比较，因为法向量可能朝内或朝外。

### Swap 操作

同时交换 WeldPlate 对象和法向量：
```csharp
(ws.SidePlate, ws.MasterPlate) = (ws.MasterPlate, ws.SidePlate);
(vertex.SidePlateNormal, vertex.MasterPlateNormal) = (vertex.MasterPlateNormal, vertex.SidePlateNormal);
```

### 为什么源头 Swap 安全

所有下游通过 WeldPlate 的 (BodyIndex, PlateIndex, FaceIndex) 引用 MasterPlate。Swap 后索引互换，VCM 匹配等逻辑自动获取正确的平面。无需修改下游。

### 安全边界

- 仅影响平焊缝（Horizontal），立焊缝不触发
- 包角逻辑在 swap 之前已完成，不受影响
- `BuildWeld2ModelForV` 的隐式 swap 仅处理立焊缝，互不干扰
- `DoublePlateWeldPoseSolverManager` 的 `MasterPlateNormal * -1` 仅 DoublePlate 走此路径

## 关键调用链

详见 [references/call-chains.md](references/call-chains.md)

## 已有 Workaround（未移除）

| 位置 | 逻辑 | 适用范围 |
|------|------|---------|
| `WeldPoseSolverManager.BuildWeld2ModelForV` | 行列式 < 0 时 swap Master/Side 法向量 | 仅立焊缝 |
| `DoublePlateWeldPoseSolverManager` | `axisZ = MasterPlateNormal * -1` | 仅重磅板 |
