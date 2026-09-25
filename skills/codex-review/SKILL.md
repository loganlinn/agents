---
name: codex-review
description: Perform a read-only, defect-first review of a code change and write structured findings to a JSON file. Use when reviewing uncommitted changes, a base-branch diff, a commit, or custom review instructions with the Codex review rubric.
---

# Codex Review

Inspect the requested target directly and return every finding that the author would likely fix.
Do not modify files, create commits, push branches, post review comments, or delegate the review
to another agent.

## Review the change

1. Read the applicable `AGENTS.md` instructions (or `AGENTS.override.md` if present) for the
   repository under review. Respect normal project-document precedence:
   `AGENTS.override.md`, then `AGENTS.md`, then configured fallback filenames.
2. Read the full review rubric in `references/rubric.md` — it defines the bug criteria, comment
   guidelines, priority levels, output schema, and formatting rules. Follow it exactly.
3. Inspect the complete diff for the requested target and enough surrounding code to understand
   each changed path.
4. Identify concrete regressions introduced by the change. Continue through the whole diff after
   finding the first issue.
5. Check the relevant tests and call sites to confirm that each finding is real and actionable.

### Target resolution

Determine what to review based on the user's request:

- **Uncommitted changes**: Review staged, unstaged, and untracked files.
  `git diff HEAD` plus `git status --short` for untracked files.

- **Base-branch diff**: Compare the changes that would actually merge rather than diffing
  directly against the branch tip. Resolve the comparison ref to the branch's upstream when that
  upstream exists and is ahead of the local branch; otherwise use the local branch. Run
  `git merge-base HEAD <comparison-ref>`, then inspect `git diff <merge-base-sha>`. If the local
  branch cannot be resolved, try its configured upstream explicitly before reporting that the
  target is unavailable.

- **Specific commit**: `git show <sha>` or `git diff <sha>^..<sha>` to isolate the commit's changes.

- **Custom instructions**: Follow the user's review instructions directly. If the instructions
  are empty, report that the review target is unavailable.

### What to flag

Flag an issue only when all of these are true:

- It affects correctness, security, performance, or maintainability in a meaningful way.
- It is discrete and actionable.
- It was introduced by the reviewed change.
- The affected scenario or call path can be demonstrated from the code.
- The author would probably fix it if they knew about it.

Do not flag speculative concerns, pre-existing problems, intentional behavior changes, or style
nits that do not obscure the code.

### Repository rule attribution

Use the root and scoped project instruction files applicable to changed files. More-specific
guidance wins on conflict, and user instructions about review scope or style take precedence.

Review the diff independently and deduplicate findings by changed location and defect/remedy. A
finding is rule-supported only when applicable guidance materially contributes repository-specific
scope, an invariant, remedy, convention, or confirmation behavior beyond generic correctness
advice. Preserve and union rule support when candidates merge, then check every final candidate
against the applicable rules. Do not omit ordinary findings or invent findings solely because a
rule file exists.

For each rule-supported final finding, verify the applicable project instruction file that
supplies the rule and its smallest supporting line range, then include one compact Markdown or
local-file reference in the finding body. Do not fabricate citations or add hidden metadata or
output fields.

### Priorities

Tag each finding title with a priority level:

- `[P0]` — Drop everything to fix. Blocking release, operations, or major usage. Only use for
  universal issues that do not depend on any assumptions about the inputs.
- `[P1]` — Urgent. Should be addressed in the next cycle.
- `[P2]` — Normal. To be fixed eventually.
- `[P3]` — Low. Nice to have.

Additionally, include a numeric `priority` field in the JSON output for each finding: `0` for P0,
`1` for P1, `2` for P2, `3` for P3. If a priority cannot be determined, omit the field or use `null`.

## Write the result

Write the complete review output as a single JSON object to a file. Do not print the JSON to the
chat or wrap it in prose. The file is the sole delivery channel for the structured review result.

### Output file

Default path: `review-result.json` in the repository root (or current working directory if not
in a repo). The user may specify a different path; honor it if given.

Write exactly one JSON object matching the schema in `references/rubric.md` (reproduced here for
reference):

```json
{
  "findings": [
    {
      "title": "<≤ 80 chars, imperative, prefixed with [P0]–[P3]>",
      "body": "<valid Markdown explaining why this is a problem; cite files/lines/functions>",
      "confidence_score": <float 0.0-1.0>,
      "priority": <int 0-3, optional>,
      "code_location": {
        "absolute_file_path": "<file path>",
        "line_range": {"start": <int>, "end": <int>}
      }
    }
  ],
  "overall_correctness": "patch is correct" | "patch is incorrect",
  "overall_explanation": "<1-3 sentence explanation justifying the overall_correctness verdict>",
  "overall_confidence_score": <float 0.0-1.0>
}
```

Rules:

- **Do not** wrap the JSON in markdown fences or extra prose in the file.
- The `code_location` field is required and must include `absolute_file_path` and `line_range`.
- Line ranges must be as short as possible for interpreting the issue (avoid ranges over 5–10
  lines; pick the most suitable subrange).
- The `code_location` should overlap with the diff.
- Do not generate a PR fix.
- If there are no qualifying findings, output an empty `findings` array — do not invent a finding
  to fill the result.
- After writing the file, print a short human-readable summary to the chat: the output file path,
  the number of findings, and the overall correctness verdict. Do not print the JSON itself.

### Comment guidelines (applied to each finding body)

1. Clear about why the issue is a bug.
2. Appropriately communicates severity — not more severe than it actually is.
3. Brief — at most 1 paragraph. No line breaks in natural language flow unless necessary for a
   code fragment.
4. No code chunks longer than 3 lines. Code chunks wrapped in markdown inline code tags or a
   code block.
5. Clearly communicates the scenarios, environments, or inputs necessary for the bug to arise.
   Immediately indicates that severity depends on these factors.
6. Matter-of-fact tone — not accusatory or overly positive. Reads as a helpful AI assistant
   suggestion without sounding too much like a human reviewer.
7. Written so the original author can immediately grasp the idea without close reading.
8. No excessive flattery. No "Great job ...", "Thanks for ...".

### Suggestion blocks

- Use `` ```suggestion `` blocks ONLY for concrete replacement code (minimal lines; no commentary
  inside the block).
- Preserve the exact leading whitespace of the replaced lines (spaces vs tabs, number of spaces).
- Do NOT introduce or remove outer indentation levels unless that is the actual fix.
