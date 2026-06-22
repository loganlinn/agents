---
name: mise-expert
description: Expert guidance for working on the mise repository and mise CLI behavior. Use when Codex is asked to implement, debug, review, plan, or explain changes in github.com/jdx/mise, especially around tool backends, registry entries, version resolution, config parsing, tasks, e2e tests, docs, or GitHub/CI workflows for mise.
---

# Mise Expert

## Overview

Work as a mise repository specialist. Prefer the live repository guide over memory, verify behavior before asserting it, and call out weak assumptions early.

## First Moves

- If working in the local repo, start from `/Users/logan/src/github.com/jdx/mise`.
- Read `CLAUDE.md` or `AGENTS.md` before making changes; treat that file as authoritative and fresher than this skill.
- Use local source under `~/src` before web lookup. If a related repo is missing, suggest `ghq get <url>`.
- Inspect existing patterns near the target code before inventing abstractions.
- Before touching 2+ packages/projects, state the scope and why.

## Hard Stops

- Registry work: before touching `registry/`, ask whether the tool is already widely used outside the user's projects. Then actively check popularity data.
- Registry PRs need popularity evidence in the PR body: GitHub stars/forks, release activity, package downloads when relevant, and third-party usage.
- Do not add registry entries for self-written, personal, internal, niche, or low-popularity tools. Warn plainly that such PRs are likely to be rejected.
- Prefer registry backends in this order: `aqua:`, `github:`, `gitlab:`, then `conda:` only when needed. Avoid `npm:`, `pipx:`, `gem:`, `cargo:`, `go:`, and `dotnet:` unless the user confirms the maintainer wants that backend for the specific tool.
- Never propose new `asdf:` or `vfox:` registry entries. Never use `ubi:`.
- Do not assume semver. Treat versions as opaque unless the backend explicitly defines ordering.

## Version Resolution Rules

Use backend APIs for "latest", prefixes, channels, and installed-version matching:

- `Backend::latest_version`
- `Backend::latest_installed_version`
- `Backend::list_versions_matching`
- `Backend::list_installed_versions_matching`
- `ToolRequest::resolve`

Do not add new call sites that use `versions::Versioning::new(...)` or semver sorting to pick newest versions. Lockfile versions must be concrete strings; never write `latest`, `lts/*`, a prefix, or another non-concrete request into a lockfile.

## Common Workflows

For CLI/backend changes:

- Find the command in `src/cli/` and the backend logic in `src/backend/`, `src/toolset/`, or `src/plugins/core/`.
- Trace config loading through `src/config/` when behavior depends on `mise.toml`, `.tool-versions`, environment layering, or settings.
- Add focused e2e coverage under `e2e/` for user-visible CLI behavior.
- Use the repo's assertion helpers from `e2e/assert.sh`.
- Run e2e tests through `mise run test:e2e <test_filename>...`; do not execute test scripts directly.

For docs/settings/schema changes:

- Keep docs URL paths aligned with the `docs/` directory structure.
- For settings changes, update `settings.toml` and run the relevant render task, usually `mise run render:schema`.
- For CLI usage/completion changes, check whether `mise run render`, `mise run render:usage`, or `mise run render:completions` is needed.

For review or debugging:

- Lead with concrete findings and file/line evidence.
- Verify non-obvious runtime behavior by executing it.
- Before claiming a failure is pre-existing, verify on `main`. If there is no baseline, say so.
- Challenge assumptions around backend selection, version ordering, cross-platform behavior, config precedence, cache invalidation, and lockfile semantics.

## Verification Commands

Prefer the smallest command that exercises the changed behavior:

```sh
mise run build
mise run test:unit
mise run test:e2e e2e/<area>/<test_file>
mise run lint-fix
mise run lint
mise run ci
```

Use `MISE_DEBUG=1` or `MISE_TRACE=1` for mise debugging. Do not rely on `RUST_LOG` unless nearby code proves it is relevant.

## Commit And PR Conventions

- Use conventional commits.
- Use `registry: ...` for any `registry/` change, no scope.
- Use `task` as the scope for task-related changes, even if the code lives in `src/cli/run.rs` or `src/cmd.rs`.
- Draft external-facing content first and get user approval before posting.
- When posting GitHub comments for mise, include that the comment was AI-generated.
