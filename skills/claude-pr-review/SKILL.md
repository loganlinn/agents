---
name: claude-pr-review
description: Request and complete a claude[bot] GitHub PR review loop. Use when the user asks to comment "@claude review" on a PR, wait for claude[bot] feedback, inspect actionable review comments, implement fixes, commit and push updates, and reply to PR review comments with decisions or actions taken.
---

# Claude PR Review Loop

Drive the full `claude[bot]` PR review cycle without losing review-thread context or mutating unrelated work.

Invoking this skill authorizes the PR comments required for the review loop: the initial `@claude review` comment and follow-up replies to PR feedback. Post these comments without drafting them for separate user approval. This authorization does not extend to unrelated PR comments, resolving threads, approving the PR, or submitting a review.

## Workflow

1. Resolve the PR and current branch.
   - Run `gh auth status` first; if auth fails, ask the user to authenticate.
   - Use `gh pr view --json number,url,headRefName,baseRefName,title` for the active branch unless the user gave a PR number or URL.
   - Run `git status --short --branch` and preserve unrelated dirty or untracked files.

2. Trigger the bot review only when the user explicitly requested it.
   - Post exactly: `gh pr comment <pr> --body '@claude review'`.
   - Do not ask for separate approval before posting; invoking this skill is sufficient authorization.
   - Record the comment URL and approximate trigger time.

3. Wait for `claude[bot]`.
   - Poll `gh pr view <pr> --json comments,reviews` every 20-30 seconds.
   - Treat an eyes reaction on the trigger comment as acknowledgement, not completion.
   - Continue until a new comment or review by `claude[bot]` appears after the trigger time.
   - If no review appears after a reasonable wait, report that the bot did not post yet instead of inventing feedback.

4. Read feedback thread-aware.
   - For top-level bot comments, `gh pr view --json comments,reviews` is enough.
   - For inline comments, use GraphQL review threads so resolution, outdated state, file path, line, and replies are preserved:

```bash
gh api graphql \
  -F owner='<owner>' \
  -F repo='<repo>' \
  -F number='<pr-number>' \
  -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:20) {
            nodes {
              id
              databaseId
              author { login }
              body
              url
              createdAt
            }
          }
        }
      }
    }
  }
}'
```

5. Classify before editing.
   - Actionable: concrete bug, regression risk, missing test, unclear behavior that should change.
   - Response-only: valid question or design tradeoff where code should not change.
   - Ignore: stale, outdated, duplicate, or non-actionable praise.
   - If comments conflict or would widen scope materially, pause and ask the user.

6. Implement only actionable feedback.
   - Keep edits scoped to the reviewed change.
   - Use existing repo patterns and preserve unrelated user work.
   - Run focused verification; broaden only when shared behavior or blast radius requires it.

7. Commit and push.
   - Stage only files changed for the review feedback.
   - Prefer a focused follow-up commit unless the user asked to amend or squash.
   - Push the PR branch after tests pass.

8. Reply to comments.
   - Address PR replies back to `claude[bot]` by starting each posted response with `@claude`.
   - Post review-loop replies without asking for separate approval; invoking this skill is sufficient authorization.
   - Reply to each actionable thread with what changed and what verification ran.
   - For response-only feedback, explain the decision briefly and concretely.
   - Do not resolve threads, approve the PR, or submit a review unless the user explicitly asks.

## Reply Style

Use short, factual PR replies:

```md
@claude Fixed in <commit>: <what changed>. Verified with `<command>`.
```

```md
@claude Leaving this as-is because <reason>. The contract here is <specific boundary>.
```
