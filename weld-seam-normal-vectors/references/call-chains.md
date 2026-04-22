# 法向量关键调用链

## 目录
1. [焊前规划：焊接姿态生成](#1-焊前规划焊接姿态生成)
2. [精定位：扫描 → VCM → MapMatrix → 逐点校正](#2-精定位扫描--vcm--mapmatrix--逐点校正)
3. [法向量赋值源头](#3-法向量赋值源头)
4. [VCM 法向量提取](#4-vcm-法向量提取)

---

## 1. 焊前规划：焊接姿态生成

```
FlexBeamWorkpieceManager.GenerateWeldPathsAsync()
  → AssignWsgDirection()           // 从面片数据赋值 MasterPlateNormal/SidePlateNormal
  → SwapMasterSidePlateForFlatWelds()  // 平焊缝自动校正（仅 FlexBeam）
  → ...
  → WeldPoseSolverManager.CalculateWeldToolPoses()
      → BuildWeld2Model(wsg)
          baseNormalVector = wsg.WeldSeams.First().WeldSeamVertices.First().MasterPlateNormal
          sideNormalVector = wsg.WeldSeams.First().WeldSeamVertices.First().SidePlateNormal
          weld2Model = WeldCoordinateUtils.GetTransformFromWeldToModel(
              baseNormalVector, sideNormalVector, weldVector)
          // Z = MasterPlateNormal, X = weldVector, Y = Cross(Z,X) 符号由 SidePlateNormal 修正
      → CreateWeldSinglePassPose(wsg, ..., weld2Model)
          → CreateWeldPose(..., weld2Model)
              → WeldCoordinateUtils.OffsetInWeldCoordinate(offset, model2Weld)
              → GetMatrixByAngles(refPosition + weldOffset, calcAngles, ws, ...)
```

### 关键文件
- `src/Weldone.Domain/WorkpieceManager/FlexBeamWorkpieceManager.cs` — GenerateWeldPathsAsync
- `src/Weldone.Domain/WorkpieceManager/WorkpieceManagerBase.cs` — AssignWsgDirection, SwapMasterSidePlateForFlatWelds
- `src/Weldone.Domain/Welding/ToolPlanning/WeldPoseSolverManager.cs:496-552` — BuildWeld2Model / BuildWeld2ModelForV
- `src/Weldone.Domain/Welding/ToolPlanning/WeldCoordinateUtils.cs:293-315` — GetTransformFromWeldToModel

### 立焊缝隐式 Swap（BuildWeld2ModelForV, 行 544-551）
```csharp
if (weld2Model.GetDeterminant() < 0)
{
    weld2Model = WeldCoordinateUtils
        .GetTransformFromWeldToModel(sideNormalVector, baseNormalVector, weldVector);
    // 注意：这里把 side 和 base 互换了
}
```

---

## 2. 精定位：扫描 → VCM → MapMatrix → 逐点校正

```
ScanExecute (状态机节点 6)
  → ProcessCapturePoint → DualArmPrecisePositioningAppService.SetCapturePointAsync
  → 英莱激光相机推扫 → StopScanAndRecogAsync (识别 VCM)

WeldExecute (状态机节点 10)
  → GetMapMatrixAsync(wsgId)
      → CapturePointManager.GetMapCalculatorAsync()
          → DetermineMasterAndSideNormals(wsg, newVcm, 0)  // 起点：从 VCM 提取新法向量
          → DetermineMasterAndSideNormals(wsg, newVcm, 1)  // 终点
          → DetermineMasterAndSideNormals(wsg, oldVcm, 0)  // 起点：旧法向量（模型）
          → DetermineMasterAndSideNormals(wsg, oldVcm, 1)  // 终点
          → MapCalculator(stMasterNormal, stSideNormal, stPoint,
                          edMasterNormal, edSideNormal, edPoint,
                          oldStMasterNormal, oldStSideNormal, oldStPoint,
                          oldEdMasterNormal, oldEdSideNormal, oldEdPoint)
              // BuildMatrix: Z = masterNormal, Y = sideNormal, X = weldVector
              // _startTransfer = inv(oldStMat) * newStMat
              // _endTransfer = inv(oldEdMat) * newEdMat
  → ApplyPrecisePositioningMatrix()
      → 对每个焊接点: calculator.CalcBy(pose, t)
          // 四元数 nlerp 插值姿态 + 线性插值位置
          // t 为焊缝上的归一化位置 [0,1]
```

### MapCalculator.BuildMatrix（行 48-59）
```csharp
var yn = Vector3.Normalize(sideNormal);    // Y = 子板法向
var zn = Vector3.Normalize(masterNormal);  // Z = 主板法向
var xn = Vector3.Normalize(weldVector);    // X = 焊接方向
// 构建 4x4 矩阵 [x, y, z 列]
```

### MapCalculator.CalcBy（行 61-83）— 逐点校正
```csharp
var poseSt = pose.TransferPose(_startTransfer);  // 起点校正
var poseEd = pose.TransferPose(_endTransfer);    // 终点校正
var rotation = Quaternion.Lerp(qSt, qEd, (float)t);    // 姿态插值
var pos = Vector3.Lerp(poseSt.Translation, poseEd.Translation, (float)t);  // 位置插值
```

### 关键文件
- `src/Weldone.Application/States/ModelBase/6.ScanExecute.cs:82-173`
- `src/Weldone.Application/States/ModelBase/10.WeldExecute.cs:97-127`
- `src/Weldone.Application/Scanning/CapturePointManager.cs:397-653` — GetMapCalculatorAsync, DetermineMasterAndSideNormals
- `src/Weldone.Application/Scanning/MapMatrix/MapCalculator.cs:22-83` — BuildMatrix, CalcBy
- `src/Weldone.Application/Scanning/DualArmPrecisePositioningAppService.cs:217`
- `src/Weldone.Application/Welding/WeldRobotAppService.cs:1345` — ApplyPrecisePositioningMatrix

---

## 3. 法向量赋值源头

### ParseIntermidiateILs（WorkpieceManagerBase.cs:889-931）

C++ 算法输出 IL 的 BodyPlateFaceIdxs，硬编码映射：
```csharp
SidePlate  = new WeldPlate(il.BodyPlateFaceIdxs[0], il.BodyPlateFaceIdxs[1], il.BodyPlateFaceIdxs[2], ...)
MasterPlate = new WeldPlate(il.BodyPlateFaceIdxs[3], il.BodyPlateFaceIdxs[4], il.BodyPlateFaceIdxs[5], ...)
```

### AssignWsgDirection（WorkpieceManagerBase.cs:807-845）

从 PlateFaceSetsInOneWp 的 Face.OriIn3D 矩阵第三行提取法向量：
```csharp
var masterIdx = (ws.MasterPlate.BodyIndex, ws.MasterPlate.PlateIndex, ws.MasterPlate.FaceIndex);
var sideIdx = (ws.SidePlate.BodyIndex, ws.SidePlate.PlateIndex, ws.SidePlate.FaceIndex);
// masterVec = face.OriIn3D 的 (M31, M32, M33)
vertex.MasterPlateNormal = masterVec;
vertex.SidePlateNormal = sideVec;
```

### SwapMasterSidePlateForFlatWelds（WorkpieceManagerBase.cs:844+）

在 AssignWsgDirection 之后，对平焊缝检测并 swap：
```csharp
if (wsg.Direction != WeldSeamDirectionType.Horizontal) continue;
var workFaceNormal = new Vector(orientArr[6], orientArr[7], orientArr[8]); // 工作面法向量
var masterDot = Math.Abs(Vector.Dot(firstVertex.MasterPlateNormal, workFaceNormal));
var sideDot = Math.Abs(Vector.Dot(firstVertex.SidePlateNormal, workFaceNormal));
if (sideDot <= masterDot) continue;  // 主板法向量已经更对齐，不 swap
// swap WeldPlate 对象和法向量
```

### 关键文件
- `src/Weldone.Domain/WorkpieceManager/WorkpieceManagerBase.cs:399-406` — ParseWeldSeamGroups 赋值
- `src/Weldone.Domain/WorkpieceManager/WorkpieceManagerBase.cs:807-845` — AssignWsgDirection
- `src/Weldone.Domain/WorkpieceManager/WorkpieceManagerBase.cs:844+` — SwapMasterSidePlateForFlatWelds
- `src/Weldone.Domain/WeldProcedure/Procedure/Entities/WeldSeamVertex.cs:30,35` — MasterPlateNormal/SidePlateNormal 字段

---

## 4. VCM 法向量提取

### DetermineMasterAndSideNormals（CapturePointManager.cs:622-653）

VCM.Planes 数组包含两个平面的法向量：`Planes[0:3]` 和 `Planes[4:7]`。通过比较 VCM 中的板索引与 WeldSeam.MasterPlate 决定哪个是主板：

```csharp
var (p1, _) = GetVcmInfo(wsg, idxInWsg);
if (IsEqualTo(p1, wsg.WeldSeams.First().MasterPlate))
    return (new Vector3(newVcm.Planes[0], newVcm.Planes[1], newVcm.Planes[2]),  // 主板
            new Vector3(newVcm.Planes[4], newVcm.Planes[5], newVcm.Planes[6])); // 子板
else
    return (new Vector3(newVcm.Planes[4], ...), new Vector3(newVcm.Planes[0], ...)); // 反过来
```

**关键**：IsEqualTo 比较 (BodyIndex, PlateIndex, FaceIndex)。Swap 后 MasterPlate 索引改变了，所以 VCM 提取会自动对齐到 swap 后的板，无需额外处理。

### 旧版精定位（PrecisePositioningManager.cs:60-136）

单机流程中同理：通过 MasterPlate/SidePlate 索引匹配 VCM 平面，提取 masterVectors/sideVectors 后构建坐标系。

### 关键文件
- `src/Weldone.Application/Scanning/CapturePointManager.cs:622-653` — DetermineMasterAndSideNormals
- `src/Weldone.Application/Scanning/CapturePointManager.cs:641-654` — DetermineMasterAndSidePlanes
- `src/Weldone.Domain/Scanning/PrecisePositioning/PrecisePositioningManager.cs:60-136`
- `src/Weldone.Application/Scanning/CapturePointManager.cs:572-591` — GetRecordedNormal
- `src/Weldone.Application/Scanning/CapturePointManager.cs:747-760` — SetRecordPoseNormal
