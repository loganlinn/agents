# Migration Reference: CI/CD Platforms to GitHub Actions

Quick-reference for migrating workflows from Jenkins, Travis CI, CircleCI, GitLab CI/CD, and Azure Pipelines.

---

## Jenkins

### Concept Mapping

| Jenkins | GitHub Actions |
|---------|---------------|
| Pipeline | Workflow |
| Stage | Job (`jobs.<id>`) |
| Step | Step (`jobs.<id>.steps`) |
| Agent | Runner (`runs-on`) / Container (`container`) |
| Declarative Pipeline (Jenkinsfile) | Workflow YAML (`.github/workflows/*.yml`) |
| Scripted Pipeline (Groovy) | No equivalent (YAML only) |
| Node/Agent label | Runner label (`runs-on: [self-hosted, linux]`) |
| `environment {}` | `env:` (workflow, job, or step level) |
| `parameters {}` | `inputs:` (via `workflow_dispatch` or reusable workflows) |
| `triggers { cron() }` | `on: schedule: - cron:` |
| `triggers { upstream() }` | `jobs.<id>.needs` |
| `when {}` | `jobs.<id>.if` / `steps.if` |
| `options { timeout() }` | `jobs.<id>.timeout-minutes` |
| `options { retry() }` | No built-in retry (use action or step-level workaround) |
| `post { always {} }` | `if: always()` on a step |
| `post { failure {} }` | `if: failure()` on a step |
| `post { success {} }` | `if: success()` on a step |
| `parallel {}` | Jobs run in parallel by default; `strategy.max-parallel` |
| `matrix { axes {} }` | `strategy.matrix` |
| `tools {}` | `setup-*` actions (e.g., `actions/setup-node`) |
| `input {}` | `inputs:` |
| Shared Libraries | Reusable workflows / composite actions |
| Plugins | Actions (from GitHub Marketplace or custom) |
| Credentials | Secrets (`secrets.*`) and Variables (`vars.*`) |
| Artifacts | `actions/upload-artifact` / `actions/download-artifact` |

### YAML Comparison

**Scheduled build:**

```yaml
# Jenkins
pipeline {
  agent any
  triggers {
    cron('H/15 * * * 1-5')
  }
}
```

```yaml
# GitHub Actions
on:
  schedule:
    - cron: '*/15 * * * 1-5'
```

**Environment variables:**

```yaml
# Jenkins
pipeline {
  agent any
  environment {
    MAVEN_PATH = '/usr/local/maven'
  }
}
```

```yaml
# GitHub Actions
jobs:
  maven-build:
    env:
      MAVEN_PATH: '/usr/local/maven'
```

**Job dependencies:**

```yaml
# Jenkins
pipeline {
  triggers {
    upstream(
      upstreamProjects: 'job1,job2',
      threshold: hudson.model.Result.SUCCESS
    )
  }
}
```

```yaml
# GitHub Actions
jobs:
  job1:
  job2:
    needs: job1
  job3:
    needs: [job1, job2]
```

**Matrix build across operating systems:**

```yaml
# Jenkins
pipeline {
  agent none
  stages {
    stage('Run Tests') {
      matrix {
        axes {
          axis {
            name: 'PLATFORM'
            values: 'macos', 'linux'
          }
        }
        agent { label "${PLATFORM}" }
        stages {
          stage('test') {
            tools { nodejs "node-20" }
            steps {
              dir("scripts/myapp") {
                sh(script: "npm install -g bats")
                sh(script: "bats tests")
              }
            }
          }
        }
      }
    }
  }
}
```

```yaml
# GitHub Actions
name: demo-workflow
on:
  push:
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, ubuntu-latest]
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm install -g bats
      - run: bats tests
        working-directory: ./scripts/myapp
```

### Key Differences and Gotchas

- Jenkins uses Groovy-based DSL; GitHub Actions is YAML-only.
- Jenkins `post` blocks (always/success/failure/cleanup) have no direct equivalent. Use `if: always()`, `if: failure()`, etc. on individual steps.
- Jenkins `agent` selects a build node; GitHub Actions uses `runs-on` for runner selection and `container` for Docker-based execution.
- Jenkins stages are sequential by default; GitHub Actions jobs are parallel by default.
- Jenkins Shared Libraries map loosely to reusable workflows and composite actions.
- Jenkins `tools` directive auto-installs tools; in Actions, use `setup-*` actions.
- Self-hosted Jenkins agents map to self-hosted runners with labels.

---

## Travis CI

### Concept Mapping

| Travis CI | GitHub Actions |
|-----------|---------------|
| `.travis.yml` | `.github/workflows/*.yml` |
| Build | Workflow run |
| Job | Job (`jobs.<id>`) |
| Phase (`install`, `script`, `deploy`) | Steps (`jobs.<id>.steps`) |
| `language:` | `setup-*` actions |
| `matrix:` / `jobs:` | `strategy.matrix` |
| `branches: only:` | `on.push.branches` |
| `env:` (global/matrix) | `env:` (workflow/job/step) or `strategy.matrix.include` |
| `cache:` | `actions/cache` |
| `services:` | `services:` (under job) |
| `stages:` | `jobs.<id>.needs` |
| `if:` (on jobs) | `jobs.<id>.if` |
| `before_install` / `install` | Steps before main `run` |
| `script` | `run:` steps |
| `after_success` / `after_failure` | Steps with `if: success()` / `if: failure()` |
| `deploy` | Steps or dedicated deploy job |
| Build matrix (implicit from `language`) | Explicit `strategy.matrix` |
| Encrypted variables | Secrets (`secrets.NAME`) |
| `git: submodules:` | `actions/checkout` with `submodules:` input |

### YAML Comparison

**Branch targeting:**

```yaml
# Travis CI
branches:
  only:
    - main
    - 'mona/octocat'
```

```yaml
# GitHub Actions
on:
  push:
    branches:
      - main
      - 'mona/octocat'
```

**Build matrix:**

```yaml
# Travis CI
matrix:
  include:
    - rvm: '2.5'
    - rvm: '2.6.3'
```

```yaml
# GitHub Actions
jobs:
  build:
    strategy:
      matrix:
        ruby: ['2.5', '2.6.3']
```

**Node.js build:**

```yaml
# Travis CI
install:
  - npm install
script:
  - npm run build
  - npm test
```

```yaml
# GitHub Actions
name: Node.js CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: '16.x'
      - run: npm install
      - run: npm run build
      - run: npm test
```

**Caching:**

```yaml
# Travis CI
language: node_js
cache: npm
```

```yaml
# GitHub Actions
- name: Cache node modules
  uses: actions/cache@v4
  with:
    path: ~/.npm
    key: v1-npm-deps-${{ hashFiles('**/package-lock.json') }}
    restore-keys: v1-npm-deps-
```

**Submodule checkout:**

```yaml
# Travis CI
git:
  submodules: false
```

```yaml
# GitHub Actions
- uses: actions/checkout@v5
  with:
    submodules: false
```

**Python phase-to-step migration:**

```yaml
# Travis CI
language: python
python:
  - "3.7"
script:
  - python script.py
```

```yaml
# GitHub Actions
jobs:
  run_python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: '3.7'
          architecture: 'x64'
      - run: python script.py
```

### Key Differences and Gotchas

- Travis CI auto-detects language and provides implicit setup; GitHub Actions requires explicit `setup-*` actions.
- Travis phases (`before_install`, `install`, `script`, `after_success`, `deploy`) become sequential steps in a job.
- Travis `cache: npm` is a one-liner; GitHub Actions caching requires explicit `actions/cache` configuration.
- Travis implicit matrix from `language` versions must be explicit in `strategy.matrix`.
- Checkout is automatic in Travis; GitHub Actions requires an explicit `actions/checkout` step.
- Travis `stages` for sequential execution maps to `needs:` in GitHub Actions.
- Travis encrypted env vars become GitHub repository/org/environment secrets.

---

## CircleCI

### Concept Mapping

| CircleCI | GitHub Actions |
|----------|---------------|
| `.circleci/config.yml` | `.github/workflows/*.yml` |
| Workflow | Workflow |
| Job | Job (`jobs.<id>`) |
| Step | Step (`jobs.<id>.steps`) |
| Orb | Action (from Marketplace or custom) |
| Executor / `docker:` image | `runs-on:` / `container:` |
| `requires:` (in workflow) | `needs:` |
| `context:` | Environment secrets |
| `environment:` | `env:` |
| Commands (reusable steps) | Composite actions |
| `persist_to_workspace` / `attach_workspace` | `actions/upload-artifact` / `actions/download-artifact` |
| `save_cache` / `restore_cache` | `actions/cache` |
| `store_artifacts` | `actions/upload-artifact` |
| `store_test_results` | Third-party test reporting actions |
| YAML anchors (`&` / `*`) | YAML anchors or `strategy.matrix` |
| Pipeline parameters | `inputs:` (via `workflow_dispatch` or reusable workflows) |
| Automatic test splitting | No built-in equivalent |
| Docker Layer Caching (DLC) | No built-in equivalent |
| `filters: branches:` | `on.push.branches` / `on.pull_request.branches` |
| `when` / `unless` (step level) | `if:` (step level) |
| Resource class | Runner selection (`runs-on:`) |

### YAML Comparison

**Caching:**

```yaml
# CircleCI
- restore_cache:
    keys:
      - v1-npm-deps-{{ checksum "package-lock.json" }}
      - v1-npm-deps-
```

```yaml
# GitHub Actions
- name: Cache node modules
  uses: actions/cache@v4
  with:
    path: ~/.npm
    key: v1-npm-deps-${{ hashFiles('**/package-lock.json') }}
    restore-keys: v1-npm-deps-
```

**Persisting data between jobs:**

```yaml
# CircleCI
- persist_to_workspace:
    root: workspace
    paths:
      - math-homework.txt
# ...later job:
- attach_workspace:
    at: /tmp/workspace
```

```yaml
# GitHub Actions
- name: Upload math result for job 1
  uses: actions/upload-artifact@v4
  with:
    name: homework
    path: math-homework.txt
# ...later job:
- name: Download math result for job 1
  uses: actions/download-artifact@v5
  with:
    name: homework
```

**Service containers (database):**

```yaml
# CircleCI
version: 2.1
jobs:
  ruby-26:
    docker:
      - image: circleci/ruby:2.6.3-node-browsers-legacy
        environment:
          PGHOST: localhost
          PGUSER: administrate
          RAILS_ENV: test
      - image: postgres:10.1-alpine
        environment:
          POSTGRES_USER: administrate
          POSTGRES_DB: ruby26
          POSTGRES_PASSWORD: ""
    working_directory: ~/administrate
    steps:
      - checkout
      - run: bundle install --path vendor/bundle
      - run: dockerize -wait tcp://localhost:5432 -timeout 1m
      - run: cp .sample.env .env
      - run: bundle exec rake db:setup
      - run: bundle exec rake
```

```yaml
# GitHub Actions
name: Containers
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    container: circleci/ruby:2.6.3-node-browsers-legacy
    env:
      PGHOST: postgres
      PGUSER: administrate
      RAILS_ENV: test
    services:
      postgres:
        image: postgres:10.1-alpine
        env:
          POSTGRES_USER: administrate
          POSTGRES_DB: ruby25
          POSTGRES_PASSWORD: ""
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - name: Setup file system permissions
        run: sudo chmod -R 777 $GITHUB_WORKSPACE /github /__w/_temp
      - uses: actions/checkout@v5
      - name: Install dependencies
        run: bundle install --path vendor/bundle
      - name: Setup environment configuration
        run: cp .sample.env .env
      - name: Setup database
        run: bundle exec rake db:setup
      - name: Run tests
        run: bundle exec rake
```

### Key Differences and Gotchas

- CircleCI allows multiple workflows in one `config.yml`; GitHub Actions requires one YAML file per workflow.
- CircleCI orbs map to GitHub Actions from the Marketplace but are not 1:1 compatible.
- CircleCI's first `docker:` image is the primary container; in Actions, use `container:` for the primary and `services:` for sidecar containers.
- CircleCI pre-built images set `USER` to `circleci`, causing permission issues on Actions runners. You may need `sudo chmod` workarounds or switch to standard images.
- CircleCI `persist_to_workspace` / `attach_workspace` becomes `upload-artifact` / `download-artifact` (artifacts are immutable and versioned).
- CircleCI automatic test splitting has no built-in GitHub Actions equivalent.
- CircleCI Docker Layer Caching (DLC) has no built-in GitHub Actions equivalent.
- Service container hostname: in CircleCI, sidecar services are on `localhost`; in Actions with `container:`, use the service name (e.g., `postgres`) as the hostname.

---

## GitLab CI/CD

### Concept Mapping

| GitLab CI/CD | GitHub Actions |
|--------------|---------------|
| `.gitlab-ci.yml` | `.github/workflows/*.yml` |
| Pipeline | Workflow run |
| Stage | Group of jobs with `needs:` |
| Job | Job (`jobs.<id>`) |
| `script:` | `run:` (in a step) |
| `image:` | `container:` |
| `services:` | `services:` |
| `tags:` (runner selection) | `runs-on:` |
| `rules:` / `only:` / `except:` | `on:` triggers + `jobs.<id>.if` |
| `variables:` | `env:` |
| `stages:` (ordering) | `jobs.<id>.needs` |
| `needs:` (DAG) | `jobs.<id>.needs` |
| `before_script:` | Initial steps in a job |
| `after_script:` | Steps with `if: always()` |
| `artifacts:` | `actions/upload-artifact` |
| `cache:` | `actions/cache` |
| `include:` | Reusable workflows (`workflow_call`) |
| `extends:` | YAML anchors or reusable workflows |
| `trigger:` (child pipeline) | `workflow_call` or `workflow_dispatch` |
| CI/CD variables (project/group) | Secrets and variables (repo/org/environment) |
| `environment:` | `environment:` (with protection rules) |
| `GIT_CHECKOUT` variable | `actions/checkout` step |
| Shared Runners | GitHub-hosted runners |
| Group Runners | Organization-level self-hosted runners |

### YAML Comparison

**Basic job:**

```yaml
# GitLab CI/CD
job1:
  variables:
    GIT_CHECKOUT: "true"
  script:
    - echo "Run your script here"
```

```yaml
# GitHub Actions
jobs:
  job1:
    steps:
      - uses: actions/checkout@v5
      - run: echo "Run your script here"
```

**Runner selection:**

```yaml
# GitLab CI/CD
windows_job:
  tags:
    - windows
  script:
    - echo Hello, %USERNAME%!

linux_job:
  tags:
    - linux
  script:
    - echo "Hello, $USER!"
```

```yaml
# GitHub Actions
windows_job:
  runs-on: windows-latest
  steps:
    - run: echo Hello, %USERNAME%!

linux_job:
  runs-on: ubuntu-latest
  steps:
    - run: echo "Hello, $USER!"
```

**Docker image:**

```yaml
# GitLab CI/CD
my_job:
  image: node:20-bookworm-slim
```

```yaml
# GitHub Actions
jobs:
  my_job:
    container: node:20-bookworm-slim
```

**Conditionals:**

```yaml
# GitLab CI/CD
deploy_prod:
  stage: deploy
  script:
    - echo "Deploy to production server"
  rules:
    - if: '$CI_COMMIT_BRANCH == "master"'
```

```yaml
# GitHub Actions
jobs:
  deploy_prod:
    if: contains( github.ref, 'master')
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploy to production server"
```

**Job dependencies (stages):**

```yaml
# GitLab CI/CD
stages:
  - build
  - test
  - deploy

build_a:
  stage: build
  script:
    - echo "This job will run first."

build_b:
  stage: build
  script:
    - echo "This job will run first, in parallel with build_a."

test_ab:
  stage: test
  script:
    - echo "This job will run after build_a and build_b have finished."

deploy_ab:
  stage: deploy
  script:
    - echo "This job will run after test_ab is complete"
```

```yaml
# GitHub Actions
jobs:
  build_a:
    runs-on: ubuntu-latest
    steps:
      - run: echo "This job will be run first."

  build_b:
    runs-on: ubuntu-latest
    steps:
      - run: echo "This job will be run first, in parallel with build_a"

  test_ab:
    runs-on: ubuntu-latest
    needs: [build_a, build_b]
    steps:
      - run: echo "This job will run after build_a and build_b have finished"

  deploy_ab:
    runs-on: ubuntu-latest
    needs: [test_ab]
    steps:
      - run: echo "This job will run after test_ab is complete"
```

**Service containers:**

```yaml
# GitLab CI/CD
container-job:
  variables:
    POSTGRES_PASSWORD: postgres
    POSTGRES_HOST: postgres
    POSTGRES_PORT: 5432
  image: node:20-bookworm-slim
  services:
    - postgres
  script:
    - npm ci
    - node client.js
  tags:
    - docker
```

```yaml
# GitHub Actions
jobs:
  container-job:
    runs-on: ubuntu-latest
    container: node:20-bookworm-slim
    services:
      postgres:
        image: postgres
        env:
          POSTGRES_PASSWORD: postgres
    steps:
      - uses: actions/checkout@v5
      - name: Install dependencies
        run: npm ci
      - name: Connect to PostgreSQL
        run: node client.js
        env:
          POSTGRES_HOST: postgres
          POSTGRES_PORT: 5432
```

### Key Differences and Gotchas

- GitLab uses `stages:` for implicit ordering; GitHub Actions uses explicit `needs:` (DAG-based).
- GitLab CI/CD checkout is automatic (controlled by `GIT_CHECKOUT` variable); GitHub Actions requires explicit `actions/checkout`.
- GitLab `rules:` is more expressive than Actions `if:` (supports `changes:`, `exists:`, `allow_failure`).
- GitLab `before_script` / `after_script` have no direct equivalents; use initial/final steps with appropriate `if:` conditions.
- GitLab `include:` for reusing config maps to reusable workflows (`workflow_call`).
- GitLab `tags:` for runner routing becomes `runs-on:` labels in Actions.
- GitLab CI/CD variables in `rules:` use `$VAR` syntax; Actions `if:` uses `github.*`, `env.*`, `secrets.*` contexts.
- GitLab pipeline schedules are configured via UI; Actions schedules are in the workflow YAML (`on: schedule`).
- Single `.gitlab-ci.yml` vs. multiple workflow files in `.github/workflows/`.

---

## Azure Pipelines

### Concept Mapping

| Azure Pipelines | GitHub Actions |
|-----------------|---------------|
| `azure-pipelines.yml` | `.github/workflows/*.yml` |
| Pipeline | Workflow |
| Stage | Group of jobs (use `needs:` for ordering) |
| Job | Job (`jobs.<id>`) |
| Step | Step (`jobs.<id>.steps`) |
| Task (`task: Name@version`) | Action (`uses: owner/action@version`) |
| `pool: vmImage:` | `runs-on:` |
| `dependsOn:` | `needs:` |
| `condition:` | `if:` |
| `variables:` | `env:` |
| Variable groups | Secrets / environment variables |
| `script:` | `run:` |
| `bash:` | `run:` with `shell: bash` |
| `pwsh:` | `run:` with `shell: pwsh` |
| `powershell:` / `task: PowerShell@2` | `run:` with `shell: powershell` |
| `resources: containers:` | `container:` / `services:` |
| `trigger:` | `on: push:` |
| `pr:` | `on: pull_request:` |
| `schedules:` | `on: schedule:` |
| Templates | Reusable workflows (`workflow_call`) / composite actions |
| Service connections | Secrets (e.g., `AZURE_CREDENTIALS`) |
| Artifact publish/download | `actions/upload-artifact` / `actions/download-artifact` |
| Classic editor (GUI) | No equivalent (YAML only) |
| Stages (deployment) | Separate workflow files or `environment:` with protection rules |
| Agent capabilities | Runner labels |
| `checkout: self` | `actions/checkout` |

### YAML Comparison

**Script steps:**

```yaml
# Azure Pipelines
jobs:
  - job: scripts
    pool:
      vmImage: 'windows-latest'
    steps:
      - script: echo "This step runs in the default shell"
      - bash: echo "This step runs in bash"
      - pwsh: Write-Host "This step runs in PowerShell Core"
      - task: PowerShell@2
        inputs:
          script: Write-Host "This step runs in PowerShell"
```

```yaml
# GitHub Actions
jobs:
  scripts:
    runs-on: windows-latest
    steps:
      - run: echo "This step runs in the default shell"
      - run: echo "This step runs in bash"
        shell: bash
      - run: Write-Host "This step runs in PowerShell Core"
        shell: pwsh
      - run: Write-Host "This step runs in PowerShell"
        shell: powershell
```

**Conditionals:**

```yaml
# Azure Pipelines
jobs:
  - job: conditional
    pool:
      vmImage: 'ubuntu-latest'
    steps:
      - script: echo "This step runs with str equals 'ABC' and num equals 123"
        condition: and(eq(variables.str, 'ABC'), eq(variables.num, 123))
```

```yaml
# GitHub Actions
jobs:
  conditional:
    runs-on: ubuntu-latest
    steps:
      - run: echo "This step runs with str equals 'ABC' and num equals 123"
        if: ${{ env.str == 'ABC' && env.num == 123 }}
```

**Job dependencies:**

```yaml
# Azure Pipelines
jobs:
  - job: initial
    pool:
      vmImage: 'ubuntu-latest'
    steps:
      - script: echo "This job will be run first."
  - job: fanout1
    pool:
      vmImage: 'ubuntu-latest'
    dependsOn: initial
    steps:
      - script: echo "This job will run after initial, in parallel with fanout2."
  - job: fanout2
    pool:
      vmImage: 'ubuntu-latest'
    dependsOn: initial
    steps:
      - script: echo "This job will run after initial, in parallel with fanout1."
  - job: fanin
    pool:
      vmImage: 'ubuntu-latest'
    dependsOn: [fanout1, fanout2]
    steps:
      - script: echo "This job will run after fanout1 and fanout2 have finished."
```

```yaml
# GitHub Actions
jobs:
  initial:
    runs-on: ubuntu-latest
    steps:
      - run: echo "This job will be run first."
  fanout1:
    runs-on: ubuntu-latest
    needs: initial
    steps:
      - run: echo "This job will run after initial, in parallel with fanout2."
  fanout2:
    runs-on: ubuntu-latest
    needs: initial
    steps:
      - run: echo "This job will run after initial, in parallel with fanout1."
  fanin:
    runs-on: ubuntu-latest
    needs: [fanout1, fanout2]
    steps:
      - run: echo "This job will run after fanout1 and fanout2 have finished."
```

**Tasks to actions:**

```yaml
# Azure Pipelines
jobs:
  - job: run_python
    pool:
      vmImage: 'ubuntu-latest'
    steps:
      - task: UsePythonVersion@0
        inputs:
          versionSpec: '3.7'
          architecture: 'x64'
      - script: python script.py
```

```yaml
# GitHub Actions
jobs:
  run_python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: '3.7'
          architecture: 'x64'
      - run: python script.py
```

### Key Differences and Gotchas

- Azure Pipelines default shell on Windows is `cmd.exe`; GitHub Actions defaults to PowerShell on Windows. Specify `shell: cmd` if migrating cmd scripts.
- Azure Pipelines `condition:` uses function syntax (`eq()`, `and()`); Actions `if:` uses infix operators (`==`, `&&`).
- Azure Pipelines allows omitting job structure for single-job pipelines; Actions always requires explicit `jobs:` structure.
- Azure Pipelines `stages:` for deployment workflows must be split into separate workflow files or use `environment:` protection rules in Actions.
- Azure Pipelines tasks use `task: Name@version` format; Actions uses `uses: owner/repo@version`.
- Azure Pipelines `dependsOn:` becomes `needs:` in Actions.
- Azure Pipelines can error on `stderr` output; Actions does not support this, but uses "fail fast" shell behavior by default.
- Azure Pipelines Classic Editor (GUI) has no equivalent in Actions.
- Azure Pipelines variable groups map to GitHub Actions environment secrets or organization-level secrets.
