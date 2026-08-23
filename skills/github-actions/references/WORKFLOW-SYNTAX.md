# Workflow Syntax Reference

Complete reference for GitHub Actions workflow YAML syntax.

## Top-Level Keys

| Key | Required | Description |
|-----|----------|-------------|
| `name` | No | Workflow display name |
| `run-name` | No | Name for workflow runs (supports expressions) |
| `on` | Yes | Trigger events |
| `permissions` | No | GITHUB_TOKEN permissions |
| `env` | No | Environment variables for all jobs |
| `defaults` | No | Default settings for jobs |
| `concurrency` | No | Concurrency control |
| `jobs` | Yes | Job definitions |

## name

```yaml
name: My Workflow
```

## run-name

Dynamic name for workflow runs:

```yaml
run-name: Deploy to ${{ inputs.deploy_target }} by @${{ github.actor }}
```

## on (Triggers)

### Single Event

```yaml
on: push
```

### Multiple Events

```yaml
on: [push, pull_request]
```

### Event Configuration

```yaml
on:
  push:
    branches:
      - main
      - 'releases/**'
    branches-ignore:
      - 'feature/**'
    tags:
      - 'v*'
    paths:
      - 'src/**'
      - '!src/**/*.md'
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main
```

### workflow_dispatch (Manual)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment target'
        required: true
        default: 'staging'
        type: choice
        options:
          - development
          - staging
          - production
      dry-run:
        description: 'Dry run mode'
        required: false
        type: boolean
        default: false
      version:
        description: 'Version to deploy'
        required: true
        type: string
```

Input types: `string`, `boolean`, `choice`, `number`, `environment`

### workflow_call (Reusable)

```yaml
on:
  workflow_call:
    inputs:
      config:
        description: 'Configuration name'
        required: true
        type: string
    outputs:
      result:
        description: 'Build result'
        value: ${{ jobs.build.outputs.result }}
    secrets:
      token:
        description: 'Access token'
        required: true
```

### schedule (Cron)

```yaml
on:
  schedule:
    - cron: '0 0 * * *'     # Daily at midnight UTC
    - cron: '*/15 * * * *'  # Every 15 minutes
```

Cron format: `minute hour day-of-month month day-of-week`

### workflow_run

```yaml
on:
  workflow_run:
    workflows: ["Build"]
    types: [completed]
    branches: [main]
```

## permissions

### Workflow-Level

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
  id-token: write
```

### Job-Level

```yaml
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write
```

### Available Permissions

| Permission | Values | Description |
|------------|--------|-------------|
| `actions` | read/write/none | Manage GitHub Actions |
| `attestations` | read/write/none | Artifact attestations |
| `checks` | read/write/none | Check runs and suites |
| `contents` | read/write/none | Repository contents |
| `deployments` | read/write/none | Deployments |
| `discussions` | read/write/none | Discussions |
| `id-token` | write/none | OIDC tokens |
| `issues` | read/write/none | Issues |
| `packages` | read/write/none | GitHub Packages |
| `pages` | read/write/none | GitHub Pages |
| `pull-requests` | read/write/none | Pull requests |
| `security-events` | read/write/none | Code scanning alerts |
| `statuses` | read/write/none | Commit statuses |

## env

```yaml
env:
  NODE_ENV: production
  CI: true
```

## defaults

```yaml
defaults:
  run:
    shell: bash
    working-directory: ./src
```

## concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Fallback for events without `head_ref`:

```yaml
concurrency:
  group: ${{ github.head_ref || github.run_id }}
  cancel-in-progress: true
```

## jobs

### Basic Job

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm build
```

### jobs.<job_id>.runs-on

```yaml
# GitHub-hosted runners
runs-on: ubuntu-latest
runs-on: windows-latest
runs-on: macos-latest

# Specific versions
runs-on: ubuntu-24.04
runs-on: ubuntu-22.04

# Self-hosted
runs-on: self-hosted
runs-on: [self-hosted, linux, x64]

# Runner groups
runs-on:
  group: ubuntu-runners
  labels: ubuntu-20.04-16core
```

### jobs.<job_id>.needs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
  test:
    needs: build
    runs-on: ubuntu-latest
  deploy:
    needs: [build, test]
    runs-on: ubuntu-latest
```

Run even if dependency failed:

```yaml
jobs:
  cleanup:
    needs: [build, test]
    if: always()
    runs-on: ubuntu-latest
```

### jobs.<job_id>.if

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

  production:
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
```

### jobs.<job_id>.outputs

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.value }}
      matrix: ${{ steps.matrix.outputs.value }}
    steps:
      - id: version
        run: echo "value=1.0.0" >> "$GITHUB_OUTPUT"
      - id: matrix
        run: echo 'value={"include":[{"os":"ubuntu"},{"os":"windows"}]}' >> "$GITHUB_OUTPUT"

  build:
    needs: setup
    strategy:
      matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
    runs-on: ${{ matrix.os }}-latest
    steps:
      - run: echo "Building version ${{ needs.setup.outputs.version }}"
```

### jobs.<job_id>.env

```yaml
jobs:
  build:
    env:
      NODE_ENV: production
    runs-on: ubuntu-latest
```

### jobs.<job_id>.environment

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: ${{ steps.deploy.outputs.url }}
    runs-on: ubuntu-latest
```

### jobs.<job_id>.concurrency

```yaml
jobs:
  deploy:
    concurrency:
      group: deploy-${{ github.ref }}
      cancel-in-progress: false
    runs-on: ubuntu-latest
```

### jobs.<job_id>.strategy

```yaml
jobs:
  test:
    strategy:
      fail-fast: false          # Continue other matrix jobs on failure
      max-parallel: 2           # Limit concurrent jobs
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [18, 20, 22]
        exclude:
          - os: windows-latest
            node: 18
        include:
          - os: ubuntu-latest
            node: 20
            experimental: true
    runs-on: ${{ matrix.os }}
    continue-on-error: ${{ matrix.experimental || false }}
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
```

### jobs.<job_id>.timeout-minutes

```yaml
jobs:
  build:
    timeout-minutes: 30
    runs-on: ubuntu-latest
```

Default: 360 minutes (6 hours)

### jobs.<job_id>.container

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:20
      credentials:
        username: ${{ secrets.DOCKER_USER }}
        password: ${{ secrets.DOCKER_TOKEN }}
      env:
        NODE_ENV: production
      ports:
        - 80
      volumes:
        - my_docker_volume:/volume_mount
      options: --cpus 1
```

### jobs.<job_id>.services

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        ports:
          - 6379:6379
```

## jobs.<job_id>.steps

### Step Keys

| Key | Description |
|-----|-------------|
| `id` | Unique identifier for referencing outputs |
| `name` | Display name |
| `uses` | Action to run |
| `run` | Shell command(s) |
| `with` | Action inputs |
| `env` | Environment variables |
| `if` | Conditional execution |
| `continue-on-error` | Don't fail job if step fails |
| `timeout-minutes` | Step timeout |
| `shell` | Shell to use for `run` |
| `working-directory` | Working directory for `run` |

### uses (Actions)

```yaml
steps:
  # Public action
  - uses: actions/checkout@v5

  # Specific version
  - uses: actions/setup-node@v4.2.0

  # Commit SHA (most secure)
  - uses: actions/checkout@8f4b7f84864484a7bf31766abe9204da3cbe65b3

  # Branch
  - uses: actions/checkout@main

  # Subdirectory
  - uses: actions/aws/ec2@main

  # Local action
  - uses: ./.github/actions/my-action

  # Docker Hub
  - uses: docker://alpine:3.8

  # GitHub Container Registry
  - uses: docker://ghcr.io/owner/image
```

### with (Action Inputs)

```yaml
steps:
  - uses: actions/checkout@v5
    with:
      fetch-depth: 0
      ref: ${{ github.head_ref }}

  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
      registry-url: 'https://npm.pkg.github.com'
```

### run (Commands)

```yaml
steps:
  - run: npm install

  - run: |
      echo "Multi-line command"
      npm test
      npm build

  - name: With options
    run: ./build.sh
    shell: bash
    working-directory: ./app
    env:
      DEBUG: true
```

### Shell Options

| Shell | Platform | Command |
|-------|----------|---------|
| `bash` | All | `bash --noprofile --norc -eo pipefail {0}` |
| `pwsh` | All | `pwsh -command ". '{0}'"` |
| `python` | All | `python {0}` |
| `sh` | Linux/macOS | `sh -e {0}` |
| `cmd` | Windows | `%ComSpec% /D /E:ON /V:OFF /S /C "CALL "{0}""` |
| `powershell` | Windows | `powershell -command ". '{0}'"` |

### Step Conditions

```yaml
steps:
  # Always run
  - run: echo "Cleanup"
    if: always()

  # On failure
  - run: echo "Failed!"
    if: failure()

  # On success (default)
  - run: echo "Success!"
    if: success()

  # On cancellation
  - run: echo "Cancelled"
    if: cancelled()

  # Custom condition
  - run: echo "Main branch"
    if: github.ref == 'refs/heads/main'

  # Combine conditions
  - run: echo "Deploy"
    if: success() && github.ref == 'refs/heads/main'

  # Negation (must use ${{ }})
  - run: echo "Not a tag"
    if: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

### Step Outputs

```yaml
steps:
  - id: build
    run: |
      echo "version=1.0.0" >> "$GITHUB_OUTPUT"
      echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"

  - run: echo "Version: ${{ steps.build.outputs.version }}"
```

### continue-on-error

```yaml
steps:
  - run: ./optional-task.sh
    continue-on-error: true

  - run: echo "This runs even if previous failed"
```

### timeout-minutes

```yaml
steps:
  - run: ./long-running-task.sh
    timeout-minutes: 10
```

## Filter Pattern Cheat Sheet

| Pattern | Matches |
|---------|---------|
| `*` | Any character (except `/`) |
| `**` | Any path |
| `?` | Single character |
| `+` | One or more of preceding |
| `!` | Negate (must follow positive) |
| `[abc]` | Character class |
| `[a-z]` | Character range |

Examples:

```yaml
# All JS files
'**/*.js'

# All files in src except tests
paths:
  - 'src/**'
  - '!src/**/*.test.js'

# Branches starting with feature/
branches:
  - 'feature/**'

# Version tags
tags:
  - 'v[0-9]+.[0-9]+.[0-9]+'
```
