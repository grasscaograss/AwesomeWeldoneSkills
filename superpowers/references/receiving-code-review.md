# Receiving Code Review

Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern

```
1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Forbidden Responses

**NEVER:**
- "You're absolutely right!" (performative)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:** Restate requirement, ask clarifying questions, push back with reasoning, or just start working.

## Handling Unclear Feedback

If any item is unclear, STOP. Ask for clarification on ALL unclear items before implementing anything.

## YAGNI Check

If reviewer suggests "implementing properly":
- grep codebase for actual usage
- If unused → "Remove it (YAGNI)?"
- If used → Then implement properly

## When To Push Back

- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI
- Technically incorrect for this stack
- Conflicts with architectural decisions

**How:** Technical reasoning, specific questions, reference working tests/code.

## Acknowledging Correct Feedback

```
✅ "Fixed. [what changed]"
✅ "Good catch - [issue]. Fixed in [location]."
✅ [Just fix it]
❌ "You're absolutely right!" / "Great point!" / "Thanks!"
```
