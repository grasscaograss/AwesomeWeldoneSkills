#!/usr/bin/env python3
"""
World → Robot 坐标正向变换

输入：世界坐标、外部轴E1/E2、旋转轴ext3、臂别
输出：机器人坐标
"""

import argparse
import json
import math
import sys


def world_to_robot(world_x, world_y, world_z, e1, e2, ext3=180, arm="A"):
    """
    World → Robot 坐标变换

    基于18个实测点拟合的线性公式（强制World坐标系数为1.0）：
    - Robot_X: R²=0.9995, Max Error: 5.4mm
    - Robot_Y: R²=0.99998, Max Error: 6.5mm
    - Robot_Z: R²=0.83, Max Error: 6.5mm
    - 平均总误差: ~5mm
    """
    # 拟合得到的线性公式（World坐标系数为1.0）
    robot_x = world_x + 0.999285 * e1 + 0.047826 * e2 - 2057.719
    robot_y = world_y + 0.044155 * e1 - 0.996269 * e2 + 533.752
    robot_z = world_z + 0.001865 * e1 - 0.000948 * e2 + 0.164

    return robot_x, robot_y, robot_z


def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="World → Robot 坐标正向变换"
    )

    # 单点转换参数
    parser.add_argument("--world-x", type=float, help="世界坐标 X (mm)")
    parser.add_argument("--world-y", type=float, help="世界坐标 Y (mm)")
    parser.add_argument("--world-z", type=float, help="世界坐标 Z (mm)")
    parser.add_argument("--e1", type=float, help="外部轴 E1 (mm)")
    parser.add_argument("--e2", type=float, help="外部轴 E2 (mm)")
    parser.add_argument("--ext3", type=float, default=180, help="旋转轴 ext3 (度)，默认180")
    parser.add_argument("--arm", type=str, default="A", choices=["A", "B"], help="臂别，默认A")

    # 批量转换参数
    parser.add_argument("--file", type=str, help="JSON输入文件")

    return parser.parse_args()


def convert_single(world_x, world_y, world_z, e1, e2, ext3, arm):
    """转换单个点"""
    robot_x, robot_y, robot_z = world_to_robot(
        world_x, world_y, world_z, e1, e2, ext3, arm
    )

    print(f"\n转换结果:")
    print(f"  世界坐标: ({world_x:.3f}, {world_y:.3f}, {world_z:.3f}) mm")
    print(f"  外部轴: E1={e1}, E2={e2}, ext3={ext3}°")
    print(f"  臂别: {arm}")
    print(f"  机器人坐标: ({robot_x:.3f}, {robot_y:.3f}, {robot_z:.3f}) mm")


def convert_batch(input_file):
    """批量转换"""
    with open(input_file, "r", encoding="utf-8") as f:
        points = json.load(f)

    print(f"\n批量转换 {len(points)} 个点:\n")
    print(f"{'点号':<8} {'世界坐标 (X, Y, Z)':<35} {'外部轴 (E1, E2, ext3)':<25} {'机器人坐标 (X, Y, Z)':<35}")
    print("-" * 110)

    for point in points:
        name = point.get("name", "?")
        world_x = point["world_x"]
        world_y = point["world_y"]
        world_z = point["world_z"]
        e1 = point["e1"]
        e2 = point["e2"]
        ext3 = point.get("ext3", 180)
        arm = point.get("arm", "A")

        robot_x, robot_y, robot_z = world_to_robot(
            world_x, world_y, world_z, e1, e2, ext3, arm
        )

        world_str = f"({world_x:.2f}, {world_y:.2f}, {world_z:.2f})"
        ext_str = f"({e1:.0f}, {e2:.0f}, {ext3}°)"
        robot_str = f"({robot_x:.3f}, {robot_y:.3f}, {robot_z:.3f})"

        print(f"{name:<8} {world_str:<35} {ext_str:<25} {robot_str:<35}")


def main():
    args = parse_args()

    if args.file:
        # 批量转换
        convert_batch(args.file)
    elif all([args.world_x is not None, args.world_y is not None,
              args.world_z is not None, args.e1 is not None, args.e2 is not None]):
        # 单点转换
        convert_single(args.world_x, args.world_y, args.world_z,
                      args.e1, args.e2, args.ext3, args.arm)
    else:
        print("错误: 请提供 --file 或所有坐标参数 (--world-x, --world-y, --world-z, --e1, --e2)")
        sys.exit(1)


if __name__ == "__main__":
    main()