# Dispatching Parallel Agents

When you have multiple unrelated failures, investigating sequentially wastes time. Each investigation is independent.

**Core principle:** Dispatch one agent per independent problem domain. Let them work concurrently.

## When to Use

**Use when:**
- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Each problem can be understood without context from others
- No shared state between investigations

**Don't use when:**
- Failures are related (fix one might fix others)
- Need full system state
- Agents would interfere with each other

## The Pattern

### 1. Identify Independent Domains
Group failures by what's broken.

### 2. Create Focused Agent Tasks
Each agent gets: specific scope, clear goal, constraints, expected output.

### 3. Dispatch in Parallel
All agents run concurrently.

### 4. Review and Integrate
Read summaries, check conflicts, run full suite, integrate.

## Agent Prompt Guidelines

- **Focused** — one clear problem domain
- **Self-contained** — all context needed
- **Specific output** — what should agent return
