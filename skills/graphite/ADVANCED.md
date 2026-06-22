# Advanced Graphite: Surgical Rebasing & Recovery

Reference this file when `gt restack` fails, conflicts arise in unrelated branches, or gt metadata is corrupted.

## Surgical Rebasing in Complex Stacks

In deeply nested stacks with many sibling branches, `gt restack` can be problematic:

- It restacks ALL branches that need it, not just your stack
- Can hit conflicts in completely unrelated branches
- Is all-or-nothing - hard to be surgical

### When to Use `git rebase` Instead of `gt restack`

Use direct `git rebase` when:

- You only want to update specific branches in your stack
- `gt restack` is hitting conflicts in unrelated branches
- You need to skip obsolete commits during the rebase

### Targeted Rebase Workflow

```bash
# 1. Checkout the branch you want to rebase
git checkout my-feature-branch

# 2. Rebase onto the target (e.g., updated parent branch)
git rebase target-branch

# 3. If you hit conflicts:
#    - Resolve the conflict in the file
#    - Stage it: git add <file>
#    - Continue: git rebase --continue

# 4. If a commit is obsolete and should be skipped:
git rebase --skip

# 5. After rebase, use gt modify to sync graphite's tracking
gt modify --no-edit --no-interactive
```

### Recovering from Interrupted Rebase (Context Reset)

If a rebase was interrupted (e.g., Claude session ran out of context):

1. **Check status:**

   ```bash
   git status
   # Look for "interactive rebase in progress" and "Unmerged paths"
   ```

2. **Read the "unmerged" files** - they may already be resolved (no conflict markers)

3. **If already resolved, just stage and continue:**

   ```bash
   git add <resolved-files>
   git rebase --continue
   ```

4. **If still has conflict markers**, resolve them first, then stage and continue

### Deleting Branches from a Stack

```bash
# Delete a branch (non-interactive, even if not merged)
gt delete branch-to-delete -f -q

# Also delete all children (upstack)
gt delete branch-to-delete -f -q --upstack

# Also delete all ancestors (downstack)
gt delete branch-to-delete -f -q --downstack
```

**Flags:**

- `-f` / `--force`: Delete even if not merged or closed
- `-q` / `--quiet`: Implies `--no-interactive`, minimizes output

**After deleting intermediate branches**, children are automatically restacked onto the parent. If you need to manually update tracking:

```bash
gt checkout child-branch --no-interactive
gt track --parent new-parent-branch --no-interactive
```

---

## Debugging

```bash
gt ls --no-interactive                    # Branch in stack?
gt branch info <branch> --no-interactive  # Parent, children, PR
```

### Recovery from Corrupted State

```bash
# Nuclear option: re-initialize (loses stack relationships)
rm .git/.graphite_cache_persist
gt repo init --no-interactive

# Re-track branches manually
gt track --branch feature-1 --parent main --no-interactive
gt track --branch feature-2 --parent feature-1 --no-interactive
```
