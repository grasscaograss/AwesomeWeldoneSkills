# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`archive/CONTEXT-MAP.md`** — the multi-context index: which contexts exist, where each lives, and how they relate (shared kernels, dependencies). Read it first to find the context(s) relevant to the topic.
- **`archive/contexts/<ctx>/CONTEXT.md`** — the glossary for the relevant context(s). Read each one relevant to the topic.
- **`docs/adr/`** — system-wide ADRs. For context-scoped decisions, also check `archive/contexts/<ctx>/docs/adr/` if it exists.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure — contexts nest knowledge

This repo is a **multi-context monolith**: one coupled codebase, but its domain splits into a few bounded contexts, each with its own glossary and sub-domain knowledge. The `archive/` knowledge base is organised along that context axis:

```
/
├── archive/
│   ├── CONTEXT-MAP.md                 ← context index + shared kernels + relationships
│   ├── contexts/
│   │   └── <context-slug>/            ← e.g. weld-core
│   │       ├── CONTEXT.md             ← this context's glossary (terms only)
│   │       └── knowledge/
│   │           └── <domain-slug>/     ← sub-domain knowledge files
│   ├── records/                       ← session records (cross-context)
│   ├── reviews/                       ← periodic reviews (cross-context)
│   └── INDEX.md                       ← global index
├── docs/
│   └── adr/                           ← system-wide decisions
└── src/
```

The canonical contexts (see `CONTEXT-MAP.md` for the live list) and their shared kernels:

| Context | Owns | Shared kernel |
|---|---|---|
| `weld-core` | weld-seam, wsg-merge, transition-line, weld-template | `WeldSeam`, `WSG` |
| `robotics` | coordinate, coarse-positioning | `Calculator`, coordinates |
| `orchestration` | workflow (FSM), scanning | `Executor`, state |
| `peripheral` | frontend, device-robot, capacity, tools | (weak) |

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the owning context's `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in any context glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
