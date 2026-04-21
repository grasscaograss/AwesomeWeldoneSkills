#!/usr/bin/env python3
"""Regenerate openspec/INDEX.md from current specs and changes."""
import datetime
import json
import re
import subprocess
from pathlib import Path

BASE = Path("openspec")
SPECS_DIR = BASE / "specs"
CHANGES_DIR = BASE / "changes"
ARCHIVE_DIR = CHANGES_DIR / "archive"
INDEX_PATH = BASE / "INDEX.md"

CATEGORIES = {
    "Dual-Arm System / 双臂系统": [
        "dual-arm-strategy", "dual-arm-strategy-ddd-refactor", "dual-arm-strategy-cleanup",
        "dual-arm-transition", "dual-arm-weld-strategy", "dual-arm-plan-pipeline",
        "dual-arm-pair-extraction", "dual-arm-pose-tracking", "dual-arm-arc-start-delay",
        "dual-arm-arc-end-delay", "dual-arm-arc-end-position-capture",
        "dual-arm-group-external-preplan", "dualarm-target-rotation",
        "fanuc-dual-transition", "external-movement-preplan",
    ],
    "Weld Template / 焊接模板": [
        "weld-template-editor", "weld-template-management", "weld-template-matching",
        "weld-template-matching-operation-log", "weld-template-ui", "unified-template-matching",
    ],
    "Weld Seam Planning / 焊缝规划": [
        "seam-planning", "weld-seam-geometry", "weld-seam-orientation", "weld-seam-splitting",
        "weld-seam-feature-editing", "weld-seam-ilidx-grouping", "weld-feature-points",
        "weld-robot-app-service", "weld-robot-post-processing", "planning-weld-seam-editor",
        "dual-arm-long-seam-follow",
    ],
    "Coarse Positioning / 粗定位": [
        "coarse-positioning-core", "coarse-positioning-ui", "coarse-localization-camera-defaults",
        "create-work-order-on-coarse-positioning",
    ],
    "Precise Positioning & Scanning / 精定位与扫描": [
        "modelbase-dual-precise-positioning", "scanning", "scan-movel-subprogram",
        "vision-pose-correction", "capture-point-status",
    ],
    "Capacity Statistics / 产能统计": [
        "device-capacity-statistics", "task-capacity-statistics", "clean-gun-counter",
        "operation-logging",
    ],
    "Weld Tracking / 焊接跟踪": [
        "weld-tracking-control", "weld-tracking-range", "indexed-sensor-control",
    ],
    "Coordinate & Matrix / 坐标与矩阵": [
        "map-matrix-calculator", "map-matrix-data-primitives", "coord-calibration", "solver-p2p",
    ],
    "State Machine & Workflow / 状态机与工作流": [
        "production-execution", "state-layer-separation", "crash-recovery",
        "workflow-data-cache-api", "task-schedule-persistence", "skip-workpiece",
    ],
    "Frontend & UI / 前端界面": [
        "panel-splitter", "filter-toggle-deselect", "tree-multiselect-keyboard-interaction",
        "context-menu-selection", "fov-rendering", "multi-tool-head-rendering", "log-auto-refresh",
    ],
    "Device & Robot / 设备与机器人": [
        "fanuc-http-position-reading", "robot-backup", "robot-file-archive",
        "robot-record-visioned-calculator", "config-backup-tolerant-serialization",
        "arc-start-speed-priority", "tcp-quick-input",
    ],
}

def get_purpose(spec_dir: Path) -> str:
    md = spec_dir / "spec.md"
    if not md.exists():
        return ""
    text = md.read_text(encoding="utf-8")
    m = re.search(r"## Purpose\s*\n([^#\n].*)", text)
    if m:
        return m.group(1).strip()
    return ""

def get_caps_from_change(change_dir: Path):
    caps = []
    for p in change_dir.rglob("specs/*/spec.md"):
        rel = p.relative_to(change_dir / "specs")
        caps.append(rel.parts[0])
    return caps

def list_active_changes():
    try:
        out = subprocess.run(
            ["openspec", "list", "--json"],
            capture_output=True, text=True, check=True,
        )
        data = json.loads(out.stdout)
        return {c["name"]: c for c in data.get("changes", [])}
    except Exception:
        return {}

def list_archived_changes():
    if not ARCHIVE_DIR.exists():
        return []
    return sorted(d.name for d in ARCHIVE_DIR.iterdir() if d.is_dir())

def main():
    # 1. specs
    specs = {}
    for d in sorted(SPECS_DIR.iterdir()):
        if d.is_dir():
            specs[d.name] = get_purpose(d)

    # 2. active changes
    active_meta = list_active_changes()
    active_caps = {}
    for name, meta in active_meta.items():
        cdir = CHANGES_DIR / name
        active_caps[name] = get_caps_from_change(cdir)

    # 3. archived changes
    archived = list_archived_changes()
    archived_caps = {}
    for name in archived:
        cdir = ARCHIVE_DIR / name
        archived_caps[name] = get_caps_from_change(cdir)

    # Build reverse mapping: cap -> changes
    cap_active = {s: [] for s in specs}
    cap_archived = {s: [] for s in specs}
    for ch, caps in active_caps.items():
        for c in caps:
            cap_active.setdefault(c, []).append(ch)
    for ch, caps in archived_caps.items():
        for c in caps:
            cap_archived.setdefault(c, []).append(ch)

    # Categorize
    other = []
    category_map = {cat: [] for cat in CATEGORIES}
    for s in sorted(specs):
        placed = False
        for cat, members in CATEGORIES.items():
            if s in members:
                category_map[cat].append(s)
                placed = True
                break
        if not placed:
            other.append(s)
    if other:
        category_map["Other / 其他"] = other

    lines = [
        "# OpenSpec Capability Index",
        "",
        "> Auto-generated index for Claude to quickly locate specs.",
        f"> Last updated: {datetime.date.today().isoformat()}",
        "",
        "## How to Use",
        "",
        "- Each entry: `capability-name` — one-line purpose — `spec path`",
        '- `[A]` = has active change, `[N]` = archived changes',
        "- Search by keyword with: `grep -i \"keyword\" openspec/INDEX.md`",
        "",
        "---",
        "",
    ]

    for cat, members in category_map.items():
        if not members:
            continue
        lines.append(f"## {cat}")
        lines.append("")
        lines.append("| Capability | Summary | Active / Archived Changes |")
        lines.append("|---|---|---|")
        for s in sorted(members):
            a_tags = ", ".join(sorted(cap_active.get(s, [])))
            n_tags = ", ".join(sorted(cap_archived.get(s, [])))
            parts = []
            if a_tags:
                parts.append(f"[A] {a_tags}")
            if n_tags:
                parts.append(f"[N] {n_tags}")
            changes = " ".join(parts) or "—"
            purpose = specs.get(s, "") or "—"
            lines.append(f"| `{s}` | {purpose} | {changes} |")
        lines.append("")

    # Active changes table
    if active_meta:
        lines.append("## Active Changes")
        lines.append("")
        lines.append("| Change | Status | Related Capabilities |")
        lines.append("|---|---|---|")
        for name, meta in sorted(active_meta.items()):
            status = meta.get("status", "")
            caps = ", ".join(sorted(active_caps.get(name, [])))
            lines.append(f"| `{name}` | {status} | {caps or '—'} |")
        lines.append("")

    INDEX_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Updated {INDEX_PATH}")

if __name__ == "__main__":
    main()
