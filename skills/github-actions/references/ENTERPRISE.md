# Enterprise & Scaling Reference

Enterprise features for GitHub Actions: larger runners, ARC, runner groups,
private networking, billing, and metrics.

## Larger Runners

Available on GitHub Team and Enterprise Cloud plans. Configured at the
organization or enterprise level.

### Specifications (Ubuntu/Windows)

| vCPU | RAM | Storage | Architecture |
|------|--------|---------|--------------|
| 2 | 8 GB | 75 GB | x64, arm64 |
| 4 | 16 GB | 150 GB | x64, arm64 |
| 8 | 32 GB | 300 GB | x64, arm64 |
| 16 | 64 GB | 600 GB | x64, arm64 |
| 32 | 128 GB | 1200 GB | x64, arm64 |
| 64 | 208 GB | 2040 GB | arm64 |
| 64 | 256 GB | 2040 GB | x64 |
| 96 | 384 GB | 2040 GB | x64 |

4-vCPU Windows only works with Windows Server 2025 or Base Windows 11 Desktop.

### macOS Larger Runners

| Size | Arch | CPU | RAM | Labels |
|---------|------------|-----|-------|--------|
| Large | Intel | 12 | 30 GB | `macos-{13,14,15}-large` |
| XLarge | arm64 (M2) | 5 | 14 GB | `macos-{13,14,15}-xlarge` |

macOS larger runners do not support static IPs or Azure VNET.

### GPU Runners

| vCPU | GPU | Card | RAM | VRAM | Storage | OS |
|------|-----|----------|-------|-------|---------|-----------------|
| 4 | 1 | Tesla T4 | 28 GB | 16 GB | 176 GB | Ubuntu, Windows |

### Using Larger Runners in Workflows

Larger runners get a default label matching their configured name.
Custom labels cannot be added.

```yaml
# By label (runner name)
jobs:
  build:
    runs-on: ubuntu-20.04-16core

# By runner group
jobs:
  build:
    runs-on:
      group: ubuntu-runners

# By group + label
jobs:
  build:
    runs-on:
      group: ubuntu-runners
      labels: ubuntu-20.04-16core

# macOS larger runner
jobs:
  build:
    runs-on: macos-15-xlarge
```

### Autoscaling

Set maximum concurrent jobs per runner definition. VMs scale up/down
automatically. After first use, VMs stay warm for ~5 minutes; a subset
stays warm for 24 hours with sustained usage.

## Actions Runner Controller (ARC)

Kubernetes operator that orchestrates and scales self-hosted runners.
Runners are ephemeral and container-based.

### Key Concepts

| Concept | Description |
|---------|-------------|
| Runner scale set | Group of homogeneous runners managed by ARC |
| Scale set listener | Long-polls GitHub Actions service for `Job Available` messages |
| Ephemeral runners | Created per-job via JIT tokens, deleted after completion |
| Runner image | `ghcr.io/actions/actions-runner` (minimal, based on dotnet runtime-deps) |

Runner scale sets can only have one label (the scale set name).
They belong to one runner group at a time.

### ARC Helm Charts

| Chart | Purpose |
|-------|---------|
| `gha-runner-scale-set-controller` | Controller manager deployment |
| `gha-runner-scale-set` | Runner scale set + autoscaling config |

Both published as OCI packages on GitHub Packages.

### Using ARC Runners in Workflows

Target ARC runners using the runner scale set name (set during install
or via `runnerScaleSetName` in `values.yaml`):

```yaml
jobs:
  build:
    runs-on: arc-runner-set  # matches the scale set installation name
    steps:
      - uses: actions/checkout@v5
      - run: echo "Running on ARC"
```

Additional labels cannot be used to target ARC runners. The scale set
name is the only `runs-on` value that works.

### ARC Autoscaling Flow

1. Listener receives `Job Available` from GitHub Actions service
2. Listener checks if it can scale up to desired count
3. Listener patches EphemeralRunnerSet with desired replica count
4. EphemeralRunner Controller requests JIT tokens, creates runner pods
5. Runner registers with GitHub, receives and executes the job
6. On completion, runner is deleted (ephemeral)

Failed pod creation retries up to 5 times. Unassigned jobs timeout
after 24 hours.

## Runner Groups

Control access to runners at the organization and enterprise level.

### Access Control

| Level | Default Access | Configurable |
|------------|------------------------|--------------|
| Enterprise | Not available to repos | Org owners grant access per runner group |
| Org-level | All repos in the org | Restrict to selected repos |

Runners can only belong to one group at a time. New runners go to the
default group unless specified.

### Using Runner Groups in Workflows

```yaml
# Route to any runner in a group
jobs:
  build:
    runs-on:
      group: production-runners

# Group + label combination (must match both)
jobs:
  build:
    runs-on:
      group: production-runners
      labels: ubuntu-20.04-16core
```

## Private Networking

### Approaches

| Method | Description |
|--------|-------------|
| Azure VNET | GitHub-hosted runners in your Azure Virtual Network |
| OIDC + API Gateway | Authenticate with OIDC tokens to access private APIs |
| WireGuard | Overlay network between runner and private network |

### Azure VNET

- Available on GitHub Team (org-level) and Enterprise Cloud
- GitHub-managed infrastructure with your networking policies
- Requires VNET injection; plan for 30% IP buffer over max concurrency
- Only for Ubuntu/Windows larger runners (not macOS)

### Static IP Addresses

- Enterprise Cloud only
- Up to 10 larger runners with static IP ranges (contact support for more)
- IPs assigned from GitHub's pool, unique per runner
- Use ranges to configure firewall allowlists
- Unused runners lose IP ranges after 90 days
- Only use with private repos (forks can execute code on your runner)

## Billing

### Included Minutes (Per Month, Standard Runners)

| Plan | Minutes | Artifact Storage |
|------|---------|------------------|
| GitHub Free | 2,000 | 500 MB |
| GitHub Pro | 3,000 | 1 GB |
| GitHub Team | 3,000 | 2 GB |
| GitHub Enterprise Cloud | 50,000 | 50 GB |

Free minutes apply to standard runners on private repos only.
Public repos use standard runners for free.

### Minute Multipliers (Standard Runners)

| OS | Multiplier |
|---------|------------|
| Linux | 1x |
| Windows | 2x |
| macOS | 10x |

### Larger Runner Billing

Larger runners are billed per-minute only (no included minutes, even on
private repos). No cost when idle. Billing applies to both public and
private repos.

### Cache Storage

All plans: 10 GB per repository.

### Reusable Workflow Billing

Billing is associated with the caller workflow's context, not the
called repository.

## Metrics

### Usage Metrics

Track Actions minutes consumption across:
- Workflows, jobs, repositories
- Runtime OS, runner type (hosted vs self-hosted)

### Performance Metrics

Monitor efficiency and reliability:
- Average run times, queue times, failure rates
- Breakdown by workflow, job, repository, OS, runner type

### Access

Organization owners can grant access via custom org roles with the
"View organization Actions metrics" permission.

Usage metrics do not apply minute multipliers to displayed values.

## Concurrency Limits

| Runner Type | Plan | Total Concurrent | Max macOS | Max GPU |
|-------------|------------|------------------|-----------|---------|
| Standard | Free | 20 | 5 | N/A |
| Standard | Pro | 40 | 5 | N/A |
| Standard | Team | 60 | 5 | N/A |
| Standard | Enterprise | 500 | 50 | N/A |
| Larger | Team | 1,000 | 5 | 100 |
| Larger | Enterprise | 1,000 | 50 | 100 |

macOS concurrency limits are shared between standard and larger runners.
Limits can be increased via GitHub Support ticket.
