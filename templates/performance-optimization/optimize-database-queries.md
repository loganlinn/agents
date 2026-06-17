# Optimize Database Queries

> Source: [Devin Docs — Prompt Templates Cheat Sheet](https://docs.devin.ai/essential-guidelines/prompt-templates-cheat-sheet)

```
Optimize the database queries in `[file/module]`.

Performance issues:
- `[Specific query]` is slow (takes `[time]`)
- `[Specific operation]` causes N+1 queries

Please:
1. Analyze the query execution plans
2. Add appropriate indexes to `[table/column]`
3. Refactor queries to use joins instead of N+1
4. Benchmark before and after performance
5. Ensure all tests still pass
6. Document the performance improvements
```
