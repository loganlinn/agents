# Expressions and Contexts Reference

## Expression Syntax

Expressions are enclosed in `${{ }}`:

```yaml
env:
  MY_VAR: ${{ expression }}
```

In `if:` conditions, `${{ }}` is usually optional:

```yaml
if: github.ref == 'refs/heads/main'
# Same as:
if: ${{ github.ref == 'refs/heads/main' }}
```

Exception: Always use `${{ }}` when expression starts with `!`:

```yaml
if: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

## Literals

| Type | Examples |
|------|----------|
| Boolean | `true`, `false` |
| Null | `null` |
| Number | `42`, `-9.2`, `0xff`, `2.99e-2` |
| String | `'Hello'`, `'It''s escaped'` |

Note: Use single quotes for strings. Double quotes cause errors.

## Operators

| Operator | Description |
|----------|-------------|
| `( )` | Grouping |
| `[ ]` | Index access |
| `.` | Property access |
| `!` | Logical NOT |
| `<` `<=` `>` `>=` | Comparison |
| `==` `!=` | Equality |
| `&&` | Logical AND |
| `\|\|` | Logical OR |

String comparison is case-insensitive.

## Available Contexts

### github Context

Information about the workflow run and triggering event.

| Property | Description |
|----------|-------------|
| `github.action` | Action name or step id |
| `github.action_path` | Path to action directory |
| `github.actor` | User who triggered the workflow |
| `github.actor_id` | User ID |
| `github.api_url` | GitHub API URL |
| `github.base_ref` | PR base branch name |
| `github.event` | Full webhook event payload |
| `github.event_name` | Event name (push, pull_request, etc.) |
| `github.event_path` | Path to event JSON file |
| `github.graphql_url` | GraphQL API URL |
| `github.head_ref` | PR head branch name |
| `github.job` | Current job id |
| `github.path` | Path to add to PATH |
| `github.ref` | Full ref (refs/heads/main, refs/tags/v1) |
| `github.ref_name` | Short ref (main, v1) |
| `github.ref_protected` | Whether ref is protected |
| `github.ref_type` | branch or tag |
| `github.repository` | owner/repo |
| `github.repository_id` | Repository ID |
| `github.repository_owner` | Owner name |
| `github.repository_owner_id` | Owner ID |
| `github.repositoryUrl` | Git URL (git://github.com/...) |
| `github.retention_days` | Artifact retention days |
| `github.run_attempt` | Retry attempt number |
| `github.run_id` | Unique run ID |
| `github.run_number` | Sequential run number |
| `github.server_url` | GitHub server URL |
| `github.sha` | Commit SHA |
| `github.token` | GITHUB_TOKEN value |
| `github.triggering_actor` | User who triggered run |
| `github.workflow` | Workflow name |
| `github.workflow_ref` | Full workflow path |
| `github.workflow_sha` | Workflow file SHA |
| `github.workspace` | Workspace directory |

Common event payload properties:

```yaml
# Push event
${{ github.event.head_commit.message }}
${{ github.event.pusher.name }}

# Pull request event
${{ github.event.pull_request.number }}
${{ github.event.pull_request.title }}
${{ github.event.pull_request.head.sha }}
${{ github.event.pull_request.base.ref }}

# Issue event
${{ github.event.issue.number }}
${{ github.event.issue.title }}
${{ github.event.issue.labels.*.name }}
```

### env Context

Environment variables.

```yaml
env:
  MY_VAR: hello

jobs:
  build:
    steps:
      - run: echo ${{ env.MY_VAR }}
```

### vars Context

Repository/organization variables (not secrets).

```yaml
steps:
  - run: echo ${{ vars.MY_VARIABLE }}
```

### secrets Context

Secrets from repository/organization/environment.

```yaml
steps:
  - run: echo "Token available"
    env:
      TOKEN: ${{ secrets.MY_TOKEN }}
```

Built-in: `secrets.GITHUB_TOKEN`

### job Context

Current job information.

| Property | Description |
|----------|-------------|
| `job.container.id` | Container ID |
| `job.container.network` | Container network |
| `job.services.<id>.id` | Service container ID |
| `job.services.<id>.network` | Service network |
| `job.services.<id>.ports` | Service ports |
| `job.status` | Job status (success, failure, cancelled) |

### jobs Context (Reusable Workflows)

Outputs from reusable workflow jobs.

```yaml
# In calling workflow
jobs:
  call:
    uses: ./.github/workflows/reusable.yml
  use-output:
    needs: call
    steps:
      - run: echo ${{ needs.call.outputs.result }}
```

### steps Context

Outputs and status from previous steps.

| Property | Description |
|----------|-------------|
| `steps.<id>.outputs.<name>` | Step output value |
| `steps.<id>.conclusion` | Step result (success, failure, cancelled, skipped) |
| `steps.<id>.outcome` | Result before continue-on-error |

```yaml
steps:
  - id: build
    run: echo "version=1.0.0" >> "$GITHUB_OUTPUT"

  - run: echo ${{ steps.build.outputs.version }}
  - run: echo ${{ steps.build.conclusion }}
```

### needs Context

Outputs and status from dependency jobs.

| Property | Description |
|----------|-------------|
| `needs.<job>.outputs.<name>` | Job output |
| `needs.<job>.result` | Job result |

```yaml
jobs:
  setup:
    outputs:
      version: ${{ steps.v.outputs.value }}
    steps:
      - id: v
        run: echo "value=1.0.0" >> "$GITHUB_OUTPUT"

  build:
    needs: setup
    steps:
      - run: echo ${{ needs.setup.outputs.version }}
      - run: echo ${{ needs.setup.result }}
```

### runner Context

Runner environment information.

| Property | Description |
|----------|-------------|
| `runner.name` | Runner name |
| `runner.os` | Linux, Windows, or macOS |
| `runner.arch` | X64, ARM, or ARM64 |
| `runner.temp` | Temp directory path |
| `runner.tool_cache` | Tool cache path |
| `runner.debug` | Debug logging enabled |
| `runner.environment` | github-hosted or self-hosted |

### strategy Context

Matrix strategy information.

| Property | Description |
|----------|-------------|
| `strategy.fail-fast` | Whether fail-fast enabled |
| `strategy.job-index` | Current job index in matrix |
| `strategy.job-total` | Total jobs in matrix |
| `strategy.max-parallel` | Max parallel jobs |

### matrix Context

Current matrix values.

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20]

steps:
  - run: echo "OS: ${{ matrix.os }}, Node: ${{ matrix.node }}"
```

### inputs Context

Workflow dispatch or reusable workflow inputs.

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: string
        required: true

jobs:
  deploy:
    steps:
      - run: echo ${{ inputs.environment }}
```

## Context Availability

| Context | Workflow | Job | Step |
|---------|----------|-----|------|
| `github` | Yes | Yes | Yes |
| `env` | Yes | Yes | Yes |
| `vars` | Yes | Yes | Yes |
| `job` | No | No | Yes |
| `steps` | No | No | Yes |
| `runner` | No | No | Yes |
| `secrets` | No | Yes | Yes |
| `strategy` | No | Yes | Yes |
| `matrix` | No | Yes | Yes |
| `needs` | No | Yes | Yes |
| `inputs` | Yes | Yes | Yes |

## Functions

### String Functions

#### contains

```yaml
# Check if string contains substring
contains('Hello World', 'World')  # true

# Check if array contains item
contains(github.event.issue.labels.*.name, 'bug')  # true if has 'bug' label

# Check event name
contains(fromJSON('["push", "pull_request"]'), github.event_name)
```

#### startsWith

```yaml
startsWith('Hello', 'He')  # true
startsWith(github.ref, 'refs/tags/')  # true for tags
```

#### endsWith

```yaml
endsWith('hello.js', '.js')  # true
```

#### format

```yaml
format('Hello {0} {1}', 'World', '!')  # "Hello World !"
format('{{escaped}}')  # "{escaped}"
```

#### join

```yaml
join(github.event.issue.labels.*.name, ', ')  # "bug, enhancement"
```

### JSON Functions

#### toJSON

```yaml
# Debug contexts
run: echo '${{ toJSON(github.event) }}'
run: echo '${{ toJSON(matrix) }}'
```

#### fromJSON

```yaml
# Parse JSON string
strategy:
  matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}

# Convert string to number/boolean
continue-on-error: ${{ fromJSON(env.CONTINUE) }}
timeout-minutes: ${{ fromJSON(env.TIMEOUT) }}
```

### hashFiles

```yaml
# Single pattern
hashFiles('**/package-lock.json')

# Multiple patterns
hashFiles('**/package-lock.json', '**/yarn.lock')

# Use for cache keys
key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
```

### case (Switch Expression)

```yaml
# Single condition with default
env:
  TARGET: ${{ case(github.ref == 'refs/heads/main', 'prod', 'dev') }}

# Multiple conditions
env:
  ENV: ${{ case(
    github.ref == 'refs/heads/main', 'production',
    github.ref == 'refs/heads/staging', 'staging',
    startsWith(github.ref, 'refs/heads/feature/'), 'development',
    'unknown'
  ) }}
```

## Status Check Functions

Used in `if:` conditions. Default is `success()`.

### success

```yaml
if: success()  # Previous steps succeeded (default)
```

### failure

```yaml
if: failure()  # Previous step failed

# With additional condition
if: failure() && steps.test.conclusion == 'failure'
```

### always

```yaml
if: always()  # Always run, even if cancelled
```

Warning: Avoid for critical tasks that could hang.

### cancelled

```yaml
if: cancelled()  # Workflow was cancelled
```

### Recommended: !cancelled()

```yaml
if: ${{ !cancelled() }}  # Run unless cancelled (even on failure)
```

## Object Filters

Use `*` to filter arrays and objects.

```yaml
# Get all label names
github.event.issue.labels.*.name  # ["bug", "urgent"]

# In contains()
contains(github.event.issue.labels.*.name, 'bug')
```

## Common Expression Patterns

### Conditional Values

```yaml
env:
  # Ternary-like with ||
  BRANCH: ${{ github.head_ref || github.ref_name }}

  # Default value
  TIMEOUT: ${{ vars.TIMEOUT || '30' }}
```

### Branch/Tag Checks

```yaml
# Main branch
if: github.ref == 'refs/heads/main'

# Any tag
if: startsWith(github.ref, 'refs/tags/')

# Specific tag pattern
if: startsWith(github.ref, 'refs/tags/v')

# Not main branch
if: github.ref != 'refs/heads/main'
```

### Event Checks

```yaml
# Push event
if: github.event_name == 'push'

# Pull request event
if: github.event_name == 'pull_request'

# Manual trigger
if: github.event_name == 'workflow_dispatch'

# Multiple events
if: contains(fromJSON('["push", "workflow_dispatch"]'), github.event_name)
```

### PR Checks

```yaml
# PR to main
if: github.event.pull_request.base.ref == 'main'

# PR from fork
if: github.event.pull_request.head.repo.fork

# PR has specific label
if: contains(github.event.pull_request.labels.*.name, 'deploy')
```

### Secret/Variable Checks

```yaml
# Secret is set (via env)
env:
  HAS_SECRET: ${{ secrets.MY_SECRET != '' }}
steps:
  - if: env.HAS_SECRET == 'true'
    run: echo "Secret available"
```
