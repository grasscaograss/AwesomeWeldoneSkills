---
name: opsx-search
description: Search and navigate OpenSpec documents in this project. Use when: (1) user asks about specs related to a topic, capability, or code file; (2) looking for which specs define a feature or requirement; (3) finding active or archived changes; (4) understanding the scope of a capability. Triggers: "find spec", "which spec covers", "search openspec", "related specs", "spec for X", "what specs exist for".
---

# OpenSpec Search

Search and navigate the project's OpenSpec documentation.

## Directory Structure

```
openspec/
├── INDEX.md              # Capability index (READ THIS FIRST)
├── specs/<capability>/   # 78 stable capability specs
│   └── spec.md
├── changes/<change>/     # 17 active changes
│   ├── .openspec.yaml
│   ├── proposal.md       # Why / What / Impact
│   ├── design.md         # Decisions / Risks
│   ├── tasks.md          # Implementation checklist
│   └── specs/<cap>/spec.md  # Delta specs
└── changes/archive/      # 107 completed changes
```

## Search Patterns

### 1. Quick lookup by topic
Read `openspec/INDEX.md` first. It groups all 78 capabilities by domain with one-line summaries.

### 2. Find specs mentioning a code file/class
```
grep -r "WeldUnrecognized" openspec/*/proposal.md openspec/specs/*/spec.md
```

### 3. Find specs by keyword
```
grep -ri "粗定位" openspec/specs/*/spec.md
```

### 4. List active changes with status
```
openspec list --json
```

### 5. Read a specific capability's full spec
```
openspec/specs/<capability-name>/spec.md
```

### 6. Read a change's motivation and impact
```
openspec/changes/<change-name>/proposal.md
```

## Workflow

1. **Start with INDEX.md** — locate relevant capability names
2. **Read the spec.md** for detailed requirements and scenarios (BDD: WHEN/THEN)
3. **Check proposal.md** of related changes for motivation and code impact
4. **Cross-reference** — use grep to find connections between specs and code
