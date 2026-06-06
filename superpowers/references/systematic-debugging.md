# Systematic Debugging

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

## The Four Phases

### Phase 1: Root Cause Investigation
1. **Read Error Messages Carefully** — don't skip, read stack traces completely
2. **Reproduce Consistently** — exact steps, every time?
3. **Check Recent Changes** — git diff, recent commits, new dependencies
4. **Gather Evidence** — log data entering/exiting each component boundary
5. **Trace Data Flow** — where does bad value originate? Fix at source.

### Phase 2: Pattern Analysis
1. Find working examples in same codebase
2. Compare against reference implementations
3. Identify ALL differences (however small)
4. Understand dependencies

### Phase 3: Hypothesis and Testing
1. Form single hypothesis: "I think X is root cause because Y"
2. Test minimally — smallest possible change, one variable
3. Verify before continuing
4. When you don't know — say so, ask for help

### Phase 4: Implementation
1. Create failing test case (use TDD)
2. Implement single fix — address root cause, ONE change
3. Verify fix — tests pass, no regressions
4. If 3+ fixes failed: question the architecture, discuss with partner

## Red Flags — STOP

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "One more fix attempt" (after 2+)
- Proposing solutions before tracing data flow
