# Workflow Triggers Reference

Complete reference for events that trigger GitHub Actions workflows.

## Common Events

### push

Triggered when commits are pushed.

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
    tags-ignore:
      - 'v*-beta'
    paths:
      - 'src/**'
      - '**.js'
    paths-ignore:
      - 'docs/**'
      - '**.md'
```

| Property | Description |
|----------|-------------|
| `GITHUB_SHA` | Commit that was pushed |
| `GITHUB_REF` | Branch or tag ref |

Key event payload properties:
- `github.event.head_commit.message` - Commit message
- `github.event.commits` - Array of commits
- `github.event.pusher.name` - Who pushed
- `github.event.before` - Previous HEAD SHA
- `github.event.after` - New HEAD SHA

### pull_request

Triggered for pull request activity.

```yaml
on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
      - closed
    branches:
      - main
    paths:
      - 'src/**'
```

Activity types:
- `assigned`, `unassigned`
- `labeled`, `unlabeled`
- `opened`, `edited`, `closed`
- `reopened`
- `synchronize` (new commits pushed)
- `converted_to_draft`, `ready_for_review`
- `locked`, `unlocked`
- `review_requested`, `review_request_removed`
- `auto_merge_enabled`, `auto_merge_disabled`

Default types: `opened`, `synchronize`, `reopened`

| Property | Description |
|----------|-------------|
| `GITHUB_SHA` | Merge commit SHA |
| `GITHUB_REF` | PR merge branch (refs/pull/:prNumber/merge) |

Key event payload properties:
- `github.event.pull_request.number` - PR number
- `github.event.pull_request.title` - PR title
- `github.event.pull_request.body` - PR description
- `github.event.pull_request.head.ref` - Source branch
- `github.event.pull_request.head.sha` - Head commit SHA
- `github.event.pull_request.base.ref` - Target branch
- `github.event.pull_request.merged` - Whether merged
- `github.event.pull_request.draft` - Whether draft
- `github.event.pull_request.labels` - Labels array

### pull_request_target

Like `pull_request` but runs in the context of the base repository. Safe for fork PRs as secrets are available.

```yaml
on:
  pull_request_target:
    types: [opened, synchronize]
```

**Security Warning**: Be careful running untrusted code from PRs.

### workflow_dispatch

Manual trigger with optional inputs.

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
      version:
        description: 'Version to deploy'
        required: true
        type: string
      dry_run:
        description: 'Dry run mode'
        required: false
        type: boolean
        default: false
      timeout:
        description: 'Timeout in minutes'
        required: false
        type: number
        default: 30
```

Input types:
- `string` - Text input
- `boolean` - Checkbox
- `choice` - Dropdown with options
- `number` - Numeric input
- `environment` - Environment selector

Access inputs:
```yaml
steps:
  - run: echo "Deploying ${{ inputs.version }} to ${{ inputs.environment }}"
```

### workflow_call

Makes workflow reusable by other workflows.

```yaml
on:
  workflow_call:
    inputs:
      config_path:
        description: 'Path to config file'
        required: true
        type: string
      dry_run:
        required: false
        type: boolean
        default: false
    outputs:
      result:
        description: 'Build result'
        value: ${{ jobs.build.outputs.result }}
    secrets:
      npm_token:
        description: 'NPM token'
        required: true
      aws_key:
        required: false
```

Call from another workflow:
```yaml
jobs:
  call-reusable:
    uses: owner/repo/.github/workflows/reusable.yml@main
    with:
      config_path: ./config.json
    secrets:
      npm_token: ${{ secrets.NPM_TOKEN }}
```

### schedule

Cron-based scheduling. Runs on default branch.

```yaml
on:
  schedule:
    - cron: '0 0 * * *'      # Daily at midnight UTC
    - cron: '0 */6 * * *'    # Every 6 hours
    - cron: '30 5 * * 1-5'   # Weekdays at 5:30 UTC
```

Cron format: `minute hour day-of-month month day-of-week`

| Field | Values |
|-------|--------|
| Minute | 0-59 |
| Hour | 0-23 |
| Day of month | 1-31 |
| Month | 1-12 or JAN-DEC |
| Day of week | 0-6 or SUN-SAT (0=Sunday) |

Special characters:
- `*` - Any value
- `,` - List separator (1,3,5)
- `-` - Range (1-5)
- `/` - Step (*/15 = every 15)

Examples:
- `0 0 * * *` - Daily at midnight
- `0 12 * * 1` - Monday at noon
- `*/15 * * * *` - Every 15 minutes
- `0 0 1 * *` - First of month
- `0 0 * * 0` - Every Sunday

Note: Minimum interval is 5 minutes. Runs may be delayed during high load.

### workflow_run

Triggered when another workflow completes.

```yaml
on:
  workflow_run:
    workflows: ["Build", "Test"]
    types:
      - completed
      - requested
    branches:
      - main
```

Access triggering workflow info:
```yaml
steps:
  - run: |
      echo "Workflow: ${{ github.event.workflow_run.name }}"
      echo "Conclusion: ${{ github.event.workflow_run.conclusion }}"
      echo "Branch: ${{ github.event.workflow_run.head_branch }}"
```

Check conclusion:
```yaml
jobs:
  on-success:
    if: github.event.workflow_run.conclusion == 'success'
```

### release

Triggered for release events.

```yaml
on:
  release:
    types:
      - published
      - created
      - released
      - prereleased
```

Activity types:
- `published` - Release published (not draft)
- `unpublished`
- `created`
- `edited`
- `deleted`
- `prereleased` - Pre-release published
- `released` - Full release (excludes prereleases)

Event payload:
- `github.event.release.tag_name` - Tag
- `github.event.release.name` - Release name
- `github.event.release.body` - Release notes
- `github.event.release.prerelease` - Is prerelease
- `github.event.release.draft` - Is draft

## Other Events

### issues

```yaml
on:
  issues:
    types: [opened, edited, deleted, labeled, unlabeled, assigned, closed]
```

### issue_comment

```yaml
on:
  issue_comment:
    types: [created, edited, deleted]
```

Note: Fires for both issue and PR comments.

```yaml
jobs:
  pr-comment:
    if: github.event.issue.pull_request
    runs-on: ubuntu-latest
```

### create / delete

```yaml
on:
  create:  # Branch or tag created
  delete:  # Branch or tag deleted
```

### fork

```yaml
on: fork
```

### watch

```yaml
on:
  watch:
    types: [started]  # Someone starred the repo
```

### deployment / deployment_status

```yaml
on:
  deployment:
  deployment_status:
```

### page_build

```yaml
on: page_build
```

### repository_dispatch

Custom webhook events.

```yaml
on:
  repository_dispatch:
    types: [my-event, deploy]
```

Trigger via API:
```bash
curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/owner/repo/dispatches \
  -d '{"event_type":"my-event","client_payload":{"key":"value"}}'
```

Access payload:
```yaml
steps:
  - run: echo ${{ github.event.client_payload.key }}
```

### check_run / check_suite

```yaml
on:
  check_run:
    types: [created, rerequested, completed]
  check_suite:
    types: [completed]
```

### discussion / discussion_comment

```yaml
on:
  discussion:
    types: [created, edited, answered]
  discussion_comment:
    types: [created]
```

### label

```yaml
on:
  label:
    types: [created, edited, deleted]
```

### milestone

```yaml
on:
  milestone:
    types: [created, closed, opened, edited, deleted]
```

### project / project_card / project_column

```yaml
on:
  project:
    types: [created, closed, reopened]
```

### status

Commit status changes.

```yaml
on: status
```

## Filtering

### Branch Filters

```yaml
on:
  push:
    branches:
      - main
      - 'releases/**'
      - '!releases/**-alpha'  # Exclude alpha releases
    branches-ignore:
      - 'feature/**'
```

Cannot use both `branches` and `branches-ignore` for same event.

### Tag Filters

```yaml
on:
  push:
    tags:
      - 'v*'
      - 'v[0-9]+.[0-9]+.[0-9]+'
    tags-ignore:
      - 'v*-rc*'
```

### Path Filters

```yaml
on:
  push:
    paths:
      - 'src/**'
      - '**.js'
      - '!src/**/*.test.js'
    paths-ignore:
      - 'docs/**'
      - '**.md'
      - '.github/**'
```

Path filters are not evaluated for tag pushes.

### Activity Type Filters

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  issues:
    types: [opened, labeled]
```

## Pattern Matching

| Pattern | Matches |
|---------|---------|
| `*` | Any character except `/` |
| `**` | Any path (including `/`) |
| `?` | Single character |
| `[abc]` | Character in set |
| `[a-z]` | Character in range |
| `!` | Negate (exclude) |

Examples:
- `main` - Exact match
- `feature/*` - feature/foo, not feature/foo/bar
- `feature/**` - feature/foo, feature/foo/bar
- `v[0-9]+` - v1, v12, v123
- `!**/*.md` - Exclude all markdown files

## Multiple Events

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

Check which event triggered:
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - if: github.event_name == 'push'
        run: echo "Triggered by push"
      - if: github.event_name == 'pull_request'
        run: echo "Triggered by PR"
```
