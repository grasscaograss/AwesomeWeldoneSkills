---
name: weldone-hybrid-seam-replay-debug
description: Weldone hybrid seam replay debugging for single-machine or dual-arm reconstruction packages, LaserPoint RANSAC failures, Arc fitting thresholds, weak Arc diagnostics, tangent continuity, replay-single-hybrid, and replay-dualarm-hybrid.
license: Apache-2.0
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Weldone Hybrid Seam Replay Debug

## Overview

定位 Weldone 混合焊缝重构问题时，优先围绕 replay 包复现、RANSAC 拟合质量、Arc 弱诊断和重构几何连续性推进。目标是用最少代码改动判断是点云质量问题、阈值策略问题、端点/相切几何问题，还是 replay 包/CLI 保存链路问题。

## Trigger Scenarios

Use this skill when the user mentions any of these:

- `SingleHybridReconstructionReplayPackage.json` or `ReconstructionReplayPackage.json`.
- `replay-single-hybrid`, `replay-dualarm-hybrid`, or "新的 replay 包能不能存下来".
- 单机混合焊缝、双机混合焊缝、HybridSeam、LaserPoint RANSAC、Arc 拟合失败。
- 半径偏差、圆心偏差、短弧 3 点、弦高、相切关系、端头锚点、未扫描 arc 对齐。
- Logs containing `HybridRansacFitException`, `LaserPoint Arc RANSAC`, `RadiusDeviation`, `CenterDeviation`, `MaxResidual`, or `InlierRatio`.

## Fast Workflow

1. Read `AGENTS.md` and `CLAUDE.md` in the Weldone repo before changing code.
2. Identify package type:
   - `SingleHybridReconstructionReplayPackage.json` -> run `just replay-single-hybrid "INPUT_PATH" "OUTPUT_PATH"`.
   - `ReconstructionReplayPackage.json` -> run `just replay-dualarm-hybrid "INPUT_PATH" "OUTPUT_PATH"`.
3. Never overwrite the original replay package. Always write a timestamped output beside it or into a temp/debug folder.
4. After CLI replay, inspect:
   - `FailureExceptionType` / `FailureMessage`.
   - `LineFitDiagnostics`, `ArcFitDiagnostics`, `CommonTangentDiagnostics`.
   - Reconstructed segment count, endpoint anchor error, tangent continuity logs.
5. Use `scripts/summarize_replay_arc_diagnostics.py REPLAY_JSON_OR_DIRECTORY` to summarize Arc diagnostics quickly.
6. If CLI execution modifies `src/Weldone.Cli/Logs/logs.txt`, restore it unless the user explicitly wants log changes committed.
7. Add or update focused tests before finalizing:
   - `HybridSeamSegmentFitterTests` for domain fitting behavior.
   - `HybridSinglePointReconstructionTests` for single-machine application behavior when relevant.
   - Replay CLI verification with a field package when available.

## Arc Threshold Policy

Treat Arc RANSAC hard failures as point-cloud quality failures only:

- `InlierRatio` at least `0.6`.
- `RmsResidual` at most `1.0mm`.
- `MaxResidual` at most `2.0mm`.

Treat `RadiusDeviation` and `CenterDeviation` as diagnostics, not hard failures. Short arcs can have large radius or center deviation while still being acceptable if the captured points are self-consistent and the reconstructed geometry stays continuous.

Mark weak Arc reconstruction for observability, not rejection, when any of these are true:

- `PointCount` at most `3`.
- `SagittaRatio` less than `0.05`.
- `ChordRadiusRatio` less than `0.30`.
- `RadiusDeviationRatio` greater than `0.20`.
- `MaxOriginalRadialDeviation` greater than `30mm`.

## Code Map

Check these files first:

- `src/Weldone.Domain/WeldProcedure/HybridSeam/HybridConstrainedRansacFitter.cs` - RANSAC candidate scoring and hard failure thresholds.
- `src/Weldone.Domain/WeldProcedure/HybridSeam/HybridSeamSegmentFitter.cs` - segment fitting, endpoint resolution, tangent handling, and `Last*Diagnostics`.
- `src/Weldone.Domain/WeldProcedure/HybridSeam/HybridRansacFitQuality.cs` - diagnostic records and log formatting.
- `src/Weldone.Application/Scanning/HybridSeam/HybridWeldSeamCalibrationService.cs` - replay package creation/saving and field debug package capture.
- `src/Weldone.Application/Scanning/HybridSeam/*ReplayPackage.cs` - replay package schemas.
- `src/Weldone.Cli/Commands/ReplaySingleHybridCommand.cs` - single-machine replay CLI.
- `src/Weldone.Cli/Commands/ReplayHybridCommand.cs` - dual-arm replay CLI.
- `test/Weldone.Domain.Tests/WeldProcedure/HybridSeamSegmentFitterTests.cs` - domain regression tests.

## Detailed Reference

Load `references/hybrid_replay_debug_workflow.md` when the task needs root-cause analysis, code changes, threshold design, or a final explanation of replay results.
