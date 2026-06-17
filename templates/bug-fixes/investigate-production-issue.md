# Investigate Production Issue

> Source: [Devin Docs — Prompt Templates Cheat Sheet](https://docs.devin.ai/essential-guidelines/prompt-templates-cheat-sheet)

```
Users are reporting `[describe the issue]` in production.

Please:
1. Use the `[Sentry/DataDog/Log monitoring tool]` MCP to pull recent error logs and stack traces
2. Identify the root cause of the issue
3. Implement a fix
4. Add appropriate error handling to prevent similar issues
5. Create a regression test
6. Link the monitoring/alert in the PR description
```
