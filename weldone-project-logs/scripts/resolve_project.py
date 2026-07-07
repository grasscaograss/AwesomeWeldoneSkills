#!/usr/bin/env python3
"""
解析 Weldone 项目配置根目录与当前项目目录，并列出日志文件。

路径规则（绝不写死用户名）：
  根目录   = $APPDATA/Roboticplus/Weldone/1.0.x
  项目目录 = 根目录/$(ProjectConfig.json 的 ProjectFolder 字段)
  日志目录 = 项目目录/Logs

用法：
  python resolve_project.py            # 打印根目录、当前项目名、项目目录、日志目录
  python resolve_project.py --list     # 额外列出 Logs 下的日志（按修改时间倒序）
  python resolve_project.py --project KukaTest   # 临时指定其它项目子目录
"""
import argparse
import json
import os
import sys
from pathlib import Path

CONFIG_ROOT_NAME = "Roboticplus/Weldone/1.0.x"


def resolve_config_root() -> Path:
    """从 APPDATA 环境变量解析配置根目录，绝不写死用户名。"""
    appdata = os.environ.get("APPDATA")
    if not appdata:
        # 兜底：USERPROFILE\AppData\Roaming（Linux/Mac 下退回 HOME）
        userprofile = os.environ.get("USERPROFILE") or os.environ.get("HOME")
        if not userprofile:
            raise RuntimeError("无法定位用户目录：APPDATA / USERPROFILE / HOME 均缺失")
        appdata = str(Path(userprofile) / "AppData" / "Roaming")
    root = Path(appdata) / CONFIG_ROOT_NAME
    if not root.exists():
        raise FileNotFoundError(
            f"配置根目录不存在: {root}\n"
            "请确认 APPDATA 环境变量正确，或 Weldone 已安装并运行过。"
        )
    return root


def read_project_name(config_root: Path) -> str:
    """读取 ProjectConfig.json 的 ProjectFolder 字段。"""
    pc = config_root / "ProjectConfig.json"
    if not pc.exists():
        raise FileNotFoundError(f"缺少 ProjectConfig.json: {pc}")
    try:
        cfg = json.loads(pc.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise RuntimeError(f"ProjectConfig.json 解析失败: {e}") from e
    name = cfg.get("ProjectFolder")
    if not name:
        raise RuntimeError(
            f"ProjectConfig.json 未配置 ProjectFolder 字段，原始内容:\n{cfg}"
        )
    return name


def resolve_project_dir(config_root: Path, project_name: str) -> Path:
    project_dir = config_root / project_name
    if not project_dir.exists():
        raise FileNotFoundError(f"项目目录不存在: {project_dir}")
    return project_dir


def list_logs(log_dir: Path) -> list:
    """列出日志，按修改时间倒序。0KB 文件标注 [磁盘显示 0KB，需实读确认]。"""
    import time
    if not log_dir.exists():
        return []
    entries = []
    for p in sorted(log_dir.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
        if not p.is_file():
            continue
        st = p.stat()
        ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(st.st_mtime))
        flag = "  [磁盘显示 0KB，需实读确认]" if st.st_size == 0 else ""
        entries.append((p.name, st.st_size, ts, flag))
    return entries


def main():
    ap = argparse.ArgumentParser(description="解析 Weldone 项目路径并列出日志")
    ap.add_argument("--list", action="store_true", help="列出 Logs 下的日志文件")
    ap.add_argument("--project", default=None, help="临时指定项目子目录名")
    args = ap.parse_args()

    try:
        config_root = resolve_config_root()
        project_name = args.project or read_project_name(config_root)
        project_dir = resolve_project_dir(config_root, project_name)
        log_dir = project_dir / "Logs"

        print(f"配置根目录 : {config_root}")
        print(f"当前项目   : {project_name}")
        print(f"项目目录   : {project_dir}")
        print(f"日志目录   : {log_dir}")

        if args.list:
            print(f"\n--- 日志列表（按修改时间倒序）---")
            if not log_dir.exists():
                print(f"  (日志目录不存在: {log_dir})")
            else:
                entries = list_logs(log_dir)
                if not entries:
                    print("  (无日志文件)")
                for name, size, ts, flag in entries:
                    print(f"  {ts}  {size:>10} B  {name}{flag}")
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
