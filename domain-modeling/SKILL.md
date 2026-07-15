---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when the user wants to pin down domain terminology or a ubiquitous language, record an architectural decision, or when another skill needs to maintain the domain model.
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline — challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* a context's `CONTEXT.md` for vocabulary is not this skill — that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure — contexts nest knowledge

This repo is a **multi-context** monolith: one coupled codebase, but its domain splits into a few **bounded contexts**, each with its own glossary and sub-domain knowledge. The `archive/` knowledge base is organised along that context axis — vocabulary, knowledge, and (optionally) ADRs all hang under each context:

```
/
├── archive/
│   ├── CONTEXT-MAP.md                 ← the context index + their relationships (shared kernels, context map)
│   ├── contexts/
│   │   └── <context-slug>/            ← e.g. weld-core
│   │       ├── CONTEXT.md             ← this context's glossary (terms only)
│   │       └── knowledge/
│   │           └── <domain-slug>/     ← e.g. weld-seam (sub-domain knowledge files)
│   ├── records/                       ← session records (cross-context, by date)
│   ├── reviews/                       ← periodic reviews (cross-context)
│   └── INDEX.md                       ← global index
├── docs/
│   └── adr/                           ← system-wide decisions; context-scoped ADRs may live in archive/contexts/<ctx>/docs/adr/
└── src/
```

`CONTEXT-MAP.md` lists the contexts, where each lives, and how they relate — most importantly their **shared kernels** (terms several contexts agree to share, e.g. `WeldSeam`) and **dependencies** (who consumes whose events/types).

Create files lazily — only when you have something to write. If no context `CONTEXT.md` exists, create one (plus its entry in `CONTEXT-MAP.md`) when the first term in that context is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

### Which context does this belong to?

When a term or decision lands, place it in the **one context** whose shared kernel it belongs to. If it's genuinely shared by several (a `WeldSeam` used by welding core, scanning, and orchestration), it lives in the **shared kernel** — record it once in each context that owns a piece, and note the relationship in `CONTEXT-MAP.md`. Don't duplicate a term into every context; cross-reference it.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in the relevant context's `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update the context glossary inline

When a term is resolved, update the relevant context's `CONTEXT.md` (`archive/contexts/<ctx>/CONTEXT.md`) right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

A context `CONTEXT.md` should be totally devoid of implementation details. Do not treat it as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else. (Resolved session outcomes and broader reference knowledge go to `archive/records/` and the context's `knowledge/` via the archive skills — never into the glossary.)

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
