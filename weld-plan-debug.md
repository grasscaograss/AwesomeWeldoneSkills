---
name: weld-plan-debug
description: >
  Debugging workflow for welding planning failures in the Weldone project.
  Triggered when the user reports a planning error (e.g., "SolvePath Failed!",
  IndexOutOfRangeException in PrePlanScanWeldDualArmAsyncInSameExternal,
  ParseWeldSeamGroups failure, or "single seam works but multiple fails").
  Covers dual-arm scan/weld transition planning, external axis pre-planning,
  and workpiece seam group parsing.
---

# Weld Planning Debug Workflow

## 1. Prerequisite Checks

Before investigating, confirm the following are available:

- **Stack trace or error log** from the user (production log, simulation log, or pasted exception).
- **Key source files exist** in the current working tree:
  - `src/Robim.Devices.Robot/Plan/Solver/RobotPlanSolver.cs` — solver core, throws `SolvePath Failed!`
  - `src/Weldone.Application/Plan/PlanManager.DualArm.cs` — dual-arm transition planning
  - `src/Weldone.Application/Robot/ExternalRobotAppService.cs` — external axis pre-planning
  - `src/Weldone.Domain/WorkpieceManager/WorkpieceManagerBase.cs` — seam group parsing
  - `src/Weldone.Application/Plan/SolveStrategy/DualArmStrategy.cs` — dual-arm param builder
- **ILogger instance** is accessible in the failing class (verify `using Microsoft.Extensions.Logging;`).
- **OpenSpec spec** for the feature area exists under `openspec/specs/` or `openspec/changes/` (check for intended behavior).

If the user only says "planning failed" without a stack trace, ask for the log first.

## 2. Step-by-Step Procedure

### Step 1 — Anchor on the stack trace (30 seconds)
- Read the error message the user pasted.
- Identify the **topmost method name** and **line number** in the Weldone/Robim namespace.
- Formulate a **2-sentence hypothesis** about what went wrong and where.

### Step 2 — Read the failing site and its caller (2 files max)
- `Read` the method at the line number from the stack trace.
- `Read` the immediate caller one level up.
- If the root cause is not obvious, `Grep` for the method name to find all call sites.
- **Stop here if unclear.** Ask the user: "Hypothesis: [X]. I need to check [Y] to confirm. Proceed?"

### Step 3 — Inspect planning parameters and state
Planning failures are almost always param/state mismatches. Check:
- `ExSearchTimes` value and who last set it (`DualArmStrategy` sets 50, `DualArmTransitionWithAirWallPlanStrategy` sets 1, default is 1).
- `LastJointPos` / `_armJointPoses` state — is it stale or mutated between seams?
- `fixedIndices` and `boundaries` consistency (for external axis planning).
- Shared cache dictionaries (`ScanTransCaches`, `WeldTransCaches`, `ExternalCache`) — are they cleared between planning runs?

### Step 4 — Add diagnostic logging
Use `ILogger` (never `Console.WriteLine`). Add logs at:
- Method entry: log method name, `wsgId`, `armIndex`, and key param values (`ExSearchTimes`, `FixDistance`, `Externals`).
- Decision branches: log which branch was taken and why (e.g., `skipP1={skipP1}, skipP2={skipP2}`).
- Validation results: log `ValidateSingle()` outcome with process id/counts.
- Loop iterations: log index, `ilIdx`, `WsgCount`, and boundary values when iterating seam groups.

Keep log templates structured: `"[MethodName] {WsgId} arm={ArmIndex} exSearch={ExSearchTimes}"`.

### Step 5 — Cross-check with OpenSpec
- Search `openspec/` for the method or feature name.
- Compare intended behavior in the spec against the actual code.
- If code diverges from spec, prefer fixing the code to match the spec (not updating the spec).

### Step 6 — Implement minimal fix
- Edit the narrowest possible scope to resolve the root cause.
- Do not refactor adjacent code unless it directly blocks the fix.
- If the fix involves param changes (e.g., `ExSearchTimes`), ensure related params (`ExParam.Resolution`, `FixDistance`, `banEx`) are consistent.

### Step 7 — Verify without building
- Use `mcp__ide__getDiagnostics` on changed files.
- Do **not** run `dotnet build` unless the user explicitly asks.
- Review the diff for accidental changes.

### Step 8 — Commit
- Use Chinese conventional commit format: `fix(规划): 修复[具体症状]因[根因]`.
- Include the why, not just the what.

## 3. Common Pitfalls & Avoidance

| Pitfall | Why it happens | How to avoid |
|---------|---------------|--------------|
| **Reading >3 files before hypothesizing** | Drifts into broad exploration; wastes context window | Enforce the 2-file limit. Use an agent for broad exploration if needed. |
| **Changing `ExSearchTimes` in isolation** | Dual-arm strategy sets 50 for external axis search; transition strategy sets 1. Changing one without adjusting `Resolution`/`FixDistance` breaks planning silently. | Always check the strategy builder that owns the param. Change all related fields together. |
| **Stale `LastJointPos` / `_armJointPoses`** | Transition planning reuses previous joint state. If a prior seam failed or was skipped, the state may be wrong. | Log `lastJointPos` at entry. Verify it matches the expected end pose of the previous segment. |
| **Console.WriteLine for debug logs** | Project rules require ILogger. Console output does not reach the frontend log panel and will be rejected in review. | Use `logger.LogDebug`/`LogInformation`. Inject ILogger if missing. |
| **IndexOutOfRange on `fixedIndices`** | `maxStartIdx`/`minEndIdx` boundary logic assumes seam point counts match between paired weld seam groups. When `WsgCount` changes (dual-arm vs single), indices drift. | Log `boundaries`, `fixedIndices`, and `nonFixedIndices` before the solver call. Validate `fixedIndices` are within `poseAndExternals.Count`. |
| **Shared cache pollution** | `ExternalCache`, `ScanTransCaches` are not cleared between "一键规划" runs. Old results mask new failures. | Ensure cache reset at the start of each planning batch. |
| **Fixing code to match buggy behavior** | Developer assumes the current runtime behavior is correct and patches around it. | Always check OpenSpec first. The spec is the source of truth. |

## 4. Validation Criteria for Success

A welding planning debug session is complete only when:

1. **Root cause is identified** with a specific file:line citation and a one-sentence explanation.
2. **Diagnostic logs are added** at the failure path and at least one decision branch upstream.
3. **Fix aligns with OpenSpec** (or a spec update is explicitly acknowledged by the user).
4. **LSP diagnostics are clean** on all modified files.
5. **Commit is made** with Chinese conventional commit message summarizing content and cause.
6. **No `dotnet build` was run** unless user explicitly requested it.

## 5. Scenario Simulation: "SolvePath Failed! with changed ExSearchTimes"

**User report:** "SolvePath Failed! 我在 `PlanParamSetting.json` 里把 `ExSearchTimes` 从 50 改成了 20。"

**Skill-guided execution (autonomous):**

1. **Parse error:** `SolvePath Failed!` is thrown at `RobotPlanSolver.cs:507` when `result.ValidateSingle()` returns false.
2. **Read anchor file:** `Read` `RobotPlanSolver.cs` lines 490–510. Confirm the exception is thrown after `GeneratePlanData`.
3. **Hypothesis (2 sentences):** The user reduced `ExSearchTimes` from 50 to 20 in `PlanParamSetting.json`. In dual-arm planning, `DualArmStrategy.Build()` sets `ExSearchTimes = 50` to allow broad external axis search. A lower value may cause the solver to exhaust search attempts before finding a valid path, resulting in `ValidateSingle()` failure.
4. **Check param ownership:** `Grep` for `ExSearchTimes =` across the codebase. Find:
   - `DualArmStrategy.cs:70` → `_originParam.ExSearchTimes = 50;`
   - `DualArmTransitionWithAirWallPlanStrategy.cs:87` → `_originParam.ExSearchTimes = 1;`
   - `PlanConfigUtils.cs:144` → default `1`.
5. **Inspect related params:** `Read` `DualArmStrategy.cs` lines 66–90. Notice it also sets `ExParam.Resolution[2] = 2000` and `ExParam.FixDistance`. These are coupled with `ExSearchTimes`.
6. **Add diagnostic logging:** In `RobotPlanSolver.cs` around line 490, add:
   ```csharp
   logger.LogDebug("[SolveProcess] ExSearchTimes={ExSearchTimes}, FixDistance={FixDistance}, ResolutionZ={ResolutionZ}",
       _currentParam.ExSearchTimes,
       _currentParam.ExParam.FixDistance,
       _currentParam.ExParam.Resolution[2]);
   ```
7. **Check OpenSpec:** `Grep` `openspec/` for `ExSearchTimes`. Find `dual-arm-strategy/spec.md` specifying `ExSearchTimes` should be 1 for transition and 50 for weld external search. The user's change to 20 contradicts the spec for dual-arm external axis search.
8. **Implement fix:** Revert `PlanParamSetting.json` to 50 for the dual-arm procedure key. If the user truly needs 20, also reduce `Resolution[2]` proportionally and re-test.
9. **Verify:** Run `mcp__ide__getDiagnostics` on `RobotPlanSolver.cs`.
10. **Commit:** `git commit` with message:
    ```
    fix(规划): 恢复 DualArmStrategy 的 ExSearchTimes 为 50 以匹配外部轴搜索规范

    用户误将 PlanParamSetting.json 中的 ExSearchTimes 改为 20，
    导致外部轴解算次数不足，触发 SolvePath Failed。
    同时添加 ExSearchTimes/FixDistance/Resolution 的调试日志以便未来排查。
    ```

**Result:** User receives a clean fix, diagnostic logs for next time, and no manual intervention was needed.

## 6. Telemetry Suggestions for Auto-Generating Skills

To automatically derive skills like this in the future, capture per-session telemetry:

1. **Error taxonomy:** Which exception types / error messages appeared (e.g., `RobotSolveException`, `IndexOutOfRangeException`, `ArgumentOutOfRangeException`).
2. **File touch heatmap:** Which files were `Read` and `Edit` during debugging sessions involving planning keywords.
3. **Tool call sequences:** The ordered chain of `Grep` → `Read` → `Edit` → `Read` that led to successful resolution.
4. **User corrections:** Moments where the user said "不对" / "不是这里" / "先判断error再merge" — these indicate friction points.
5. **Hypothesis confirmation latency:** Time between initial hypothesis and user confirmation (or rejection). Long latencies signal vague hypotheses.
6. **Log injection pattern:** Which methods received new `ILogger` calls during bug fixes.
7. **Spec reference frequency:** Which OpenSpec specs were consulted and whether the fix aligned with or contradicted the spec.
8. **Param mutation tracing:** Which planning parameters (`ExSearchTimes`, `FixDistance`, `ToolScale`) were changed during the session and in which files.

Store this telemetry in `~/.claude/telemetry/weld-plan-debug-sessions.jsonl` with one entry per completed debug session. A periodic script can cluster patterns and emit new skill drafts when the same sequence appears 3+ times.
