# Writing Plans

Write comprehensive implementation plans assuming the engineer has zero context. Document everything: which files to touch, code, testing, how to test. Give bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<slug>.md`

## Scope Check

If the spec covers multiple independent subsystems, suggest breaking into separate plans.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Task Structure

```
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
```

## No Placeholders

Never write: "TBD", "TODO", "implement later", "Add appropriate error handling" (without specifics).

## Self-Review

After writing the plan:
1. **Spec coverage:** Can you point to a task for each requirement?
2. **Placeholder scan:** Any red flag patterns?
3. **Type consistency:** Do types/signatures match across tasks?

## Execution Handoff

Offer choice:
1. **Subagent-Driven (recommended)** — fresh subagent per task + two-stage review
2. **Inline Execution** — execute tasks in this session with checkpoints
