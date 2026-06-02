---
name: three-blazor-dev
description: 使用 three-blazor 进行 3D 场景开发的指导，包括场景初始化、模型加载、几何绘制、动画播放和交互控制
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Three-Blazor 3D 场景开发指南

## 核心概念

three-blazor (`@robim/three-blazor`) 是基于 Three.js 的高级封装库，专为工业仿真和焊接可视化设计。

## 文档参考

详细 API 文档请参考: `docs/libraries/three-blazor.md`

## 项目中的使用入口

- TypeScript 入口: `src/Weldone/Assets/ts/three-blazor.ts`
- Blazor 组件: `src/Weldone/Components/ThreeDisplay.razor`

## 初始化 3D 场景

### Blazor 组件方式

```razor
<ThreeDisplay @ref="_threeDisplay"
              Id="my-scene"
              ShowAxes="true"
              ShowGrid="true" />
```

```csharp
@code {
    private ThreeDisplay? _threeDisplay;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender && _threeDisplay?.Core != null)
        {
            // 使用 Core 进行 3D 操作
            await _threeDisplay.Core.LoadSTLAsync("/models/part.stl", "part", true);
        }
    }
}
```

### TypeScript 方式

```typescript
import { ThreeCore } from '@robim/three-blazor';

const core = new ThreeCore(
    'container-id',  // DOM 容器 ID
    true,            // 显示坐标轴
    true,            // 显示网格
    true,            // 启用后处理
    false,           // CSS2D 渲染器
    false            // CSS3D 渲染器
);
```

## 常用操作

### 加载模型

```typescript
// STL 文件
await core.LoadSTLAsync('/models/workpiece.stl', 'workpiece-key', true);

// URDF 机器人
await core.LoadURDFAsync('/robots/robot.urdf');

// 从 Base64
await core.LoadSTLFromBytesAsync(base64Data, 'model-key', true);
```

### 几何图形绘制

```typescript
// 直线
core.AddLine('line-1', 'group', [0,0,0], [100,0,0], 0xff0000, 2);

// 圆弧 (起点, 中点, 终点)
core.AddArc('arc-1', 'group', [0,0,0], [50,50,0], [100,0,0], 0x00ff00, 2);

// 圆形
core.AddCircle('circle-1', 'group', 50, [0,0,0], [0,0,1], 0x0000ff, 2);
```

### 圆弧曲线计算

```typescript
import { ArcCurve3 } from '@robim/three-blazor';
import * as THREE from 'three';

// 通过三点创建圆弧曲线
const arc = ArcCurve3.createFromThreePoint(
    new THREE.Vector3(0, 0, 0),
    new THREE.Vector3(50, 50, 0),
    new THREE.Vector3(100, 0, 0)
);

// 获取插值点
const points = arc.getPoints(30);
```

### 相机控制

```typescript
// 适配到对象
await core.FitCameraToObject('model-key', 1.5);

// 适配到场景
await core.FitCameraToScene(1.2);

// 切换相机类型
core.SwitchToPerspectiveCamera();
core.SwitchToOrthographicCamera();
```

### 动画播放

```typescript
// 创建播放器
const totalFrames = await core.CreatePlayer(
    processData,
    (frame) => console.log('Frame:', frame),
    () => console.log('Animation ended')
);

// 控制
await core.PlayerStart();
await core.PlayerPause();
await core.SetSpeed(2.0);
await core.MoveTo(100);
```

### 交互功能

```typescript
// 对象选择监听
core.RegistrySelectObjectListener([1, 2], (obj) => {
    console.log('Selected:', obj);
});

// 框选
core.EnableBoxSelection(
    (objects) => console.log('Box selected:', objects),
    () => console.log('Cancelled'),
    [1, 2]
);

// 变换控制
core.AttachTranformControlsToObj('object-key', (matrix) => {
    console.log('Transform changed:', matrix);
});
```

### 机器人控制

```typescript
// 设置单个关节
core.SetJointValue('joint1', Math.PI / 2);

// 批量设置
core.SetJointValues([0, 0.5, 1.0, -0.5, 0.3, 0]);
```

## 项目中的参考实现

| 文件 | 功能 |
|------|------|
| `Assets/ts/WeldSeamGroup.ts` | 焊缝组 3D 模型构建 |
| `Assets/ts/WeldBeadHelper.ts` | 焊珠可视化辅助 |
| `Assets/ts/pathSimulation.ts` | 路径仿真动画 |
| `Assets/ts/production.ts` | 生产场景管理 |

## 资源清理

```typescript
// 移除单个对象
core.RemoveObjByKey('object-key');

// 清空场景
core.Clear();

// 销毁实例
core.Dispose();
```

## 注意事项

1. ThreeCore 实例与 DOM 容器绑定，确保容器在初始化前已存在
2. 使用 `fit` 参数自动调整相机视角
3. 使用 `key` 参数标识对象，便于后续操作
4. 使用 `groupName` 参数组织对象层级
5. 记得在组件销毁时调用 `Dispose()` 释放资源
