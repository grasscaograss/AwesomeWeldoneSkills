#!/usr/bin/env python3
"""
测试 World → Robot 转换的正确性
使用已知的18个点进行验证
"""

import json
import sys
import os

# 添加scripts目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'scripts'))

from convert import world_to_robot


def test_conversion():
    """使用实测数据验证转换正确性"""

    # 测试数据：已知的机器人坐标和世界坐标对应关系
    test_data = [
        {
            "name": "P18",
            "world_x": 8717.459961, "world_y": -432.382996, "world_z": 1900.939941,
            "e1": -6000, "e2": 0, "ext3": 180, "arm": "A",
            "expected_robot_x": 661.997681, "expected_robot_y": -158.511902, "expected_robot_z": 1892.645264
        },
        {
            "name": "P17",
            "world_x": 8883.669922, "world_y": -3365.689941, "world_z": 1909.650024,
            "e1": -6000, "e2": -2073, "ext3": 180, "arm": "A",
            "expected_robot_x": 735.062134, "expected_robot_y": -1031.636597, "expected_robot_z": 1901.070190
        },
        {
            "name": "P19",
            "world_x": 8586.339844, "world_y": 2734.300049, "world_z": 1911.959961,
            "e1": -6000, "e2": 2000, "ext3": 180, "arm": "A",
            "expected_robot_x": 629.741028, "expected_robot_y": 1008.692627, "expected_robot_z": 1897.256836
        },
    ]

    print("=== World → Robot 转换验证 ===\n")
    print(f"{'点号':<6} {'世界坐标 (X, Y, Z)':<35} {'E1':<8} {'E2':<8} {'预期机器人坐标':<35} {'实际机器人坐标':<35} {'误差':<15}")
    print("-" * 150)

    max_error = 0
    total_error = 0

    for point in test_data:
        name = point["name"]
        world_x = point["world_x"]
        world_y = point["world_y"]
        world_z = point["world_z"]
        e1 = point["e1"]
        e2 = point["e2"]
        ext3 = point["ext3"]
        arm = point["arm"]

        expected_x = point["expected_robot_x"]
        expected_y = point["expected_robot_y"]
        expected_z = point["expected_robot_z"]

        # 执行转换
        robot_x, robot_y, robot_z = world_to_robot(
            world_x, world_y, world_z, e1, e2, ext3, arm
        )

        # 计算误差
        error_x = abs(robot_x - expected_x)
        error_y = abs(robot_y - expected_y)
        error_z = abs(robot_z - expected_z)
        error_total = (error_x**2 + error_y**2 + error_z**2)**0.5

        max_error = max(max_error, error_total)
        total_error += error_total

        world_str = f"({world_x:.2f}, {world_y:.2f}, {world_z:.2f})"
        expected_str = f"({expected_x:.3f}, {expected_y:.3f}, {expected_z:.3f})"
        actual_str = f"({robot_x:.3f}, {robot_y:.3f}, {robot_z:.3f})"
        error_str = f"{error_total:.2f}mm"

        print(f"{name:<6} {world_str:<35} {e1:<8.0f} {e2:<8.0f} {expected_str:<35} {actual_str:<35} {error_str:<15}")

    avg_error = total_error / len(test_data)

    print("\n" + "="*150)
    print(f"\n统计结果:")
    print(f"  平均误差: {avg_error:.2f}mm")
    print(f"  最大误差: {max_error:.2f}mm")

    if max_error < 50:
        print(f"\n✓ 测试通过！最大误差 {max_error:.2f}mm 在可接受范围内")
        return 0
    else:
        print(f"\n✗ 测试失败！最大误差 {max_error:.2f}mm 超出预期")
        return 1


if __name__ == "__main__":
    sys.exit(test_conversion())