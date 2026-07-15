# Context CONTEXT.md Format

Each bounded context keeps its own glossary at `archive/contexts/<context-slug>/CONTEXT.md`. There is one per context, plus a root `archive/CONTEXT-MAP.md` that indexes them.

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Scope to this context.** Only include terms specific to this context's shared kernel. General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Shared kernels go in CONTEXT-MAP.md, not duplicated.** If a term is shared across contexts (e.g. `WeldSeam`), record it once in `CONTEXT-MAP.md`'s shared-kernel section and reference it — don't copy it into every context glossary.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.

## Where it lives

This repo is multi-context. Each context's glossary lives at `archive/contexts/<context-slug>/CONTEXT.md`, indexed by the root `archive/CONTEXT-MAP.md`. See [CONTEXT-MAP.md format](#) below.

### CONTEXT-MAP.md (the context index)

`archive/CONTEXT-MAP.md` lists the contexts, where each lives, and how they relate:

```md
# Context Map

## Contexts

- [Welding Core](./contexts/weld-core/CONTEXT.md) — weld seams, groups, transitions, templates
- [Robotics](./contexts/robotics/CONTEXT.md) — coordinates, calibration, coarse positioning
- [Orchestration](./contexts/orchestration/CONTEXT.md) — FSM, scanning workflow
- [Peripheral](./contexts/peripheral/CONTEXT.md) — frontend, devices, capacity, tooling

## Shared kernels

- **WeldSeam** — owned by Welding Core; referenced (by ID) by Robotics, Orchestration
- **Coordinate / MapMatrix** — owned by Robotics; consumed by Welding Core, Orchestration

## Relationships

- **Welding Core → Orchestration**: Orchestration drives weld seams through the FSM; consumes WeldSeam/WSG types
- **Robotics → Welding Core / Orchestration**: coordinate transforms and calibration feed pose solving and scanning
```
