# Security Reference

Secrets management, OIDC authentication, and security best practices.

## Secrets

### Creating Secrets

**Repository secrets**: Settings > Secrets and variables > Actions > New repository secret

**Environment secrets**: Settings > Environments > [env] > Add secret

**Organization secrets**: Organization Settings > Secrets and variables > Actions

### Using Secrets

```yaml
steps:
  # As environment variable
  - run: echo "Using secret"
    env:
      API_KEY: ${{ secrets.API_KEY }}

  # As action input
  - uses: some-action@v1
    with:
      token: ${{ secrets.TOKEN }}
```

### Secrets Behavior

- Secrets are redacted from logs automatically
- Cannot be used directly in `if:` conditions
- Empty string if secret doesn't exist
- Not passed to workflows from forked repositories
- Not passed to reusable workflows (must pass explicitly)
- Max size: 48 KB per secret

### Check if Secret Exists

```yaml
jobs:
  build:
    env:
      HAS_SECRET: ${{ secrets.MY_SECRET != '' }}
    steps:
      - if: env.HAS_SECRET == 'true'
        run: echo "Secret is set"
```

### Pass Secrets to Reusable Workflows

```yaml
jobs:
  call:
    uses: ./.github/workflows/reusable.yml
    secrets:
      token: ${{ secrets.TOKEN }}

  # Or inherit all secrets
  call-inherit:
    uses: ./.github/workflows/reusable.yml
    secrets: inherit
```

## GITHUB_TOKEN

Automatically created token for each workflow run.

### Default Permissions

Depends on repository settings. Can be:
- **Permissive**: Read and write for most scopes
- **Restricted**: Read-only for contents and metadata

### Setting Permissions

```yaml
# Workflow level
permissions:
  contents: read
  pull-requests: write
  issues: write

# Job level
jobs:
  build:
    permissions:
      contents: read
```

### Permission Scopes

| Permission | Description |
|------------|-------------|
| `actions` | Manage Actions |
| `attestations` | Artifact attestations |
| `checks` | Check runs/suites |
| `contents` | Repository contents, releases |
| `deployments` | Deployments |
| `discussions` | Discussions |
| `id-token` | OIDC tokens |
| `issues` | Issues |
| `packages` | GitHub Packages |
| `pages` | GitHub Pages |
| `pull-requests` | Pull requests |
| `security-events` | Code scanning |
| `statuses` | Commit statuses |

### Using GITHUB_TOKEN

```yaml
steps:
  - uses: actions/checkout@v5

  - run: |
      gh pr comment ${{ github.event.pull_request.number }} \
        --body "Build complete!"
    env:
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  - uses: actions/github-script@v7
    with:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      script: |
        github.rest.issues.createComment({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: context.issue.number,
          body: 'Hello!'
        })
```

### Token Limitations

- Cannot trigger new workflow runs
- Cannot access other repositories
- Cannot push to protected branches without bypass

## OIDC (OpenID Connect)

Request short-lived tokens from cloud providers without storing credentials.

### How It Works

1. Workflow requests OIDC token from GitHub
2. GitHub issues JWT with workflow claims
3. Cloud provider validates JWT
4. Cloud provider issues short-lived access token

### Required Permission

```yaml
permissions:
  id-token: write
  contents: read
```

### AWS OIDC

**1. Configure AWS Identity Provider**

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

**2. Create IAM Role with Trust Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
```

**3. Use in Workflow**

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/my-role
          aws-region: us-east-1

      - run: aws s3 ls
```

### OIDC Subject Claims

Format: `repo:OWNER/REPO:CONTEXT`

Examples:
- `repo:octo-org/octo-repo:ref:refs/heads/main` - Main branch
- `repo:octo-org/octo-repo:environment:production` - Production environment
- `repo:octo-org/octo-repo:pull_request` - Any PR

### Trust Policy Conditions

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:sub": "repo:owner/repo:environment:production"
    }
  }
}
```

Or with wildcards:

```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:owner/repo:*"
    }
  }
}
```

### Azure OIDC

**1. Create an Entra ID Application and Service Principal**

Register an application in Microsoft Entra ID (formerly Azure AD):
- Go to Azure Portal > Microsoft Entra ID > App registrations > New registration
- Note the Application (client) ID and Directory (tenant) ID

**2. Add Federated Credentials**

In the app registration, go to Certificates & secrets > Federated credentials > Add credential:
- Federated credential scenario: GitHub Actions deploying Azure resources
- Organization: your GitHub org or username
- Repository: your repository name
- Entity type: Branch, Environment, Pull Request, or Tag
- GitHub branch name: `main` (or your target)
- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange` (recommended default)

**3. Assign Roles to the Service Principal**

Grant the service principal access to Azure resources:
- Go to the target resource (e.g., Resource Group) > Access control (IAM) > Add role assignment
- Assign the appropriate role (e.g., Contributor) to the app registration's service principal

**4. Subject Claim Format**

Azure federated credentials match on the subject claim from the OIDC token:
- Branch: `repo:OWNER/REPO:ref:refs/heads/BRANCH`
- Environment: `repo:OWNER/REPO:environment:ENVIRONMENT_NAME`
- Pull request: `repo:OWNER/REPO:pull_request`
- Tag: `repo:OWNER/REPO:ref:refs/tags/TAG`

**5. Store Configuration as GitHub Secrets**

Create these repository secrets (these are not sensitive credentials, but secrets keep them out of logs):
- `AZURE_CLIENT_ID` - Application (client) ID
- `AZURE_TENANT_ID` - Directory (tenant) ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

**6. Use in Workflow**

```yaml
name: Deploy to Azure
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - run: |
          az account show
          az group list
```

### GCP OIDC

**1. Create a Workload Identity Pool**

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --project="PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

**2. Create a Workload Identity Provider**

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

**3. Bind a Service Account**

Allow the GitHub OIDC provider to impersonate a GCP service account:

```bash
gcloud iam service-accounts add-iam-policy-binding "SA_NAME@PROJECT_ID.iam.gserviceaccount.com" \
  --project="PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/OWNER/REPO"
```

To restrict to a specific branch, use the `subject` attribute instead:

```bash
--member="principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/subject/repo:OWNER/REPO:ref:refs/heads/main"
```

**4. Subject Claim Format**

GCP matches on the `subject` claim from the OIDC token (same format as other providers):
- Branch: `repo:OWNER/REPO:ref:refs/heads/BRANCH`
- Environment: `repo:OWNER/REPO:environment:ENVIRONMENT_NAME`
- Pull request: `repo:OWNER/REPO:pull_request`
- Tag: `repo:OWNER/REPO:ref:refs/tags/TAG`

**5. Get the Workload Identity Provider Resource Name**

```bash
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
```

This returns: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider`

**6. Use in Workflow**

```yaml
name: Deploy to GCP
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'SA_NAME@PROJECT_ID.iam.gserviceaccount.com'

      - uses: google-github-actions/setup-gcloud@v2

      - run: |
          gcloud auth login --brief --cred-file="${{ steps.auth.outputs.credentials_file_path }}"
          gcloud services list
```

## Script Injection Prevention

### Dangerous Pattern

```yaml
# VULNERABLE - user input directly in script
- run: echo "${{ github.event.issue.title }}"
```

If title is `"; rm -rf / #`, this becomes:
```bash
echo ""; rm -rf / #"
```

### Safe Pattern

```yaml
# SAFE - use environment variable
- run: echo "$TITLE"
  env:
    TITLE: ${{ github.event.issue.title }}
```

### Untrusted Inputs

These contexts can contain attacker-controlled data:

- `github.event.issue.title`
- `github.event.issue.body`
- `github.event.pull_request.title`
- `github.event.pull_request.body`
- `github.event.comment.body`
- `github.event.review.body`
- `github.event.head_commit.message`
- `github.event.commits[*].message`
- `github.head_ref`

### Safe Contexts

These are generally safe:

- `github.repository`
- `github.repository_owner`
- `github.actor`
- `github.sha`
- `github.ref`
- `github.event_name`

## Pull Request Security

### pull_request vs pull_request_target

| Event | Runs On | Secrets | Safe for Forks |
|-------|---------|---------|----------------|
| `pull_request` | Merge commit | No (from forks) | Yes |
| `pull_request_target` | Base branch | Yes | No (be careful) |

### Safe PR Workflow Pattern

```yaml
on: pull_request

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        # Checks out PR merge commit, safe

      - run: npm test
        # Tests PR code, safe
```

### Dangerous Pattern (Avoid)

```yaml
on: pull_request_target

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # DANGEROUS - runs PR code with secrets access
      - uses: actions/checkout@v5
        with:
          ref: ${{ github.event.pull_request.head.sha }}

      - run: npm test
```

### Safe pull_request_target Pattern

```yaml
on: pull_request_target

jobs:
  # Job 1: Build/test without secrets (safe)
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm test

  # Job 2: Deploy with secrets (only trusted code)
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        # Checks out base branch, safe

      - run: ./deploy.sh
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

## Permissions Best Practices

### Principle of Least Privilege

```yaml
permissions:
  contents: read    # Only what's needed

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
```

### Disable All Permissions

```yaml
permissions: {}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
```

## Environment Protection

### Configure Environments

1. Settings > Environments > New environment
2. Add protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches

### Use in Workflow

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://example.com
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

### Environment Secrets

Secrets scoped to an environment:
- Only available to jobs targeting that environment
- Require environment approval if configured

## Dependabot Security

### Dependabot Secrets

Workflows triggered by Dependabot:
- Use read-only GITHUB_TOKEN
- Don't have access to regular secrets
- Can use Dependabot secrets

### Handle Dependabot PRs

```yaml
on: pull_request

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm test

  deploy:
    if: github.actor != 'dependabot[bot]'
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

## Artifact Attestation

Create SLSA provenance and SBOM attestations for build artifacts and container images.

### Build Provenance for Binaries

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write

steps:
  - uses: actions/checkout@v5
  - run: npm run build
  - uses: actions/attest-build-provenance@v3
    with:
      subject-path: 'dist/*.js'
```

### Build Provenance for Container Images

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
  packages: write

steps:
  - uses: actions/checkout@v5

  - uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}

  - id: push
    uses: docker/build-push-action@v6
    with:
      push: true
      tags: ghcr.io/${{ github.repository }}:latest

  - uses: actions/attest-build-provenance@v3
    with:
      subject-name: ghcr.io/${{ github.repository }}
      subject-digest: ${{ steps.push.outputs.digest }}
      push-to-registry: true
```

### SBOM Attestation

Generate signed SBOM (Software Bill of Materials) attestations using `actions/attest-sbom`.

**Binary SBOM attestation:**

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write

steps:
  - uses: actions/checkout@v5
  - run: npm run build

  - uses: anchore/sbom-action@v0
    with:
      path: ./dist
      output-file: sbom.spdx.json

  - uses: actions/attest-sbom@v2
    with:
      subject-path: 'dist/my-app'
      sbom-path: 'sbom.spdx.json'
```

**Container image SBOM attestation:**

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
  packages: write

steps:
  - id: push
    uses: docker/build-push-action@v6
    with:
      push: true
      tags: ghcr.io/${{ github.repository }}:latest

  - uses: anchore/sbom-action@v0
    with:
      image: ghcr.io/${{ github.repository }}:latest
      output-file: sbom.spdx.json

  - uses: actions/attest-sbom@v2
    with:
      subject-name: ghcr.io/${{ github.repository }}
      subject-digest: ${{ steps.push.outputs.digest }}
      sbom-path: 'sbom.spdx.json'
      push-to-registry: true
```

### Verifying Attestations with GitHub CLI

**Verify a binary:**

```bash
gh attestation verify dist/my-app -R OWNER/REPO
```

**Verify a container image:**

```bash
docker login ghcr.io
gh attestation verify oci://ghcr.io/OWNER/REPO:tag -R OWNER/REPO
```

**Verify an SBOM attestation (SPDX):**

```bash
gh attestation verify dist/my-app \
  -R OWNER/REPO \
  --predicate-type https://spdx.dev/Document/v2.3
```

**Verify with JSON output for inspection:**

```bash
gh attestation verify dist/my-app \
  -R OWNER/REPO \
  --predicate-type https://spdx.dev/Document/v2.3 \
  --format json \
  --jq '.[].verificationResult.statement.predicate'
```

### Enforcing Attestations

Use `gh attestation verify` in deployment pipelines to gate deployments on valid attestations:

```yaml
deploy:
  needs: build
  runs-on: ubuntu-latest
  steps:
    - uses: actions/download-artifact@v4
      with:
        name: my-artifact

    - name: Verify attestation before deploy
      env:
        GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        gh attestation verify my-app \
          -R ${{ github.repository }}

    - name: Deploy
      run: ./deploy.sh
```

For organization-wide enforcement, repository admins can require artifact attestations
via repository rulesets (Settings > Rules > Rulesets), which block artifacts without
valid provenance from being deployed.

## Security Checklist

1. **Secrets**
   - [ ] Use secrets, not hardcoded values
   - [ ] Use OIDC instead of long-lived credentials
   - [ ] Rotate secrets regularly

2. **Permissions**
   - [ ] Set minimal permissions
   - [ ] Use `permissions: {}` and grant explicitly

3. **Dependencies**
   - [ ] Pin action versions to SHA
   - [ ] Enable Dependabot for actions

4. **Code**
   - [ ] Never use untrusted input in `run:` directly
   - [ ] Use environment variables for user input

5. **Pull Requests**
   - [ ] Use `pull_request` not `pull_request_target` when possible
   - [ ] Require approval for fork PRs
   - [ ] Don't run untrusted code with secrets
