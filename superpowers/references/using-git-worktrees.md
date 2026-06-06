# Using Git Worktrees

Ensure work happens in an isolated workspace.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to git.

## Step 0: Detect Existing Isolation

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

**If already in linked worktree:** Skip to project setup. Do NOT create another.

## Step 1: Create Isolated Workspace

### 1a. Native Worktree Tools (preferred)
Do you have a native tool (EnterWorktree, WorktreeCreate)? Use it.

### 1b. Git Worktree Fallback
**Directory priority:**
1. User-declared preference
2. Existing `.worktrees/` or `worktrees/`
3. Default to `.worktrees/`

**Safety:** Verify directory is gitignored before creating.

```bash
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

## Step 2: Project Setup

Auto-detect: `npm install` / `cargo build` / `pip install` / `go mod download`

## Step 3: Verify Clean Baseline

Run tests. If pass → ready. If fail → report, ask whether to proceed.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in worktree | Skip creation |
| Native tool available | Use it |
| No native tool | Git fallback |
| Not gitignored | Add to .gitignore first |
