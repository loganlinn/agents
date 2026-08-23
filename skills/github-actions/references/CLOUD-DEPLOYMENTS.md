# Cloud Deployments Reference

OIDC authentication and deployment workflows for AWS, Azure, and GCP.

## OIDC Fundamentals

All cloud providers follow the same pattern: request a GitHub OIDC token, exchange
it for a short-lived cloud credential. No long-lived secrets required.

Required permission for all OIDC workflows:

```yaml
permissions:
  id-token: write
  contents: read
```

---

## AWS

### OIDC Setup

IAM Identity Provider config:
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

**Trust Policy (specific branch):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456123456:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Trust Policy (environment-scoped):**

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:environment:prod"
  }
}
```

**Trust Policy (wildcard):**

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

Sub claim formats:
- Branch: `repo:ORG/REPO:ref:refs/heads/BRANCH`
- Tag: `repo:ORG/REPO:ref:refs/tags/TAG`
- PR: `repo:ORG/REPO:pull_request`
- Environment: `repo:ORG/REPO:environment:ENV_NAME`

### AWS Authentication Steps

```yaml
# OIDC (preferred)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/my-role
    role-session-name: github-actions-session
    aws-region: us-east-1

# Static credentials (fallback)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

### Deploy to ECS

```yaml
name: Deploy to Amazon ECS
on:
  push:
    branches: [main]
env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: my-app
  ECS_SERVICE: my-service
  ECS_CLUSTER: my-cluster
  ECS_TASK_DEFINITION: .aws/task-definition.json
  CONTAINER_NAME: my-container
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy-role
          aws-region: ${{ env.AWS_REGION }}
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build, tag, and push image
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
      - name: Render ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ${{ env.ECS_TASK_DEFINITION }}
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}
      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```

### Deploy to S3 (with CloudFront invalidation)

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/s3-deploy-role
      aws-region: us-east-1
  - run: aws s3 sync ./dist s3://my-bucket --delete
  - run: |
      aws cloudfront create-invalidation \
        --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
        --paths "/*"
```

### Deploy Lambda

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/lambda-deploy-role
      aws-region: us-east-1
  - run: |
      zip -r function.zip .
      aws lambda update-function-code \
        --function-name my-function \
        --zip-file fileb://function.zip
```

---

## Azure

### OIDC Setup

Requires a Microsoft Entra ID application with federated credentials.

```bash
# Create app registration and service principal
az ad app create --display-name "github-actions-deploy"
az ad sp create --id <APP_ID>

# Add federated credential (branch-scoped)
az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-main-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:octo-org/octo-repo:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For environment-scoped
az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-production-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:octo-org/octo-repo:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For pull requests
az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-pull-requests",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:octo-org/octo-repo:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

Required secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

### Azure Authentication Steps

```yaml
# OIDC (preferred)
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

# Service principal secret (fallback)
- uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
# AZURE_CREDENTIALS JSON: {"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}
```

### Deploy to AKS

```yaml
name: Deploy to AKS
on:
  push:
    branches: [main]
env:
  AZURE_CONTAINER_REGISTRY: myregistry
  REGISTRY_URL: myregistry.azurecr.io
  PROJECT_NAME: my-app
  RESOURCE_GROUP: my-resource-group
  CLUSTER_NAME: my-aks-cluster
  CHART_PATH: ./charts/my-app
  CHART_OVERRIDE_PATH: ./charts/my-app/values-prod.yaml
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Build image on ACR
        uses: azure/CLI@v2
        with:
          inlineScript: |
            az configure --defaults acr=${{ env.AZURE_CONTAINER_REGISTRY }}
            az acr build -t ${{ env.REGISTRY_URL }}/${{ env.PROJECT_NAME }}:${{ github.sha }} .
      - uses: azure/aks-set-context@v4
        with:
          resource-group: ${{ env.RESOURCE_GROUP }}
          cluster-name: ${{ env.CLUSTER_NAME }}
      - name: Bake manifests (Helm)
        uses: azure/k8s-bake@v3
        with:
          renderEngine: helm
          helmChart: ${{ env.CHART_PATH }}
          overrideFiles: ${{ env.CHART_OVERRIDE_PATH }}
          overrides: |
            replicas:2
          helm-version: latest
        id: bake
      - uses: Azure/k8s-deploy@v5
        with:
          manifests: ${{ steps.bake.outputs.manifestsBundle }}
          images: |
            ${{ env.REGISTRY_URL }}/${{ env.PROJECT_NAME }}:${{ github.sha }}
          imagepullsecrets: |
            ${{ env.PROJECT_NAME }}
```

### Deploy to App Service (Docker)

```yaml
name: Deploy to Azure App Service
on:
  push:
    branches: [main]
env:
  AZURE_WEBAPP_NAME: my-web-app
permissions:
  contents: read
  packages: write
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - run: echo "REPO=${GITHUB_REPOSITORY,,}" >> $GITHUB_ENV
      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/${{ env.REPO }}:${{ github.sha }}
          file: ./Dockerfile
  deploy:
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: production
      url: ${{ steps.deploy-to-webapp.outputs.webapp-url }}
    steps:
      - run: echo "REPO=${GITHUB_REPOSITORY,,}" >> $GITHUB_ENV
      - id: deploy-to-webapp
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
          images: ghcr.io/${{ env.REPO }}:${{ github.sha }}
```

### Deploy to Azure Static Web Apps

```yaml
name: Deploy to Azure Static Web Apps
on:
  push:
    branches: [main]
  pull_request:
    types: [opened, synchronize, reopened, closed]
    branches: [main]
permissions:
  issues: write
  contents: read
  pull-requests: write
env:
  APP_LOCATION: "/"
  API_LOCATION: "api"
  OUTPUT_LOCATION: "build"
jobs:
  build_and_deploy:
    if: github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.action != 'closed')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: upload
          app_location: ${{ env.APP_LOCATION }}
          api_location: ${{ env.API_LOCATION }}
          output_location: ${{ env.OUTPUT_LOCATION }}
  close_pull_request:
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          action: close
```

---

## GCP

### OIDC Setup (Workload Identity Federation)

```bash
# Create identity pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="my-project-id" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="my-project-id" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Bind service account (repo-scoped)
gcloud iam service-accounts add-iam-policy-binding \
  "my-sa@my-project-id.iam.gserviceaccount.com" \
  --project="my-project-id" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/octo-org/octo-repo"

# Bind service account (branch-scoped)
# --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/subject/repo:octo-org/octo-repo:ref:refs/heads/main"
```

Provider path format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER`

### GCP Authentication Steps

```yaml
# OIDC (preferred)
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider
    service_account: my-sa@my-project-id.iam.gserviceaccount.com

# With credential file for gcloud CLI
- id: auth
  uses: google-github-actions/auth@v2
  with:
    create_credentials_file: true
    workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider
    service_account: my-sa@my-project-id.iam.gserviceaccount.com
- run: |
    gcloud auth login --brief --cred-file="${{ steps.auth.outputs.credentials_file_path }}"
    gcloud services list

# Service account key (fallback)
- uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}
```

### Deploy to GKE

```yaml
name: Deploy to GKE
on:
  push:
    branches: [main]
env:
  PROJECT_ID: my-project-id
  GKE_CLUSTER: my-cluster
  GKE_ZONE: us-central1-c
  DEPLOYMENT_NAME: my-app
  IMAGE: my-app
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider
          service_account: deployer@my-project-id.iam.gserviceaccount.com
      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud --quiet auth configure-docker
      - uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: ${{ env.GKE_CLUSTER }}
          location: ${{ env.GKE_ZONE }}
      - name: Build and push image
        run: |
          docker build --tag "gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA" .
          docker push "gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA"
      - name: Deploy
        run: |
          kubectl set image deployment/$DEPLOYMENT_NAME \
            $IMAGE=gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA
          kubectl rollout status deployment/$DEPLOYMENT_NAME
```

---

## Key Actions Reference

| Provider | Action | Purpose |
|----------|--------|---------|
| AWS | `aws-actions/configure-aws-credentials@v4` | OIDC or static credential auth |
| AWS | `aws-actions/amazon-ecr-login@v2` | Login to ECR |
| AWS | `aws-actions/amazon-ecs-render-task-definition@v1` | Update ECS task def image |
| AWS | `aws-actions/amazon-ecs-deploy-task-definition@v2` | Deploy ECS task def |
| Azure | `azure/login@v2` | OIDC or service principal auth |
| Azure | `azure/aks-set-context@v4` | Set AKS kubectl context |
| Azure | `azure/k8s-bake@v3` | Bake K8s manifests (Helm/Kustomize) |
| Azure | `Azure/k8s-deploy@v5` | Deploy to Kubernetes |
| Azure | `azure/webapps-deploy@v3` | Deploy to App Service |
| Azure | `Azure/static-web-apps-deploy@v1` | Deploy to Static Web Apps |
| Azure | `azure/CLI@v2` | Run Azure CLI commands |
| GCP | `google-github-actions/auth@v2` | OIDC or SA key auth |
| GCP | `google-github-actions/setup-gcloud@v2` | Set up gcloud CLI |
| GCP | `google-github-actions/get-gke-credentials@v2` | Get GKE kubectl context |
