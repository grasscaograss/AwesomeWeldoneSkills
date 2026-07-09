# Hybrid Seam Replay Debug Workflow

## Purpose

Use this reference to debug Weldone hybrid weld seam reconstruction problems from field replay packages and logs. Focus on reproducibility first, then distinguish point-cloud quality failures from acceptable weak Arc geometry.

## Replay Package Types

- `SingleHybridReconstructionReplayPackage.json`
  - Single-machine, non-closed hybrid seam reconstruction.
  - CLI: `just replay-single-hybrid "<input>" "<output>"`.
  - Key fields: `OriginalWsgForReconstruction`, `CapturedPoints`, `EndpointAnchors`, `Junctions`, `ReconstructedWsg`, `LineFitDiagnostics`, `ArcFitDiagnostics`, `CommonTangentDiagnostics`, failure fields.

- `ReconstructionReplayPackage.json`
  - Dual-arm or closed hybrid reconstruction package.
  - CLI: `just replay-dualarm-hybrid "<input>" "<output>"`.
  - Key fields: `OriginalWsgForReconstruction`, `Half1Wsg`, `Half2Wsg`, `MergedCapturedPoints`, `RawMergedCapturedPoints`, `MergedCapturedPointsPlaneProjection`, `ReconstructedOriginalWsg`, `ResplitHalf1`, `ResplitHalf2`, diagnostics, failure fields.

## Standard Procedure

1. Confirm the replay package path exists.
2. Create an output path that does not overwrite input, for example:
   `SingleHybridReconstructionReplayPackage.replayed.<topic>.<yyyyMMdd_HHmmss_fff>.json`.
3. Run the proper CLI recipe from repo root:
   ```pwsh
   just replay-single-hybrid "<input>" "<output>"
   just replay-dualarm-hybrid "<input>" "<output>"
   ```
4. If replay fails, inspect the saved failure package instead of only reading console logs.
5. Summarize the saved package:
   ```pwsh
   python "C:\Users\mini-pc\.codex\skills\weldone-hybrid-seam-replay-debug\scripts\summarize_replay_arc_diagnostics.py" "<output>"
   ```
6. Restore `src/Weldone.Cli/Logs/logs.txt` if CLI execution modified it:
   ```pwsh
   git restore --worktree -- src/Weldone.Cli/Logs/logs.txt
   ```

## Arc Fitting Interpretation

Hard failure should mean the captured points do not support a stable primitive:

- Too few inliers: `InlierRatio < 0.6`.
- Point residual too high: `RmsResidual > 1.0mm` or `MaxResidual > 2.0mm`.

Do not hard-fail Arc only because:

- `RadiusDeviation` is large.
- `CenterDeviation` is large.

Reason: short arcs and 3-point arcs can fit a different but locally acceptable circle. The field case `SegIdx=6` had 3 points, zero residual, large radius/center deviation, and should reconstruct successfully with a weak diagnostic.

## Weak Arc Diagnostics

Create or inspect `HybridArcFitDiagnostics` with these fields:

- `SegmentIndex`
- `PointCount`
- `RadiusDeviation`
- `RadiusDeviationRatio`
- `CenterDeviation`
- `ChordLength`
- `Sagitta`
- `SagittaRatio`
- `ChordRadiusRatio`
- `MaxOriginalRadialDeviation`
- `WeakReconstruction`
- `WeakReasons`
- `Quality`

Weak reasons are observability only. They should not throw.

Use these current thresholds:

- `PointCount <= 3`
- `SagittaRatio < 0.05`
- `ChordRadiusRatio < 0.30`
- `RadiusDeviationRatio > 0.20`
- `MaxOriginalRadialDeviation > 30mm`

Interpretation guide:

- `PointCount <= 3`: exact circle can pass residual checks, but confidence is low.
- `SagittaRatio < 0.05`: captured arc is very flat relative to chord length; many radii can explain it.
- `ChordRadiusRatio < 0.30`: captured span covers too little angular range.
- `RadiusDeviationRatio > 0.20`: fitted radius diverges materially from original, but still only diagnostic.
- `MaxOriginalRadialDeviation > 30mm`: captured points are far from original circle, indicating possible drift or scan mismatch.

## Geometry Checks

For single-machine non-closed seams:

- Preserve original segment structure.
- Do not truncate a captured segment merely because a neighboring segment was not scanned.
- If original `Line` and `Arc` are tangent, preserve tangent geometry where possible.
- For an unscanned endpoint Arc, align it to the endpoint anchor and infer geometry from the adjacent line when possible.

For closed or dual-arm seams:

- Check plane projection diagnostics first: `MergedCapturedPointsPlaneProjection`.
- Verify split/resplit output and original split points.
- Check tangent continuity logs for `|dot|` and angle.

## Common Log Patterns

Successful but weak Arc:

```text
LaserPoint Arc RANSAC 质量通过 ... SegIdx=6 ... PointCount=3 ... RadiusDeviation=67.533 ...
LaserPoint Arc 弱重构诊断 ... WeakReasons=[PointCount<=3,SagittaRatio<0.05,ChordRadiusRatio<0.30]
```

Hard failure that should remain hard:

```text
HybridRansacFitException ... AlgoType=Arc ... Failure=InlierRatio ...
HybridRansacFitException ... AlgoType=Arc ... Failure=RmsResidual ...
HybridRansacFitException ... AlgoType=Arc ... Failure=MaxResidual ...
```

If a failure mentions only `RadiusDeviation` or `CenterDeviation`, remove that hard failure condition and convert it to diagnostics.

## Test Strategy

Add or update `HybridSeamSegmentFitterTests`:

- Short 3-point Arc with large radius/center deviation reconstructs and marks `WeakReconstruction=true`.
- Well-covered Arc reconstructs and is not weak.
- Bad Arc point cloud with insufficient inliers still throws `HybridRansacFitException`.
- Existing single-machine cases preserve endpoints, segment structure, and tangent relationship.

Application/CLI verification:

- Run `dotnet test .\test\Weldone.Domain.Tests\Weldone.Domain.Tests.csproj --filter "FullyQualifiedName~HybridSeamSegmentFitterTests"`.
- Run `dotnet test .\test\Weldone.Application.Tests\Weldone.Application.Tests.csproj --filter "FullyQualifiedName~HybridSinglePointReconstructionTests"` when single-machine app behavior changed.
- Replay the field package and inspect the saved output package.

## Final Report Checklist

Include:

- What changed in code.
- Which replay package was used and where the new package was saved.
- Failure fields status.
- `ArcFitCount` and weak Arc count.
- Key weak Arc reasons and values for the problematic segment.
- Tests and CLI commands that passed.
- Any warnings that are pre-existing or unrelated.
