# Runners Reference

GitHub-hosted and self-hosted runner configuration.

## GitHub-Hosted Runners

### Standard Runners (Public Repos)

| Label | OS | CPUs | RAM | Storage |
|-------|-----|------|-----|---------|
| `ubuntu-latest` | Ubuntu 24.04 | 4 | 16 GB | 14 GB |
| `ubuntu-24.04` | Ubuntu 24.04 | 4 | 16 GB | 14 GB |
| `ubuntu-22.04` | Ubuntu 22.04 | 4 | 16 GB | 14 GB |
| `ubuntu-slim` | Ubuntu | 1 | 5 GB | 14 GB |
| `windows-latest` | Windows Server 2025 | 4 | 16 GB | 14 GB |
| `windows-2025` | Windows Server 2025 | 4 | 16 GB | 14 GB |
| `windows-2022` | Windows Server 2022 | 4 | 16 GB | 14 GB |
| `macos-latest` | macOS 15 (arm64) | 3 | 7 GB | 14 GB |
| `macos-15` | macOS 15 (arm64) | 3 | 7 GB | 14 GB |
| `macos-14` | macOS 14 (arm64) | 3 | 7 GB | 14 GB |
| `macos-13` | macOS 13 (Intel) | 4 | 14 GB | 14 GB |

### ARM64 Runners

| Label | OS | CPUs | RAM |
|-------|-----|------|-----|
| `ubuntu-24.04-arm` | Ubuntu 24.04 | 4 | 16 GB |
| `ubuntu-22.04-arm` | Ubuntu 22.04 | 4 | 16 GB |
| `windows-11-arm` | Windows 11 | 4 | 16 GB |

### Private Repos (Reduced Specs)

Private repos have reduced resources:
- Linux/Windows: 2 CPUs, 7 GB RAM
- Uses free minutes allocation

### Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
```

### Runner Images

Pre-installed software documentation:
- [Ubuntu 24.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
- [Ubuntu 22.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2204-Readme.md)
- [Windows 2022](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md)
- [macOS 14](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-arm64-Readme.md)

### Larger Runners

Available on GitHub Team and Enterprise:
- Up to 64 CPUs
- Up to 256 GB RAM
- GPU runners
- Custom images

```yaml
runs-on: ubuntu-latest-16-cores
runs-on: windows-latest-8-cores
```

## Self-Hosted Runners

### Setup

1. Settings > Actions > Runners > New self-hosted runner
2. Download and configure runner
3. Start runner service

### Labels

```yaml
runs-on: [self-hosted, linux, x64]
runs-on: [self-hosted, windows, gpu]
```

Default labels:
- `self-hosted`
- OS: `linux`, `windows`, `macos`
- Architecture: `x64`, `arm`, `arm64`

### Custom Labels

Add in runner config or via UI:

```yaml
runs-on: [self-hosted, production, high-memory]
```

### Runner Groups

Organize runners into groups with access controls.

```yaml
runs-on:
  group: production-runners

# With labels
runs-on:
  group: production-runners
  labels: linux
```

## Choosing Runners

### Basic Selection

```yaml
runs-on: ubuntu-latest
```

### Multiple Labels (AND)

```yaml
# Must have ALL labels
runs-on: [self-hosted, linux, x64, production]
```

### Dynamic Selection

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
runs-on: ${{ matrix.os }}
```

### Input-Based Selection

```yaml
on:
  workflow_dispatch:
    inputs:
      runner:
        type: choice
        options:
          - ubuntu-latest
          - self-hosted

jobs:
  build:
    runs-on: ${{ inputs.runner }}
```

## Runner Environment

### Environment Variables

| Variable | Description |
|----------|-------------|
| `RUNNER_OS` | linux, Windows, macOS |
| `RUNNER_ARCH` | X64, ARM, ARM64 |
| `RUNNER_NAME` | Runner name |
| `RUNNER_TEMP` | Temp directory |
| `RUNNER_TOOL_CACHE` | Tool cache directory |
| `GITHUB_WORKSPACE` | Workspace directory |

### runner Context

```yaml
steps:
  - run: |
      echo "OS: ${{ runner.os }}"
      echo "Arch: ${{ runner.arch }}"
      echo "Name: ${{ runner.name }}"
      echo "Temp: ${{ runner.temp }}"
      echo "Tool Cache: ${{ runner.tool_cache }}"
```

### Platform-Specific Steps

```yaml
steps:
  - if: runner.os == 'Linux'
    run: sudo apt-get install -y package

  - if: runner.os == 'Windows'
    run: choco install package

  - if: runner.os == 'macOS'
    run: brew install package
```

## Container Jobs

Run jobs in a container instead of directly on runner.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:20
      env:
        NODE_ENV: production
      ports:
        - 8080
      volumes:
        - /data:/container/data
      options: --cpus 1 --memory 512m
```

### With Credentials

```yaml
container:
  image: ghcr.io/owner/image:latest
  credentials:
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Simple Form

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: node:20
```

## Service Containers

Run services alongside your job.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
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
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - run: |
          # Connect to services
          psql -h localhost -U test -d test
          redis-cli -h localhost ping
```

### Service Networking

**Direct on runner (ports mapped):**
```yaml
services:
  redis:
    image: redis
    ports:
      - 6379:6379

steps:
  - run: redis-cli -h localhost -p 6379 ping
```

**In container job (use service name):**
```yaml
container: node:20
services:
  redis:
    image: redis

steps:
  - run: redis-cli -h redis ping
```

### Accessing Service Ports

```yaml
services:
  nginx:
    image: nginx
    ports:
      - 8080:80

steps:
  - run: curl http://localhost:8080
```

Dynamic port:
```yaml
services:
  nginx:
    image: nginx
    ports:
      - 80  # Random host port

steps:
  - run: curl http://localhost:${{ job.services.nginx.ports['80'] }}
```

## Timeouts

### Job Timeout

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Default: 360 (6 hours)
```

### Step Timeout

```yaml
steps:
  - run: ./long-task.sh
    timeout-minutes: 10
```

## Parallelism

### Matrix Parallelism

```yaml
jobs:
  test:
    strategy:
      max-parallel: 2  # Limit concurrent jobs
      matrix:
        version: [10, 12, 14, 16]
```

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Runner Caching

### Tool Cache

Pre-installed tools are cached:
- Node.js
- Python
- Ruby
- Go
- Java

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
```

### Dependency Caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-
```

## Troubleshooting

### Check Runner Info

```yaml
steps:
  - run: |
      echo "Runner OS: ${{ runner.os }}"
      echo "Runner Arch: ${{ runner.arch }}"
      echo "Runner Name: ${{ runner.name }}"
      cat /etc/os-release || ver
```

### Debug Mode

Enable by setting secret:
- `ACTIONS_STEP_DEBUG` = `true`
- `ACTIONS_RUNNER_DEBUG` = `true`

Or re-run with debug logging enabled.

### Common Issues

1. **Runner not picking up jobs**
   - Check labels match
   - Verify runner is online
   - Check runner group access

2. **Out of disk space**
   - Use `actions/checkout@v5` with `sparse-checkout`
   - Clean up after builds
   - Use larger runner

3. **Command not found**
   - Check pre-installed software
   - Use setup actions
   - Install manually

4. **Network issues**
   - Check firewall rules
   - Verify GitHub connectivity
   - Check service container ports
