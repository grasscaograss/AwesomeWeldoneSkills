---
name: opsx:reindex
description: Regenerate openspec/INDEX.md after specs or changes are modified. Use when: (1) a change has been archived and the index is stale; (2) new capabilities or specs were added; (3) user says "update index", "reindex openspec", "refresh INDEX.md", "index is out of date", "/opsx:reindex". Runs opsx:reindex/scripts/reindex.py to rebuild the capability index from current specs, active changes, and archived changes.
---

# OpenSpec Reindex

Regenerate `openspec/INDEX.md` after specs or changes are modified.

## When to Use

- After archiving a change (e.g. with `/opsx:archive`)
- After adding new capabilities or specs
- When the index appears stale or incomplete

## How to Run

Execute the bundled script:

```bash
python .agents/skills/opsx:reindex/scripts/reindex.py
```

## What It Does

1. Scans `openspec/specs/*/` for all capabilities and extracts the `## Purpose` line from `spec.md`
2. Queries `openspec list --json` for active changes and maps them to their delta specs
3. Scans `openspec/changes/archive/*/` for archived changes and maps them to their specs
4. Rebuilds `openspec/INDEX.md` with:
   - Categorized capability table (by domain: dual-arm, weld template, coarse positioning, etc.)
   - `[A]` = active changes, `[N]` = archived changes
   - Active changes summary table at the bottom
