# Subagent-Driven Development

Execute plan by dispatching fresh subagent per task, with two-stage review: spec compliance first, then code quality.

**Core principle:** Fresh subagent per task + two-stage review = high quality, fast iteration

**Continuous execution:** Do not pause between tasks. Execute all without stopping. Only stop for: BLOCKED status, genuine ambiguity, or all tasks complete.

## The Process

1. Read plan, extract all tasks, create task list
2. For each task:
   a. Dispatch implementer subagent with full task text + context
   b. If implementer asks questions, answer them
   c. Dispatch spec reviewer — verify code matches spec
   d. Dispatch code quality reviewer — verify implementation quality
   e. Mark task complete
3. After all tasks: dispatch final reviewer
4. Use finishing-a-development-branch skill

## Model Selection

- **Mechanical tasks** (1-2 files, clear specs): fast, cheap model
- **Integration tasks** (multi-file, pattern matching): standard model
- **Architecture/design/review**: most capable model

## Handling Implementer Status

- **DONE:** Proceed to spec review
- **DONE_WITH_CONCERNS:** Read concerns before proceeding
- **NEEDS_CONTEXT:** Provide missing context, re-dispatch
- **BLOCKED:** Assess — provide context, upgrade model, break down, or escalate

## Red Flags

**Never:**
- Skip reviews
- Proceed with unfixed issues
- Dispatch multiple implementers in parallel
- Start code quality review before spec compliance passes
- Move to next task while review has open issues
