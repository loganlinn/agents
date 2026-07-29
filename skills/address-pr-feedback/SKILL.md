---
name: address-pr-feedback
description: Report or close out PR review feedback across a branch stack. Reports outstanding feedback and review-request status read-only; on an explicit request to address feedback, also lands the fixes that need no judgment, replies, resolves, re-requests review, and reports what needs the user's call. Use when the user asks what review feedback is outstanding on a PR or stack, or asks to address, handle, or clear PR review comments.
---

# Address PR feedback

Two modes. Pick one before doing anything, and say which you picked.

**Status** — the user asked a question: what is outstanding, where does the stack stand, is anything blocking. Read-only. Run steps 1–2, print the report, stop. No commits, no replies, no resolves, no rebase.

**Address** — the user explicitly asked to address, handle, fix, or clear feedback. Runs every step.

A question is Status. Ambiguity is Status. Address needs an actual instruction to change something — the cost of guessing wrong is public comments on someone else's PR and rewritten local history, so the quiet mode is the default.

## Standing authorization

**In Address mode only**, the user has pre-approved you to post, without asking:

- `Addressed <sha>` replies on threads you actually fixed
- factual "no longer applies" replies on **Stale** threads
- resolving those threads
- re-requesting review
- syncing the worktree onto the PR's base by rebase or fast-forward

Everything a reviewer will read for its argument — rebuttals, disagreement, explanation of intent, PR description edits — is drafted in the report and posted only after the user approves.

**Rebase, never merge.** A merge commit needs approval every time. `git rebase`, `git pull --rebase`, and `git merge --ff-only` are the only integrations you run unattended.

**Relocating the work also needs approval, every time.** Do the work in the worktree you were started in. A separate worktree, a fresh clone, a scratch branch, or `git stash` all leave the user looking at a different state of the world than the reviewer sees, and that disconnect is the thing this skill must never create. When the worktree's state makes you want to move, say so in one line, name the state that prompted it, and wait.

## Dispositions

Every thread lands in exactly one bucket. Before choosing, **verify**: read the code the thread points at, plus whatever it depends on. A reviewer's claim is a hypothesis, and its confidence is not evidence — a fluent, well-structured comment can still be wrong about the code.

**Every comment is a colleague's.** Some reviewers draft with tooling, but a person put their name on it and a person reads your reply. Treat all feedback as human-authored and human-reviewed, whatever it looks like. Calling a comment automated is both an assumption you cannot check and a licence to dismiss it — so the question is never who wrote it, only whether the code bears it out.

**Apply** — all four hold:

1. the claim checks out against the code
2. exactly one reasonable fix exists, and you can say why it is the only one
3. the fix stays inside the PR's changed files, and every file it touches is clean in the worktree — the user's uncommitted hunks and yours cannot be separated safely in one file
4. you can verify the result, or it is prose whose correctness you just confirmed by reading

**Stale** — the premise no longer holds: the code moved, the line is gone, or another thread already covers it. Reply with the evidence and resolve.

**Push back** — the claim is factually wrong, or the remedy costs more than the defect it removes. Draft the rebuttal and leave the thread unresolved and unanswered. Write it to the colleague who will read it: open with the evidence that settles it, cite the file, line, or doc that shows it, keep it to a few sentences, and leave the door open where the point is arguable.

**Escalate** — the concern is real, but the fix turns on a decision the user owns: scope, product behavior, risk tolerance, an assumption you cannot verify, or a change that reaches outside this PR.

When a thread fails an **Apply** condition, it is **Escalate** — not a best guess. Changing code to satisfy a claim you did not verify is the failure this skill exists to prevent; so is a fix that quietly grows past what the thread asked for.

Threads where the user already replied last (`awaitingReviewer: true`) are the reviewer's move. Leave them untouched and list them in the report.

## Steps

Resolve the script directory once:

```bash
for d in ~/.claude/skills ~/.agents/skills ~/src/github.com/loganlinn/agents/skills; do
  [ -d "$d/address-pr-feedback/scripts" ] && S="$d/address-pr-feedback/scripts" && break
done
```

### 1. Collect

```bash
"$S/collect.sh" [pr-number|url|branch]
```

Read-only. Defaults to the current branch's PR. Emits PR state, `repo`, `changedFiles`, every review thread with `id`/`isResolved`/`isOutdated`/`awaitingReviewer`/`hasSuggestion`, each reviewer's latest review state, review summary bodies, top-level comments, and `stack.tool` when the user has posted a stacking-tool comment.

Two fields gate everything downstream:

- **`incomplete`** non-empty means a connection was cut off and a triage decision could rest on truncated data. Report it and stop.
- **`repoMatchesWorktree: false`** means the PR lives in a different repo than the worktree. Status mode continues; Address mode stops, because fixes would land in the wrong tree.

Read the PR description and the diff too — feedback is judged against what the PR set out to do.

### 2. Survey the stack

```bash
"$S/stack.sh" --repo <owner/repo> --pr <n>
```

Walks base/head links on GitHub — not a stacking tool's local metadata — so it covers Graphite, git-spice, and hand-built stacks alike, and reflects what reviewers see. Returns each PR bottom-to-top with `unresolved`, `needsYou`, `reviewDecision`, `changesRequestedBy`, and `requestedReviewers`.

You act on the target PR only. Sibling PRs are situational awareness: each lives on a different branch, and touching one would mean the relocation that needs approval. Report them; leave them alone.

**Status mode ends here.** Print the report and stop.

### 3. Sync the worktree

**The PR's `baseRefName` is the base.** Never assume trunk — on a stack the base is the parent branch, and rebasing onto `main` instead would absorb every sibling's commits.

**A stack comment on the PR means a tool owns this branch.** Load that tool's skill before any branch operation and use its restack command; the tool holds parent metadata a bare `git rebase` leaves stale. When no skill matches, say so and use the tool's own CLI rather than reaching around it. Preflight reports `localStackTool` from repo config as an independent reading — when the two disagree, that is a blocker: the tool is not initialized where you are standing.

```bash
"$S/preflight.sh" --head <headRefName> --base <baseRefName>
```

Fetches origin, then reports gaps to base and upstream, `rebaseable`, `blockers`, and a structured `sync` object. It returns an **action name and ref fields, never a command string** — ref names are attacker-controlled on a fork PR and git permits `$`, `(`, and `)` in them. Refs outside a safe charset are refused outright and land in `unsafeRefNames`.

| `sync.action`          | What to run                                                                 |
| ---------------------- | --------------------------------------------------------------------------- |
| `none`                 | nothing                                                                       |
| `fast-forward`         | `git merge --ff-only <sync.upstreamRef>` — no merge commit                    |
| `rebase-onto-upstream` | `git pull --rebase origin <branch>`                                           |
| `rebase-onto-base`     | the stacking tool's restack, else `git rebase <sync.baseRef>`                 |
| `blocked`              | stop                                                                          |

**Stop the moment syncing fails.** A `blocked` action, a non-empty `blockers` list, a conflicted rebase, a restack error — all mean this head will need reconciling with the remote later, and every commit you add first makes that worse. Abort a failed rebase so the worktree is exactly as you found it, then report and wait.

Uncommitted work in unrelated files is fine while nothing needs syncing. Once a sync is required it stops being fine, because a rebase will not run against a dirty tree — and clearing that tree is the user's call.

### 4. Triage before editing

Assign a disposition to every open item, with a one-line reason, **before** changing any file. Triaging as you fix biases you toward fixing.

### 5. Land the Apply set

- `hasSuggestion` threads carry the reviewer's exact patch — apply it verbatim when it is right, and treat rewriting it as a divergence to note in the reply.
- Verify each touched package with the repo's documented single verification command (in gamma: `cd packages/<pkg> && yarn lint:fix`; for Terraform roots: `terraform fmt`, and `terraform validate` where already initialized). If nothing can verify a change, land it and mark it `unverified` in the report.
- Stage by explicit path — `git add <file> …` — so the user's other working-tree changes stay out. Re-run preflight before committing and confirm the staged set is exactly the files you edited.
- Commit in the repo's message convention. One commit per concern; each thread's reply cites the sha that contains its fix.
- Push with plain `git push`.

Guardrails:

- **Rewrite history before you cite it, never after.** Step 3 is where rebasing and restacking belong — no sha is published yet, so rewriting there costs nothing. From your first commit onward the branch is append-only: no amend, no rebase, no force-push, because the replies you are about to post cite shas.
- A rejected push means the branch moved while you worked. Stop before replying, leave the threads as they were, and report it.
- On a stacked branch, push this one plainly and **report** children needing restack rather than restacking them.

### 6. Close the loops

```bash
# Apply — fixed in a commit
"$S/respond.sh" --repo <owner/repo> --pr <n> --thread <PRRT_id> --sha <sha> [--note "<one sentence>"] --resolve

# Stale — no code change
"$S/respond.sh" --repo <owner/repo> --pr <n> --thread <PRRT_id> --note "<why it no longer applies>" --resolve
```

The script builds the body, strips backticks so GitHub auto-links the sha, and **proves against GitHub that the cited commit is the PR head or an ancestor of it** before posting — "contained by some remote branch" never meant "present in this PR". It resolves only after the reply lands. Add `--dry-run` to preview.

Use `--note` when the fix diverges from what the reviewer suggested. Resolve only when a thread's feedback is fully addressed; a thread with one fixed point and one escalated point stays open.

For feedback in a review summary body or top-level comment, acknowledge with a single `gh pr comment` in the same form.

### 7. Re-request review

For each reviewer whose latest review is `CHANGES_REQUESTED`, once every thread they authored is resolved and none awaits a pushback draft:

```bash
gh api --method POST repos/<owner>/<repo>/pulls/<n>/requested_reviewers -f 'reviewers[]=<login>'
```

REST adds to the reviewer set. (The `requestReviews` GraphQL mutation replaces it unless you pass `union: true`.) A few reviewer logins are rejected here; note the failure rather than retrying.

### 8. Report

One message. No preamble, no recap of the diff, no narration of steps taken. Lead with what the user must act on; everything closed gets one line.

```
**PR #<n> — <title>** · <mode>
<x>/<y> threads closed. <a> need your call, <b> pushback drafted.

## Stack
| PR | branch | unresolved | needs you | review |
|----|--------|-----------|-----------|--------|
| #<n> | <head> | 2 | 2 | changes requested (dinedal) |
| → #<n> | <head> | 1 | 0 | approved |

## Needs your call
1. **<file>:<line>** — <claim in one line> · <link>
   Verified: <what you checked>
   Fork: <A> vs <B> → recommend <one, why>

## Pushback drafts (not posted)
1. **<file>:<line>** — <claim> · <link>
   Wrong because: <evidence>
   > <exact reply text>

## Landed — <sha>
- <file>:<line> — <what changed> [unverified]

## Closed without a change
- <file>:<line> — <why>

## Waiting on reviewer
- <file>:<line> — you replied <date>

## State
Base · how the worktree synced · stacking tool · children needing restack · conflicts · failures

Reply `post` to send the pushback drafts.
```

Rules: omit empty sections. Mark the target PR with `→` in the stack table, and include the table only when the stack has more than one PR. Every claim names file, line, and what you checked — no thread is called handled without saying how. In Status mode, only the stack table, the outstanding items, and State apply.
