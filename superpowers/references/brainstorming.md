# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. "Simple" projects are where unexamined assumptions cause the most wasted work.

## Checklist

1. **Explore project context** — check files, docs, recent commits
2. **Offer visual companion** (if topic will involve visual questions)
3. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections, get user approval after each section
6. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD--design.md` and commit
7. **Spec self-review** — check for placeholders, contradictions, ambiguity, scope
8. **User reviews written spec** — ask user to review before proceeding
9. **Transition to implementation** — invoke writing-plans

## Key Principles

- **One question at a time**
- **Multiple choice preferred** when possible
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always propose 2-3 approaches
- **Incremental validation** — get approval before moving on

## After the Design

- Write spec to `docs/superpowers/specs/YYYY-MM-DD--design.md`
- Spec self-review: placeholder scan, internal consistency, scope check, ambiguity check
- User review gate: ask user to review written spec
- Invoke writing-plans to create implementation plan
