# Finishing a Development Branch

Guide completion by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

## Step 1: Verify Tests

```bash
npm test / cargo test / pytest / go test ./...
```

If fail → stop. Don't proceed.

## Step 2: Present Options

```
1. Merge back to <base> locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work
```

## Step 3: Execute Choice

**Option 1 — Merge locally:**
```bash
git checkout <base> && git pull && git merge <branch>
# Verify tests, delete branch
```

**Option 2 — Create PR:**
```bash
git push -u origin <branch>
gh pr create --title "<title>" --body "<body>"
```

**Option 3 — Keep as-is:** Report branch and worktree location.

**Option 4 — Discard:** Require typed confirmation. Then delete.

## Step 4: Cleanup Worktree

For Options 1, 2, 4: Remove worktree.
For Option 3: Keep worktree.
