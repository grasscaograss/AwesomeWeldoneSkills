# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade.

**Core principle:** Review early, review often.

## When to Request

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

1. **Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)
HEAD_SHA=$(git rev-parse HEAD)
```

2. **Dispatch code reviewer** with:
   - DESCRIPTION — what you built
   - PLAN_OR_REQUIREMENTS — what it should do
   - BASE_SHA / HEAD_SHA — commit range

3. **Act on feedback:**
   - Critical → fix immediately
   - Important → fix before proceeding
   - Minor → note for later
   - Wrong → push back with reasoning

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
