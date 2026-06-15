#!/usr/bin/env python3
"""Summarize Weldone hybrid replay Arc diagnostics from a JSON file or directory."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable


def replay_files(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path
        return

    patterns = (
        "SingleHybridReconstructionReplayPackage*.json",
        "ReconstructionReplayPackage*.json",
    )
    for pattern in patterns:
        yield from sorted(path.rglob(pattern))


def get_value(obj: dict[str, Any], *names: str) -> Any:
    for name in names:
        if name in obj:
            return obj[name]
    return None


def summarize_file(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as stream:
        package = json.load(stream)

    diagnostics = package.get("ArcFitDiagnostics") or []
    weak = [item for item in diagnostics if item.get("WeakReconstruction")]
    reconstructed = (
        package.get("ReconstructedWsg")
        or package.get("ReconstructedOriginalWsg")
        or {}
    )
    segment_count = len(reconstructed.get("WeldSeams") or [])

    return {
        "path": str(path),
        "failureExceptionType": package.get("FailureExceptionType"),
        "failureMessage": package.get("FailureMessage"),
        "arcFitCount": len(diagnostics),
        "weakArcCount": len(weak),
        "reconstructedSegmentCount": segment_count,
        "diagnostics": diagnostics,
    }


def format_float(value: Any) -> str:
    if isinstance(value, (int, float)):
        return f"{value:.3f}"
    return "-"


def print_summary(summary: dict[str, Any]) -> None:
    print(f"\n{summary['path']}")
    print(f"  FailureExceptionType: {summary['failureExceptionType'] or '-'}")
    print(f"  FailureMessage: {summary['failureMessage'] or '-'}")
    print(f"  ReconstructedSegmentCount: {summary['reconstructedSegmentCount']}")
    print(f"  ArcFitCount: {summary['arcFitCount']}")
    print(f"  WeakArcCount: {summary['weakArcCount']}")

    for diagnostic in summary["diagnostics"]:
        quality = diagnostic.get("Quality") or {}
        reasons = diagnostic.get("WeakReasons") or []
        if isinstance(reasons, list):
            reason_text = ",".join(str(item) for item in reasons) or "-"
        else:
            reason_text = str(reasons)

        print(
            "  "
            f"SegIdx={get_value(diagnostic, 'SegmentIndex', 'segmentIndex')} "
            f"Points={get_value(diagnostic, 'PointCount', 'pointCount')} "
            f"Weak={get_value(diagnostic, 'WeakReconstruction', 'weakReconstruction')} "
            f"RadiusDev={format_float(get_value(diagnostic, 'RadiusDeviation', 'radiusDeviation'))} "
            f"RadiusRatio={format_float(get_value(diagnostic, 'RadiusDeviationRatio', 'radiusDeviationRatio'))} "
            f"CenterDev={format_float(get_value(diagnostic, 'CenterDeviation', 'centerDeviation'))} "
            f"Chord={format_float(get_value(diagnostic, 'ChordLength', 'chordLength'))} "
            f"Sagitta={format_float(get_value(diagnostic, 'Sagitta', 'sagitta'))} "
            f"SagittaRatio={format_float(get_value(diagnostic, 'SagittaRatio', 'sagittaRatio'))} "
            f"ChordRadiusRatio={format_float(get_value(diagnostic, 'ChordRadiusRatio', 'chordRadiusRatio'))} "
            f"Rms={format_float(get_value(quality, 'RmsResidual', 'rmsResidual'))} "
            f"MaxResidual={format_float(get_value(quality, 'MaxResidual', 'maxResidual'))} "
            f"Reasons=[{reason_text}]"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Replay JSON file or directory to scan")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    args = parser.parse_args()

    path = Path(args.path)
    if not path.exists():
        raise SystemExit(f"Path does not exist: {path}")

    summaries = [summarize_file(file) for file in replay_files(path)]
    if args.json:
        print(json.dumps(summaries, ensure_ascii=False, indent=2))
        return 0

    if not summaries:
        print(f"No replay package JSON files found under: {path}")
        return 1

    for summary in summaries:
        print_summary(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
