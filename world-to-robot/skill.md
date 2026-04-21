---
name: world-to-robot
description: 将双机焊接系统中世界坐标转换到机器人坐标系。输入世界坐标xyz、外部轴E1/E2、旋转轴ext3和臂别，输出机器人坐标。适用于：粗定位点云转换、路径规划坐标计算、离线编程目标点计算。
---

# World → Robot 坐标正向变换

## 背景

在双机焊接系统中，规划器输出世界坐标，但需要转换到机器人坐标系才能执行。本skill执行完整的正向变换，包括：

1. 减去线性补偿（修正外部轴系统偏差）
2. 执行正向变换（逆变换的反向操作）

## 变换公式

### 步骤1: 减去线性补偿

从实际世界坐标减去补偿量，得到"转换坐标系"坐标：

```
X_conv = X_world - ΔX
Y_conv = Y_world - ΔY
Z_conv = Z_world - ΔZ

其中：
ΔX = -2.054 * E1 - 0.066 * E2 + 1925.29
ΔY = -0.042 * E1 + 2.997 * E2 - 612.34
ΔZ = -0.0019 * E1 + 0.001 * E2 - 0.16
```

### 步骤2: 正向变换

执行逆变换的反向操作：

```
1. 反向平移:
   rx = X_conv - E1
   ry = Y_conv + E2
   rz = Z_conv

2. 绕 (600, 0) 旋转 -angle 度（反向旋转）:
   Robot A: angle = ext3 + 360（效果等同ext3）
   Robot B: angle = ext3 + 180

   dx = rx - 600
   robot_x = dx * cos(-angle) - ry * sin(-angle) + 600
   robot_y = dx * sin(-angle) + ry * cos(-angle)
   robot_z = rz

   简化（使用cos(-θ)=cos(θ), sin(-θ)=-sin(θ)）:
   robot_x = dx * cos(angle) + ry * sin(angle) + 600
   robot_y = -dx * sin(angle) + ry * cos(angle)
```

## 使用方式

### 方式1: 命令行调用

```bash
# 单个点
/world-to-robot --world-x 8717.46 --world-y -432.38 --world-z 1900.94 \
                --e1 -6000 --e2 0 --ext3 180 --arm A

# JSON格式批量
/world-to-robot --file input.json
```

JSON格式：
```json
[
  {
    "name": "P1",
    "world_x": 8717.46,
    "world_y": -432.38,
    "world_z": 1900.94,
    "e1": -6000,
    "e2": 0,
    "ext3": 180,
    "arm": "A"
  }
]
```

### 方式2: Claude内联计算

用户提供：世界坐标、外部轴、臂别

Claude直接计算并输出结果表格。

## 输入格式

用户通常提供：
- 世界坐标 X, Y, Z (mm)
- 外部轴 E1, E2 (mm)
- 旋转轴 ext3 (度)
- 臂别 (A 或 B)

## 输出格式

结果表格包含：
- 点名
- 世界坐标 (X, Y, Z)
- 外部轴 (E1, E2, ext3)
- 机器人坐标 (X, Y, Z)

## 精度说明

- 线性补偿精度：R² > 0.999
- 验证点数：18个实测点
- 最大误差：约30mm

## 注意事项

1. **Y轴镜像**：已隐含在线性补偿公式中，无需单独处理
2. **ext3默认值**：如果未提供ext3，默认使用180°
3. **臂别默认值**：如果未提供臂别，默认使用A臂

## 实现文件

- `scripts/convert.py` - Python转换脚本
- `scripts/test.py` - 测试脚本

## 验证数据

使用18个实测点验证，转换精度：
- X轴：R² = 0.9997
- Y轴：R² = 0.9990
- Z轴：R² = 0.927

---

**创建时间**: 2026-04-02
**适用场景**: 粗定位点云转换、路径规划、离线编程
**相关skill**: robot-to-world (逆变换)