---
name: clickhouse-best-practices
description: MUST USE when reviewing ClickHouse schemas, queries, or configurations. Contains 31 rules that MUST be checked before providing recommendations. Always read relevant rule files and cite specific rules in responses.
license: Apache-2.0
metadata:
  author: ClickHouse Inc
  version: "0.4.0"
---

# ClickHouse Best Practices

Comprehensive guidance for ClickHouse covering schema design, query optimization, data ingestion, and AI agent connectivity. Contains 31 rules across 4 main categories (schema, query, insert, agent), prioritized by impact.

> **Official docs:** [ClickHouse Best Practices](https://clickhouse.com/docs/best-practices)

## IMPORTANT: How to Apply This Skill

**Before answering ClickHouse questions, follow this priority order:**

1. **Check for applicable rules** in the `references/` directory
2. **If rules exist:** Apply them and cite them in your response using "Per `rule-name`..."
3. **If no rule exists:** Use the LLM's ClickHouse knowledge or search documentation
4. **If uncertain:** Use web search for current best practices
5. **Always cite your source:** rule name, "general ClickHouse guidance", or URL

**Why rules take priority:** ClickHouse has specific behaviors (columnar storage, sparse indexes, merge tree mechanics) where general database intuition can be misleading. The rules encode validated, ClickHouse-specific guidance.

---

## Agent Connectivity & Query Workflow

Before querying ClickHouse, agents must establish a connection and follow the discovery workflow:

1. `references/agent-connect-mcp.md` - Connection setup (MCP + CLI), credential discovery, output format selection
2. `references/agent-discovery-schema.md` - **CRITICAL**: 7-step schema discovery workflow
3. `references/agent-query-safety.md` - **CRITICAL**: LIMIT, timeouts, progressive exploration

**Every agent session should follow this sequence:**

1. **Connect** — establish connection via MCP or CLI (see `agent-connect-mcp`)
2. **Discover** — databases → tables → columns + comments → sort keys → skip indexes → sample → EXPLAIN
3. **Plan** — use sort key and skip index knowledge to write efficient WHERE clauses
4. **Execute** — run queries with LIMIT and timeouts
5. **Recover** — on timeout/memory errors, narrow filters and retry (see `agent-query-safety`)

### Subagent architecture notes

If your system dispatches ClickHouse tasks to specialized subagents:
- **Schema discovery + query execution**: any model — the steps are procedural
- **EXPLAIN analysis + query optimization**: benefits from mid-tier reasoning
- **Schema design review against all 31 rules**: benefits from mid-tier reasoning

---

## Review Procedures

### For Schema Reviews (CREATE TABLE, ALTER TABLE)

**Read these rule files in order:**

1. `references/schema-pk-plan-before-creation.md` - ORDER BY is immutable
2. `references/schema-pk-cardinality-order.md` - Column ordering in keys
3. `references/schema-pk-prioritize-filters.md` - Filter column inclusion
4. `references/schema-types-native-types.md` - Proper type selection
5. `references/schema-types-minimize-bitwidth.md` - Numeric type sizing
6. `references/schema-types-lowcardinality.md` - LowCardinality usage
7. `references/schema-types-avoid-nullable.md` - Nullable vs DEFAULT
8. `references/schema-partition-low-cardinality.md` - Partition count limits
9. `references/schema-partition-lifecycle.md` - Partitioning purpose

**Check for:**
- [ ] PRIMARY KEY / ORDER BY column order (low-to-high cardinality)
- [ ] Data types match actual data ranges
- [ ] LowCardinality applied to appropriate string columns
- [ ] Partition key cardinality bounded (100-1,000 values)
- [ ] ReplacingMergeTree has version column if used

### For Query Reviews (SELECT, JOIN, aggregations)

**Read these rule files:**

1. `references/query-join-choose-algorithm.md` - Algorithm selection
2. `references/query-join-filter-before.md` - Pre-join filtering
3. `references/query-join-use-any.md` - ANY vs regular JOIN
4. `references/query-index-skipping-indices.md` - Secondary index usage
5. `references/schema-pk-filter-on-orderby.md` - Filter alignment with ORDER BY

**Check for:**
- [ ] Filters use ORDER BY prefix columns
- [ ] JOINs filter tables before joining (not after)
- [ ] Correct JOIN algorithm for table sizes
- [ ] Skipping indices for non-ORDER BY filter columns

### For Insert Strategy Reviews (data ingestion, updates, deletes)

**Read these rule files:**

1. `references/insert-batch-size.md` - Batch sizing requirements
2. `references/insert-mutation-avoid-update.md` - UPDATE alternatives
3. `references/insert-mutation-avoid-delete.md` - DELETE alternatives
4. `references/insert-async-small-batches.md` - Async insert usage
5. `references/insert-optimize-avoid-final.md` - OPTIMIZE TABLE risks

**Check for:**
- [ ] Batch size 10K-100K rows per INSERT
- [ ] No ALTER TABLE UPDATE for frequent changes
- [ ] ReplacingMergeTree or CollapsingMergeTree for update patterns
- [ ] Async inserts enabled for high-frequency small batches

---

## Output Format

Structure your response as follows:

```
## Rules Checked
- `rule-name-1` - Compliant / Violation found
- `rule-name-2` - Compliant / Violation found
...

## Findings

### Violations
- **`rule-name`**: Description of the issue
  - Current: [what the code does]
  - Required: [what it should do]
  - Fix: [specific correction]

### Compliant
- `rule-name`: Brief note on why it's correct

## Recommendations
[Prioritized list of changes, citing rules]
```

---

## Rule Categories by Priority

| Priority | Category | Impact | Prefix | Rule Count |
|----------|----------|--------|--------|------------|
| 1 | Primary Key Selection | CRITICAL | `schema-pk-` | 4 |
| 2 | Data Type Selection | CRITICAL | `schema-types-` | 5 |
| 3 | JOIN Optimization | CRITICAL | `query-join-` | 5 |
| 4 | Insert Batching | CRITICAL | `insert-batch-` | 1 |
| 5 | Mutation Avoidance | CRITICAL | `insert-mutation-` | 2 |
| 6 | Partitioning Strategy | HIGH | `schema-partition-` | 4 |
| 7 | Skipping Indices | HIGH | `query-index-` | 1 |
| 8 | Materialized Views | HIGH | `query-mv-` | 2 |
| 9 | Async Inserts | HIGH | `insert-async-` | 2 |
| 10 | OPTIMIZE Avoidance | HIGH | `insert-optimize-` | 1 |
| 11 | JSON Usage | MEDIUM | `schema-json-` | 1 |
| 12 | Agent Schema Discovery | CRITICAL | `agent-discovery-` | 1 |
| 13 | Agent Query Safety | CRITICAL | `agent-query-` | 1 |
| 14 | Agent Connectivity + Formats | HIGH | `agent-connect-` | 1 |

---

## Quick Reference

### Schema Design - Primary Key (CRITICAL)

- `references/schema-pk-plan-before-creation.md` - Plan ORDER BY before table creation (immutable)
- `references/schema-pk-cardinality-order.md` - Order columns low-to-high cardinality
- `references/schema-pk-prioritize-filters.md` - Include frequently filtered columns
- `references/schema-pk-filter-on-orderby.md` - Query filters must use ORDER BY prefix

### Schema Design - Data Types (CRITICAL)

- `references/schema-types-native-types.md` - Use native types, not String for everything
- `references/schema-types-minimize-bitwidth.md` - Use smallest numeric type that fits
- `references/schema-types-lowcardinality.md` - LowCardinality for <10K unique strings
- `references/schema-types-enum.md` - Enum for finite value sets with validation
- `references/schema-types-avoid-nullable.md` - Avoid Nullable; use DEFAULT instead

### Schema Design - Partitioning (HIGH)

- `references/schema-partition-low-cardinality.md` - Keep partition count 100-1,000
- `references/schema-partition-lifecycle.md` - Use partitioning for data lifecycle, not queries
- `references/schema-partition-query-tradeoffs.md` - Understand partition pruning trade-offs
- `references/schema-partition-start-without.md` - Consider starting without partitioning

### Schema Design - JSON (MEDIUM)

- `references/schema-json-when-to-use.md` - JSON for dynamic schemas; typed columns for known

### Query Optimization - JOINs (CRITICAL)

- `references/query-join-choose-algorithm.md` - Select algorithm based on table sizes
- `references/query-join-use-any.md` - ANY JOIN when only one match needed
- `references/query-join-filter-before.md` - Filter tables before joining
- `references/query-join-consider-alternatives.md` - Dictionaries/denormalization vs JOIN
- `references/query-join-null-handling.md` - join_use_nulls=0 for default values

### Query Optimization - Indices (HIGH)

- `references/query-index-skipping-indices.md` - Skipping indices for non-ORDER BY filters

### Query Optimization - Materialized Views (HIGH)

- `references/query-mv-incremental.md` - Incremental MVs for real-time aggregations
- `references/query-mv-refreshable.md` - Refreshable MVs for complex joins

### Insert Strategy - Batching (CRITICAL)

- `references/insert-batch-size.md` - Batch 10K-100K rows per INSERT

### Insert Strategy - Async (HIGH)

- `references/insert-async-small-batches.md` - Async inserts for high-frequency small batches
- `references/insert-format-native.md` - Native format for best performance

### Insert Strategy - Mutations (CRITICAL)

- `references/insert-mutation-avoid-update.md` - ReplacingMergeTree instead of ALTER UPDATE
- `references/insert-mutation-avoid-delete.md` - Lightweight DELETE or DROP PARTITION

### Insert Strategy - Optimization (HIGH)

- `references/insert-optimize-avoid-final.md` - Let background merges work

### Agent Integration - Discovery (CRITICAL)

- `references/agent-discovery-schema.md` - Always discover schema before querying

### Agent Integration - Safety (CRITICAL)

- `references/agent-query-safety.md` - LIMIT, timeouts, progressive exploration

### Agent Integration - Connectivity + Formats (HIGH)

- `references/agent-connect-mcp.md` - MCP + CLI setup, credential discovery, output format selection

---

## When to Apply

This skill activates when you encounter:

- AI agent connecting to ClickHouse (MCP, CLI, HTTP)
- Agent workflow design for ClickHouse
- Schema discovery or exploration requests

- `CREATE TABLE` statements
- `ALTER TABLE` modifications
- `ORDER BY` or `PRIMARY KEY` discussions
- Data type selection questions
- Slow query troubleshooting
- JOIN optimization requests
- Data ingestion pipeline design
- Update/delete strategy questions
- ReplacingMergeTree or other specialized engine usage
- Partitioning strategy decisions

---

## Rule File Structure

Each rule file in `references/` contains:

- **YAML frontmatter**: title, impact level, tags
- **Brief explanation**: Why this rule matters
- **Incorrect example**: Anti-pattern with explanation
- **Correct example**: Best practice with explanation
- **Additional context**: Trade-offs, when to apply, references

Rule files follow the template in `references/_template.md`. Section ordering, impact levels, and category descriptions are defined in `references/_sections.md`.
