---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Run a `/grilling` session, using the `/domain-modeling` skill.

## This repo's knowledge base

This project is a **multi-context monolith** — one coupled codebase whose domain splits into a few bounded contexts. `/domain-modeling` writes vocabulary, decisions, and knowledge along that context axis under `archive/`:

- **Context glossaries** → `archive/contexts/<ctx>/CONTEXT.md` (one per context; terms only — no implementation details)
- **Context index** → `archive/CONTEXT-MAP.md` (which contexts exist, their shared kernels, and relationships)
- **System decisions** → `docs/adr/` (context-scoped ADRs may live in `archive/contexts/<ctx>/docs/adr/`)
- **Sub-domain knowledge** → `archive/contexts/<ctx>/knowledge/<domain>/`, **session records** → `archive/records/`, both indexed by `archive/INDEX.md`

## After the session

Once the plan is settled and code is written, fold the results back into the archive:

- `/archive-session` — archive this session as a dated record under `archive/records/`
- `/archive` — query past decisions and domain knowledge before a new session
- `/archive-import` — bring external reference docs into the archive
- `/knowledge-reorg` and `/periodic-review` — keep the archive healthy over time

```
/grill-with-docs → coding → /archive-session → /periodic-review
       ↓                            ↓                    ↓
 archive/contexts/<ctx>/       /archive-import        /knowledge-reorg
   CONTEXT.md             (import external docs)   (restructure knowledge)
 archive/CONTEXT-MAP.md                                 ↓
                                                  /archive (query)
```
