#!/usr/bin/env python3
"""双机焊接系统：机器人坐标 -> 世界坐标 逆变换工具

用法:
  # 单组外部轴，多个点
  python convert.py --arm A --ext "2799.992,1599.986,44.372" \
      --points "605.031,-113.480,1889.974" "646.348,787.098,1883.850"

  # 从 JSON 文件读取（格式见下方）
  python convert.py --file input.json

JSON 格式:
  [
    {"name": "P1", "x": 605.031, "y": -113.480, "z": 1889.974,
     "ext1": 2799.992, "ext2": 1599.986, "ext3": 44.372, "arm": "A"}
  ]
"""

import math
import argparse
import json
import sys


def robot_to_world(x, y, z, ext1, ext2, ext3, arm='A'):
    """将机器人坐标逆变换到世界坐标。

    正向变换 (ApplyExternalAxisTransform):
      1. 平移 (-ext1, +ext2, 0)
      2. 绕 (600, 0) 旋转 angle 度
         Robot A: angle = -(ext3 + 360)
         Robot B: angle = -(ext3 + 180)

    逆变换:
      1. 绕 (600, 0) 旋转 +angle 度（取正）
      2. 平移 (+ext1, -ext2, 0)
    """
    arm = arm.upper()
    if arm == 'A':
        angle_deg = ext3 + 360
    elif arm == 'B':
        angle_deg = ext3 + 180
    else:
        raise ValueError(f"arm must be 'A' or 'B', got '{arm}'")

    angle_rad = math.radians(angle_deg)
    cos_r = math.cos(angle_rad)
    sin_r = math.sin(angle_rad)

    # 绕 (600, 0) 旋转
    dx = x - 600.0
    rx = dx * cos_r - y * sin_r + 600.0
    ry = dx * sin_r + y * cos_r

    # 平移
    wx = rx + ext1
    wy = ry - ext2
    wz = z

    return wx, wy, wz


def parse_point(s):
    parts = [float(v.strip()) for v in s.split(',')]
    if len(parts) != 3:
        raise ValueError(f"点格式应为 'x,y,z'，得到: {s}")
    return parts


def parse_ext(s):
    parts = [float(v.strip()) for v in s.split(',')]
    if len(parts) != 3:
        raise ValueError(f"外部轴格式应为 'ext1,ext2,ext3'，得到: {s}")
    return parts


def print_table(results):
    print()
    print('| 点 | 机器人坐标 (X, Y, Z) | 外部轴 (E1, E2, R°) | 世界坐标 (X, Y, Z) |')
    print('|---|---|---|---|')
    for r in results:
        name = r['name']
        rx, ry, rz = r['robot']
        e1, e2, e3 = r['ext']
        wx, wy, wz = r['world']
        robot_str = f'({rx:.3f}, {ry:.3f}, {rz:.3f})'
        ext_str = f'{e1} / {e2} / {e3}°'
        world_str = f'({wx:.3f}, {wy:.3f}, {wz:.3f})'
        print(f'| {name} | {robot_str} | {ext_str} | {world_str} |')
    print()


def main():
    parser = argparse.ArgumentParser(description='机器人坐标 -> 世界坐标 逆变换')
    parser.add_argument('--arm', default='A', choices=['A', 'B', 'a', 'b'],
                        help='机器人臂别 A 或 B（默认 A）')
    parser.add_argument('--ext', help='外部轴 "ext1,ext2,ext3"')
    parser.add_argument('--points', nargs='+', help='机器人坐标点列表 "x,y,z" ...')
    parser.add_argument('--file', help='JSON 输入文件')
    args = parser.parse_args()

    results = []

    if args.file:
        with open(args.file, encoding='utf-8') as f:
            data = json.load(f)
        for i, item in enumerate(data):
            name = item.get('name', f'P{i+1}')
            arm = item.get('arm', 'A')
            x, y, z = item['x'], item['y'], item['z']
            e1, e2, e3 = item['ext1'], item['ext2'], item['ext3']
            wx, wy, wz = robot_to_world(x, y, z, e1, e2, e3, arm)
            results.append({'name': name, 'robot': (x, y, z), 'ext': (e1, e2, e3), 'world': (wx, wy, wz)})
    elif args.ext and args.points:
        e1, e2, e3 = parse_ext(args.ext)
        for i, pt in enumerate(args.points):
            x, y, z = parse_point(pt)
            wx, wy, wz = robot_to_world(x, y, z, e1, e2, e3, args.arm)
            results.append({'name': f'P{i+1}', 'robot': (x, y, z), 'ext': (e1, e2, e3), 'world': (wx, wy, wz)})
    else:
        parser.print_help()
        sys.exit(1)

    print_table(results)


if __name__ == '__main__':
    main()
