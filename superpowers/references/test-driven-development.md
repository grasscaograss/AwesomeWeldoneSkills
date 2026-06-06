# Test-Driven Development (TDD)

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

## Red-Green-Refactor

### RED — Write Failing Test
- One behavior per test
- Clear name describing behavior
- Real code (no mocks unless unavoidable)

### Verify RED — Watch It Fail (**MANDATORY**)
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing (not typos)

### GREEN — Minimal Code
Write simplest code to pass. Don't add features beyond the test.

### Verify GREEN — Watch It Pass (**MANDATORY**)
- Test passes
- Other tests still pass
- Output pristine

### REFACTOR — Clean Up (after green only)
- Remove duplication, improve names, extract helpers
- Keep tests green. Don't add behavior.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. |
| "TDD is dogmatic" | TDD IS pragmatic — finds bugs before commit. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |

## Red Flags — STOP

- Code before test
- Test after implementation
- Test passes immediately
- Rationalizing "just this once"

**All mean: Delete code. Start over with TDD.**
