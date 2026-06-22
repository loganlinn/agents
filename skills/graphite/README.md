# Graphite Skill

Based on the [official Graphite agent skill](https://github.com/withgraphite/agent-skills/blob/main/skills/graphite/SKILL.md), customized for this repo.

## Design Decisions

- **`--no-interactive` on every command.** From [dagster-io/erk](https://github.com/dagster-io/erk). Any gt command can hang in agent context without it. `--force` alone does not prevent prompts.
- **`allowed-tools` uses scoped globs** (`Bash(gt *)`, `Bash(git add *)`) not blanket `Bash`. This is additive (pre-approves without prompting), not restrictive — [docs](https://docs.anthropic.com/en/docs/claude-code/skills).
- **`description` is one sentence.** Combined `description` + `when_to_use` is [capped at 1,536 chars](https://docs.anthropic.com/en/docs/claude-code/skills) and loaded into every conversation. Keyword stuffing wastes budget without improving match rate.
- **PR splitting is cost-aware.** Not "always more PRs" — each PR has real cost (CI, AI review, merge queue, reviewer fatigue). Mechanical sweeps stay as one PR.
- **Branch naming matches repo convention** (`{author}/{kebab-case-description}`), not the upstream `stack-name/description` pattern.
- **Advanced content broken out to `ADVANCED.md`** (surgical rebasing, debugging, recovery). Only loaded when things go wrong — saves ~400 words from the main skill context.
- **Env vars (`GRAPHITE_DISABLE_TELEMETRY`, `GRAPHITE_INTERACTIVE`) live in `settings.json`**, not the skill body. Infrastructure beats instructions the agent can forget.
