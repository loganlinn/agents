# GitHub Actions Limits

## Workflow and Job Time Limits

| Limit | Threshold | Notes |
|-------|-----------|-------|
| Workflow run time | 35 days | Includes execution, waiting, and approval time |
| Gate approval time | 30 days | Max wait for environment approvals |
| Job execution (GitHub-hosted) | 6 hours | Job is terminated and fails if exceeded |
| Job execution (self-hosted) | 5 days | Job is terminated and fails if exceeded |
| Job queue time (self-hosted) | 24 hours | Auto-cancelled if not picked up |

## Workflow Queuing Limits

| Limit | Threshold | Notes |
|-------|-----------|-------|
| Workflow trigger events | 1,500 events / 10s / repo | Support can increase |
| Workflow runs queued | 500 runs / 10s | Reusable workflows count as 1 run |

## Matrix Limits

| Limit | Threshold |
|-------|-----------|
| Jobs per matrix | 256 per workflow run |

Applies to both GitHub-hosted and self-hosted runners.

## Job Concurrency by Plan (Standard Runners)

| Plan | Total Concurrent | Max macOS | Max GPU |
|------|-----------------|-----------|---------|
| Free | 20 | 5 | N/A |
| Pro | 40 | 5 | N/A |
| Team | 60 | 5 | N/A |
| Enterprise | 500 | 50 | N/A |

## Job Concurrency (Larger Runners)

| Plan | Total Concurrent | Max macOS | Max GPU |
|------|-----------------|-----------|---------|
| Team | 1,000 | 5 | 100 |
| Enterprise | 1,000 | 50 | 100 |

macOS concurrency is shared between standard and larger runners.

## Storage Limits by Plan

| Plan | Artifact Storage | Minutes/Month | Cache Storage |
|------|-----------------|---------------|---------------|
| Free | 500 MB | 2,000 | 10 GB |
| Pro | 1 GB | 3,000 | 10 GB |
| Free (org) | 500 MB | 2,000 | 10 GB |
| Team | 2 GB | 3,000 | 10 GB |
| Enterprise Cloud | 50 GB | 50,000 | 10 GB |

Storage limits cannot be increased by support.

## Cache Limits

| Limit | Threshold |
|-------|-----------|
| Cache uploads | 200 per minute per repo |
| Cache storage | 10 GB per repo |

Least recently used entries are evicted when storage is full.

## Self-Hosted Runner Limits

| Limit | Threshold | Support Increase? |
|-------|-----------|-------------------|
| Runner registrations | 1,500 / 5 min / repo/org/enterprise | Yes |
| Runners per group | 10,000 | No |

## Larger Runner Limits

| Limit | Threshold | Support Increase? |
|-------|-----------|-------------------|
| Per-runner concurrency | ~1,000 max (Linux CPU) | Yes |
| Static IPs | 10 per enterprise/org | Yes |
| vnet injection buffer | 30% above max concurrency | Configurable |

## API Rate Limits

| Authentication | Rate Limit |
|---------------|------------|
| Unauthenticated | 60 requests/hour (per IP) |
| Personal access token | 5,000 requests/hour |
| PAT (Enterprise Cloud org) | 15,000 requests/hour |
| GitHub App installation | 5,000 requests/hour (base) |
| GitHub App (Enterprise Cloud) | 15,000 requests/hour |
| OAuth app | 5,000 requests/hour |
| OAuth app (Enterprise Cloud) | 15,000 requests/hour |
| `GITHUB_TOKEN` | 1,000 requests/hour/repo |
| `GITHUB_TOKEN` (Enterprise Cloud) | 15,000 requests/hour/repo |

GitHub App installation rate scales: +50 req/hr per repo (>20 repos) and +50 req/hr per user (>20 users), max 12,500/hr.

Secondary rate limits also apply and are not configurable.

## Docker Hub Rate Limits

| Scenario | Rate Limited? |
|----------|--------------|
| GitHub-hosted, public images | No |
| GitHub-hosted, private images | Yes |
| Self-hosted, any images | Yes |

## Commonly Hit Limits Summary

| What you hit | Typical cause | Mitigation |
|-------------|---------------|------------|
| 256 matrix cap | Large test matrices | Split into multiple jobs or use `include` selectively |
| 6hr job timeout | Long builds/tests | Parallelize, use caching, split jobs |
| 1,000 req/hr GITHUB_TOKEN | Many API calls in workflow | Batch operations, use GraphQL, cache responses |
| 10 GB cache | Large dependency trees | Prune cache keys, use selective caching |
| 500 MB / 2 GB artifact storage | CI artifact accumulation | Set retention days, clean up old artifacts |
| 200 cache uploads/min | Parallel jobs saving caches | Deduplicate cache saves, use single cache job |
