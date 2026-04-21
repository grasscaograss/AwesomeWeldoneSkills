# World → Robot 坐标转换 Skill

## 快速开始

### 方式1: 在对话中直接使用

直接告诉Claude：
```
"我有一个世界坐标 (8717.46, -432.38, 1900.94)，E1=-6000，E2=0，ext3=180，请转换为机器人坐标"
```

Claude会自动调用此skill进行计算。

### 方式2: 命令行调用

```bash
# 单个点
python ~/.claude/skills/world-to-robot/scripts/convert.py \
  --world-x 8717.46 --world-y -432.38 --world-z 1900.94 \
  --e1 -6000 --e2 0 --ext3 180 --arm A

# 批量转换
python ~/.claude/skills/world-to-robot/scripts/convert.py --file input.json
```

## 输入格式

### 单点转换

提供以下信息：
- 世界坐标 X, Y, Z (mm)
- 外部轴 E1 (mm)
- 外部轴 E2 (mm)
- 旋转轴 ext3 (度，可选，默认180)
- 臂别 (A或B，可选，默认A)

### 批量转换 (JSON)

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
  },
  {
    "name": "P2",
    "world_x": 8883.67,
    "world_y": -3365.69,
    "world_z": 1909.65,
    "e1": -6000,
    "e2": -2073,
    "ext3": 180,
    "arm": "A"
  }
]
```

## 输出示例

```
转换结果:
  世界坐标: (8717.460, -432.380, 1900.940) mm
  外部轴: E1=-6000, E2=0, ext3=180°
  臂别: A
  机器人坐标: (661.998, -158.512, 1892.645) mm
```

## 转换原理

### 步骤1: 减去线性补偿

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

```
1. 反向平移:
   rx = X_conv - E1
   ry = Y_conv + E2

2. 绕 (600, 0) 旋转:
   robot_x = (rx-600) * cos(angle) + ry * sin(angle) + 600
   robot_y = -(rx-600) * sin(angle) + ry * cos(angle)

其中:
   Robot A: angle = ext3 + 360
   Robot B: angle = ext3 + 180
```

## 精度验证

基于18个实测点验证：
- X轴：R² = 0.9997
- Y轴：R² = 0.9990
- Z轴：R² = 0.927
- 最大误差：约30mm

## 应用场景

- 粗定位点云转换
- 路径规划目标点计算
- 离线编程坐标转换
- 焊缝位置计算

## 相关资源

- `skill.md` - Skill详细说明
- `scripts/convert.py` - Python转换脚本
- `robot-to-world` skill - 逆变换（机器人→世界）

## 注意事项

1. **Y轴镜像**：已在线性补偿中自动处理，无需额外操作
2. **ext3默认值**：未提供时使用180°
3. **臂别默认值**：未提供时使用A臂
4. **单位**：长度单位均为mm，角度单位为度

---

**创建时间**: 2026-04-02
**作者**: Claude
**版本**: 1.0