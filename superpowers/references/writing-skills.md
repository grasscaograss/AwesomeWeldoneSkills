# Writing Skills

**Writing skills IS Test-Driven Development applied to process documentation.**

Write test cases (pressure scenarios), watch them fail (baseline), write the skill, watch tests pass (agents comply), refactor (close loopholes).

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

## What is a Skill?

- **Skills are:** Reusable techniques, patterns, tools, reference guides
- **Skills are NOT:** Narratives about how you solved a problem once

## SKILL.md Structure

```yaml
---
name: Skill-Name
description: Use when [specific triggering conditions]  # NOT what it does
---
```

**Critical:** Description = When to Use, NOT What the Skill Does. This prevents agents from shortcutting by reading the description instead of the full skill.

## Claude Search Optimization (CSO)

1. **Rich description** — triggering conditions only, start with "Use when..."
2. **Keyword coverage** — error messages, symptoms, synonyms, tool names
3. **Descriptive naming** — active voice, verb-first
4. **Token efficiency** — frequently-loaded: <200 words; others: <500 words

## The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

## Skill Creation Checklist

**RED Phase:**
- [ ] Create pressure scenarios
- [ ] Run WITHOUT skill — document baseline
- [ ] Identify rationalization patterns

**GREEN Phase:**
- [ ] Valid frontmatter (name + description)
- [ ] Description starts with "Use when..."
- [ ] Clear overview with core principle
- [ ] Address baseline failures
- [ ] Run WITH skill — verify compliance

**REFACTOR Phase:**
- [ ] Identify new rationalizations
- [ ] Add explicit counters
- [ ] Build rationalization table
- [ ] Create red flags list
- [ ] Re-test until bulletproof
