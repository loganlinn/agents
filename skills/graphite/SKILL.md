---
name: graphite
description: Work with Graphite (gt) for stacked PRs - creating, navigating, and managing PR stacks.
allowed-tools:
  - "Bash(gt *)"
  - "Bash(git add *)"
  - "Bash(git reset *)"
  - "Bash(git diff *)"
  - "Bash(git status *)"
  - "Bash(git stash *)"
  - "Bash(git checkout *)"
  - "Bash(git rebase *)"
  - "Bash(git branch *)"
  - "Bash(gh pr *)"
  - "Bash(gh api *)"
---

# Graphite Skill

Work with Graphite (`gt`) for creating, navigating, and managing stacked pull requests.

## Detection

Check for `.git/.graphite_repo_config` to determine if a repo uses Graphite:

- **File exists:** Use `gt` commands (this skill applies)
- **File does not exist:** Use standard `git` commands (this skill does NOT apply)

## CRITICAL: Always Use `--no-interactive`

**Every `gt` command must include `--no-interactive`.** This is a global flag, not per-command. Without it, gt may open prompts, pagers, or editors that hang indefinitely in agent contexts. `--force` does NOT prevent prompts.

## Quick Reference

| I want to...            | Command                                               |
| ----------------------- | ----------------------------------------------------- |
| Create a new branch/PR  | `gt create branch-name -m "message" --no-interactive` |
| Amend current branch    | `gt modify -m "message" --no-interactive`             |
| Navigate up the stack   | `gt up --no-interactive`                              |
| Navigate down the stack | `gt down --no-interactive`                            |
| Jump to top of stack    | `gt top --no-interactive`                             |
| Jump to bottom of stack | `gt bottom --no-interactive`                          |
| View stack structure    | `gt ls --no-interactive`                              |
| Submit stack for review | `gt submit --no-interactive --ai --no-edit`           |
| Rebase stack on trunk   | `gt restack --no-interactive`                         |
| Change branch parent    | `gt track --parent <branch> --no-interactive`         |
| Rename current branch   | `gt rename <new-name> --no-interactive`               |
| Move branch in stack    | `gt move --no-interactive`                            |
| Pull someone's stack    | `gt get <branch-or-PR#> --no-interactive`             |

---

## What Makes a Good PR?

Each PR has real cost: CI runs, AI code review, merge queue, reviewer context-switching. Split when it helps reviewers reason about the change; don't split when it just multiplies overhead.

**Split when:**

- Changes are logically independent — different concerns, different reviewers, different risk profiles
- A large feature has natural seams (data model, API, UI) that are each meaningful on their own

**Keep together when:**

- A mechanical/sweeping change (formatter rule, rename, dependency bump) touches many files but is one logical operation — splitting it across PRs creates N reviews of the same trivial diff
- Splitting would produce PRs that are meaningless in isolation (e.g. "add unused import" as its own PR)

**In all cases:** each PR must be atomic (pass CI, safe to deploy independently) and have narrow semantic scope.

---

## Branch Naming Conventions

Branches follow `{author}/{kebab-case-description}`:

```
alice/fix-auth-token-refresh
bob/fonts-require-custom-fonts-feature
carol/m-337-homepage-prompt-box-ab-test
```

When a Linear ticket is provided, prefix the description with the lowercased ticket ID:

```
alice/inf-76-openapi-spec-ci-pipeline
bob/sec-115-hocuspocus-auth
```

For stacks, keep the author prefix and give each branch a distinct description — no nested slash grouping:

```
alice/auth-bugfix-reorder-args
alice/auth-bugfix-improve-logging
alice/auth-bugfix-handle-401
```

---

## Creating a Stack

### Basic Workflow

1. Make changes to files
2. Stage changes: `git add <files>`
3. Create branch: `gt create branch-name -m "commit message" --no-interactive`
4. Repeat for each PR in the stack
5. Submit: `gt submit --no-interactive --ai --no-edit`

### Handle Untracked Branches (common with worktrees)

Before creating branches, check if the current branch is tracked:

```bash
gt branch info --no-interactive
```

If you see "ERROR: Cannot perform this operation on untracked branch":

**Option A (Recommended): Track temporarily, then re-parent**

1. Track current branch: `gt track -p main --no-interactive`
2. Create your stack normally with `gt create`
3. After creating ALL branches, re-parent your first new branch onto main:
   ```bash
   gt checkout <first-branch-of-your-stack> --no-interactive
   gt track -p main --no-interactive
   gt restack --no-interactive
   ```

**Option B: Stash changes and start from main**

1. `git stash`
2. `git checkout main && git pull`
3. Create your branch directly: `git checkout -b <branch-name> && git stash pop`
4. Track it: `gt track -p main --no-interactive`
5. Stage and create: `git add <files>` then `gt create <branch-name> -m "message" --no-interactive`

---

## Navigating a Stack

```bash
gt up --no-interactive
gt down --no-interactive
gt top --no-interactive
gt bottom --no-interactive
gt ls --no-interactive
```

---

## Modifying a Stack

### Amend Current Branch

```bash
git add <files>
gt modify -m "message" --no-interactive
```

### Reorder Branches

Use `gt move --no-interactive` to reorder branches in the stack. This is simpler than trying to use `gt create --insert`.

### Re-parent a Stack

If you created a stack on top of a feature branch but want it based on main:

```bash
gt checkout <first-branch> --no-interactive
gt track --parent main --no-interactive
gt restack --no-interactive
```

### Rename a Branch

```bash
gt rename new-branch-name --no-interactive
```

---

## Resetting Commits to Unstaged Changes

If changes are already committed but you want to re-stack them differently:

```bash
# Reset the last commit, keeping changes unstaged
git reset HEAD^

# Reset multiple commits (e.g., last 2 commits)
git reset HEAD~2

# View the diff to understand what you're working with
git diff HEAD
```

---

## Before Submitting

### Verify Stack is Rooted on Main

Before running `gt submit`, verify the first PR is parented on `main`:

```bash
gt ls --no-interactive
```

If the first branch has a parent other than `main`:

```bash
gt checkout <first-branch> --no-interactive
gt track -p main --no-interactive
gt restack --no-interactive
```

### Run Validation

After creating each PR, run appropriate linting, building, and testing:

1. Refer to the project's CLAUDE.md for specific commands
2. If validation fails, fix the issue, stage changes, and use `gt modify --no-interactive`

---

## Submitting and Updating PRs

### Submit the Stack

```bash
gt submit --no-interactive --ai --no-edit
```

**Useful flags:**

- `--reviewers alice,bob` — request individual reviewers (comma-separated, not repeatable)
- `--team-reviewers frontend,platform` — request team reviewers (comma-separated, not repeatable)
- `--draft` — open PRs in draft mode

**Do NOT enable auto-merge on your own.** Never pass `--merge-when-ready` (or run `gh pr merge --auto`, `gt merge`, etc.) unless the user explicitly asks for it in this turn. Auto-merge ships code without further human review the moment checks pass — that's the user's call, not the agent's. A prior approval to auto-merge one PR does not carry over to later PRs.

**When the user requests reviewers** (e.g. "have the backend team review", "ask Alice to review"):

1. **Resolve to verified GitHub identifiers before submitting.** Never pass unverified names.
   - Individual: `gh api /repos/{owner}/{repo}/collaborators/{login} --silent` (200 = has access)
   - Team: `gh api /orgs/{org}/teams/{slug} --silent` (200 = exists)
2. **Disambiguate user vs. team.** If unclear, check both — ask the user if it matches both. Never use `--reviewers` for a team slug or `--team-reviewers` for a user login.
3. **If a name doesn't resolve**, stop and ask. Do not guess, do not attempt to grant access, do not invite collaborators.

### Update PR Descriptions

After submitting, use `gh pr edit` to set proper titles and descriptions.

**IMPORTANT:** Never use Bash heredocs for PR descriptions - shell escaping breaks markdown tables, code blocks, etc. Instead:

1. Use the `Write` tool to create `/tmp/pr-body.md` with the full markdown content
2. Use `gh pr edit` with `--body-file`:

```bash
gh pr edit <PR_NUMBER> --title "stack-name: description" --body-file /tmp/pr-body.md
```

PR descriptions must include:

- **Stack Context**: What is the bigger goal of this stack?
- **What?** (optional for small changes): Super terse, focus on what not why
- **Why?**: What prompted the change? Why this solution? How does it fit into the stack?

**Example** (for the first PR in a multi-PR stack):

```markdown
## Stack Context

This stack adds <feature> by introducing <data model change>, exposing it through <API surface>,
and surfacing it in <UI>.

## Why?

<One or two sentences on the motivation — what user-facing problem or constraint prompted this.>
This PR is the foundation: it adds the <type/field/migration> that the later PRs in the stack
build on.
```

---

## Collaborating on Someone Else's Stack

Use `gt get` to pull a teammate's stack locally:

```bash
gt get their-branch-name --no-interactive
gt get 1234 --no-interactive          # by PR number
```

Fetched branches are **frozen** by default — you can read, review, and navigate them but local edits are blocked. This prevents accidental modifications to branches you don't own.

```bash
gt get their-branch --unfrozen --no-interactive   # fetch editable from the start
gt unfreeze --no-interactive                       # unfreeze current branch after fetching
gt freeze --no-interactive                         # re-freeze when done editing
```

**When to freeze/unfreeze:**

- **Keep frozen** when reviewing, testing, or rebasing your own work on top of their stack
- **Unfreeze** when the owner asks you to push fixes to their branch, or when pair-programming on a shared stack

---

## Troubleshooting

| Problem                                             | Solution                                                                           |
| --------------------------------------------------- | ---------------------------------------------------------------------------------- |
| "Cannot perform this operation on untracked branch" | Run `gt track -p main --no-interactive` first                                      |
| Stack parented on wrong branch                      | Use `gt track -p main --no-interactive` then `gt restack --no-interactive`          |
| Need to reorder PRs                                 | Use `gt move --no-interactive`                                                     |
| Conflicts during restack                            | Resolve conflicts, then `gt continue -a --no-interactive`                          |
| Want to split a PR                                  | Reset commits (`git reset HEAD^`), re-stage selectively, create new branches       |
| Need to delete a branch (non-interactive)           | `gt delete <branch> -f -q`                                                         |
| `gt restack` hitting unrelated conflicts            | Use targeted `git rebase` — see @.claude/skills/graphite/ADVANCED.md               |
| Rebase interrupted mid-conflict                     | See recovery steps in @.claude/skills/graphite/ADVANCED.md                         |

---

## Conflict Resolution

When `gt sync` or `gt restack` hits conflicts:

1. **Understand what conflicted** - check which branch and what files
2. **Check what each branch does** - use `gt log` and review the changes
3. **Auto-resolve obvious conflicts:**
   - Import order changes
   - Whitespace differences
   - Non-overlapping additions
   - Lock file conflicts: accept either version, regenerate (`yarn install`), and stage
4. **Ask about ambiguous conflicts:**
   - Same code modified differently
   - Deleted vs modified conflicts
   - Semantic conflicts (logic changes)
   - Test expectation changes

After resolving: `gt continue -a --no-interactive`. If stuck: `gt abort --no-interactive`.

---

## Programmatic Parent Resolution

Use `gt parent` — never parse `gt log short` output.

```bash
parent=$(gt parent --no-interactive)
git diff "$parent...HEAD"
```

---

## Advanced Rebasing, Debugging & Recovery

For surgical rebasing (when `gt restack` hits unrelated conflicts), branch deletion, corrupted metadata recovery, and interrupted rebase recovery, see @.claude/skills/graphite/ADVANCED.md.

---

## Context Efficiency

For commands that produce verbose output (`gt log`, `gt ls`, `gt diff`, large `git status`), delegate to a subagent to avoid polluting the main conversation context. The main context should be reserved for judgment calls — conflict resolution, stack planning, PR descriptions — not command output.
