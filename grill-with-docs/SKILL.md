---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Run a `/grilling` session, using the `/domain-modeling` skill.

## This repo's knowledge base

This project keeps its domain language in an `archive/` knowledge base, not a bare root `CONTEXT.md`. `/domain-modeling` is already wired to write here:

- **Glossary** → `archive/CONTEXT.md` (terminology only — no implementation details)
- **Decisions** → `docs/adr/`
- **Session records** → `archive/records/`, **domain knowledge** → `archive/knowledge/` (indexed by `archive/INDEX.md`)

## After the session

Once the plan is settled and code is written, fold the results back into the archive:

- `/archive-session` — archive this session as a dated record under `archive/records/`
- `/archive` — query past decisions and domain knowledge before a new session
- `/archive-import` — bring external reference docs into the archive
- `/knowledge-reorg` and `/periodic-review` — keep the archive healthy over time

```
/grill-with-docs → coding → /archive-session → /periodic-review
       ↓                            ↓                    ↓
  archive/CONTEXT.md          /archive-import        /knowledge-reorg
  docs/adr/             (import external docs)   (restructure knowledge)
                                                         ↓
                                                  /archive (query)
```
