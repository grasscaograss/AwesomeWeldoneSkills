---
name: robot-to-world
description: 将双机焊接系统中机器人坐标（含外部轴）逆变换到世界坐标系。当用户提供机器人坐标、外部轴值（E1/E2/旋转角）及机器人臂别（A/B）时使用此 skill。
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Robot → World 坐标逆变换

## 背景

双机焊接系统中，规划器以世界坐标输出目标点，后处理阶段通过 `ApplyExternalAxisTransform` 将其转换到机器人坐标系（因旋转轴未与机器人耦合）。本 skill 执行该变换的逆运算。

## 正向变换（World → Robot）

```
1. 平移: P' = P + (-ext1, +ext2, 0)
2. 绕 (600, 0) 旋转 angle 度:
   Robot A: angle = -(ext3 + 360)°
   Robot B: angle = -(ext3 + 180)°
```

## 逆变换公式（Robot → World）

```
1. 绕 (600, 0) 旋转 +angle 度（取正角）:
   angle_A = ext3 + 360   （效果等同 ext3）
   angle_B = ext3 + 180
   dx = x - 600
   rx = dx * cos(angle) - y * sin(angle) + 600
   ry = dx * sin(angle) + y * cos(angle)
2. 平移: world_x = rx + ext1,  world_y = ry - ext2,  world_z = z
```

Z 轴不参与变换。

## 使用方式

### 直接计算（Claude 内联）

用户给出若干点（格式：`X, Y, Z / E1 / E2 / 旋转角`）和臂别，Claude 直接调用 Python 计算并输出结果表格。

### 脚本方式

```bash
# 单组外部轴，多个点
python ~/.claude/skills/robot-to-world/scripts/convert.py \
  --arm A \
  --ext "2799.992,1599.986,44.372" \
  --points "605.031,-113.480,1889.974" "646.348,787.098,1883.850"

# 从 JSON 文件批量转换
python ~/.claude/skills/robot-to-world/scripts/convert.py --file input.json
```

JSON 格式：
```json
[
  {"name": "P1", "x": 605.031, "y": -113.480, "z": 1889.974,
   "ext1": 2799.992, "ext2": 1599.986, "ext3": 44.372, "arm": "A"}
]
```

## 输入格式约定

用户通常粘贴如下格式：
```
X: 605.031, Y: -113.480, Z: 1889.974
2799.992 / 1599.986
44.372
```
解析规则：第一行 XYZ，第二行 E1 / E2，第三行旋转角（ext3）。
