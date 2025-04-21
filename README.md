# Cloud-Native Infrastructure with Terraform, Crossplane, and GitOps

This repository contains a production-grade cloud infrastructure setup using Terraform for base infrastructure, Crossplane for Kubernetes-native infrastructure provisioning, and ArgoCD for GitOps-based application deployment on Google Cloud Platform.

## Architecture Overview

This architecture implements a modern, GitOps-driven cloud infrastructure with three clearly separated layers:

1. **Base Infrastructure Layer (Terraform)**
   - Custom VPC with public and private subnets
   - IAM service accounts with proper RBAC
   - GCP API enablement
   - Base GKE cluster to host Crossplane Controller and ArgoCD

2. **Infrastructure Controller Layer (Crossplane)**
   - Crossplane running on the base GKE cluster
   - Custom resource definitions for GKE clusters
   - Declarative API for provisioning application-specific GKE clusters
   - Multi-environment support (dev, staging, prod)

3. **Application Deployment Layer (ArgoCD)**
   - ArgoCD for GitOps-based deployments
   - Declarative application definitions in Git
   - Automatic sync from Git to Kubernetes 
   - Multi-cluster deployment through ApplicationSets

## Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                           │
│                               GitHub Repository                                           │
│                                                                                           │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │
│  │  Terraform      │   │  Crossplane     │   │  ArgoCD         │   │  Application    │   │
│  │  Infrastructure │   │  Bootstrap      │   │  Bootstrap      │   │  Build          │   │
│  │  Workflow       │   │  Workflow       │   │  Workflow       │   │  Workflow       │   │
│  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘   └────────┬────────┘   │
│           │                     │                     │                     │            │
└───────────┼─────────────────────┼─────────────────────┼─────────────────────┼────────────┘
            │                     │                     │                     │
            ▼                     │                     │                     │
┌───────────────────────┐         │                     │                     │
│                       │         │                     │                     │
│  Google Cloud         │         │                     │                     │
│  Platform             │         │                     │                     │
│                       │         │                     │                     │
│  ┌───────────────┐    │         │                     │                     │
│  │ IAM Service   │    │         │                     │                     │
│  │ Accounts      │    │         │                     │                     │
│  └───────────────┘    │         │                     │                     │
│                       │         │                     │                     │
│  ┌───────────────┐    │         │                     │                     │
│  │ GCS Buckets   │    │         │                     │                     │
│  │ (TF State)    │    │         │                     │                     │
│  └───────────────┘    │         │                     │                     │
│                       │         │                     │                     │
│  ┌───────────────┐    │         │                     │                     │
│  │ GCP APIs &    │    │         │                     │                     │
│  │ Services      │◄───┘         │                     │                     │
│  └───────────────┘              │                     │                     │
│                                 │                     │                     │
│  ┌───────────────────┐          │                     │                     │
│  │ VPC Network       │          │                     │                     │
│  │                   │          │                     │                     │
│  │ ┌─────────────┐   │          │                     │                     │
│  │ │Public Subnet│   │          │                     │                     │
│  │ └─────────────┘   │          │                     │                     │
│  │                   │          │                     │                     │
│  │ ┌─────────────┐   │          │                     │                     │
│  │ │Private      │   │          │                     │                     │
│  │ │Subnet       │   │          │                     │                     │
│  │ └─────────────┘   │          │                     │                     │
│  └───────────────────┘          │                     │                     │
│                                 │                     │                     │
│  ┌───────────────────┐          │                     │                     │
│  │ GKE Management    │          │                     │                     │
│  │ Cluster           │◄─────────┘                     │                     │
│  │                   │                                │                     │
│  │ ┌─────────────┐   │                                │                     │
│  │ │Crossplane   │   │                                │                     │
│  │ │Operators    │───┼────────────────────┐           │                     │
│  │ └─────────────┘   │                    │           │                     │
│  │                   │                    │           │                     │
│  │ ┌─────────────┐   │                    │           │                     │
│  │ │ArgoCD       │◄──┼────────────────────┼───────────┼─────────────────┐  │
│  │ │             │   │                    │           │                 │  │
│  │ └─────────────┘   │                    │           │                 │  │
│  │                   │                    │           │                 │  │
│  └───────────────────┘                    │           │                 │  │
│                                           │           │                 │  │
│  ┌───────────────────┐                    │           │                 │  │
│  │ GKE Application   │                    │           │                 │  │
│  │ Clusters          │◄───────────────────┘           │                 │  │
│  │                   │                                │                 │  │
│  │ ┌─────────────┐   │                                │                 │  │
│  │ │Hello World  │◄──┼────────────────────────────────┼─────────────────┘  │
│  │ │Application  │   │                                │                    │
│  │ └─────────────┘   │                                │                    │
│  │                   │                                │                    │
│  │ ┌─────────────┐   │                                │                    │
│  │ │Container    │◄──┼────────────────────────────────┘                    │
│  │ │Registry     │   │                                                     │
│  │ └─────────────┘   │                                                     │
│  │                   │                                                     │
│  └───────────────────┘                                                     │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## GitOps Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                          │
│                                    GitOps Process Flow                                   │
│                                                                                          │
├──────────────┬──────────────────┬─────────────────────┬───────────────────┬─────────────┤
│              │                  │                     │                   │             │
│  Developer   │    GitHub        │   Management        │  App Cluster      │  Container  │
│  Workflow    │    Actions       │   Cluster           │  (Created by      │  Registry   │
│              │                  │                     │   Crossplane)     │             │
├──────────────┼──────────────────┼─────────────────────┼───────────────────┼─────────────┤
│              │                  │                     │                   │             │
│   Code       │                  │                     │                   │             │
│   Changes    │                  │                     │                   │             │
│      │       │                  │                     │                   │             │
│      ▼       │                  │                     │                   │             │
│   Git Push   │                  │                     │                   │             │
│      │       │                  │                     │                   │             │
│      └──────►│  Terraform       │                     │                   │             │
│              │  Workflow        │                     │                   │             │
│              │  Triggered       │                     │                   │             │
│              │      │           │                     │                   │             │
│              │      ▼           │                     │                   │             │
│              │  Create/Update   │                     │                   │             │
│              │  Base Infra      │                     │                   │             │
│              │      │           │                     │                   │             │
│              │      └──────────►│  Management GKE     │                   │             │
│              │                  │  Cluster Created    │                   │             │
│              │                  │      │              │                   │             │
│              │                  │      │              │                   │             │
│              │  Crossplane      │      │              │                   │             │
│              │  Bootstrap       │      │              │                   │             │
│              │  Workflow        │      │              │                   │             │
│              │  Triggered       │      │              │                   │             │
│              │      │           │      │              │                   │             │
│              │      ▼           │      │              │                   │             │
│              │  Install         │      │              │                   │             │
│              │  Crossplane      │      │              │                   │             │
│              │      │           │      │              │                   │             │
│              │      └──────────►│  Crossplane         │                   │             │
│              │                  │  Running            │                   │             │
│              │                  │      │              │                   │             │
│              │  ArgoCD          │      │              │                   │             │
│              │  Bootstrap       │      │              │                   │             │
│              │  Workflow        │      │              │                   │             │
│              │  Triggered       │      │              │                   │             │
│              │      │           │      │              │                   │             │
│              │      ▼           │      │              │                   │             │
│              │  Install         │      │              │                   │             │
│              │  ArgoCD          │      │              │                   │             │
│              │      │           │      │              │                   │             │
│              │      └──────────►│  ArgoCD             │                   │             │
│              │                  │  Running            │                   │             │
│              │                  │      │              │                   │             │
│              │                  │      │              │                   │             │
│              │                  │      ▼              │                   │             │
│              │                  │  ArgoCD watches     │                   │             │
│              │                  │  Git repository     │                   │             │
│              │                  │  for Crossplane     │                   │             │
│              │                  │  resources          │                   │             │
│              │                  │      │              │                   │             │
│              │                  │      ▼              │                   │             │
│              │                  │  Crossplane         │                   │             │
│              │                  │  Provisions         │                   │             │
│              │                  │  App Cluster        │                   │             │
│              │                  │      │              │                   │             │
│              │                  │      └──────────────┼──► App Cluster    │             │
│              │                  │                     │    Created        │             │
│              │                  │                     │      │            │             │
│              │  Register        │                     │      │            │             │
│              │  App Cluster     │                     │      │            │             │
│              │  Workflow        │                     │      │            │             │
│              │  Triggered       │                     │      │            │             │
│              │      │           │                     │      │            │             │
│              │      ▼           │                     │      │            │             │
│              │  Register        │                     │      │            │             │
│              │  Cluster with    │                     │      │            │             │
│              │  ArgoCD          │                     │      │            │             │
│              │      │           │                     │      │            │             │
│              │      └──────────►│  ArgoCD knows       │      │            │             │
│              │                  │  about App          │      │            │             │
│              │                  │  Cluster           ─┼──────┼───────────►│             │
│              │                  │                     │      │            │             │
│              │  Build           │                     │      │            │             │
│              │  Application     │                     │      │            │             │
│              │  Workflow        │                     │      │            │             │
│              │  Triggered       │                     │      │            │             │
│              │      │           │                     │      │            │             │
│              │      ▼           │                     │      │            │             │
│              │  Build &         │                     │      │            │             │
│              │  Push Image      │                     │      │            │             │
│              │      │           │                     │      │            │             │
│              │      └───────────┼─────────────────────┼──────┼───────────►│  Container  │
│              │                  │                     │      │            │  Image      │
│              │  Update          │                     │      │            │  Stored     │
│              │  ArgoCD App      │                     │      │            │     │       │
│              │  Definitions     │                     │      │            │     │       │
│              │      │           │                     │      │            │     │       │
│              │      └──────────►│  ArgoCD detects     │      │            │     │       │
│              │                  │  Changes            │      │            │     │       │
│              │                  │      │              │      │            │     │       │
│              │                  │      └──────────────┼──────┼────────────┼─────┘       │
│              │                  │                     │      ▼            │             │
│              │                  │                     │  App Deployed     │             │
│              │                  │                     │  and Running      │             │
│              │                  │                     │                   │             │
└──────────────┴──────────────────┴─────────────────────┴───────────────────┴─────────────┘
```

## Repository Structure

```
lab_commercelab/
├── .github/workflows/                # GitHub Actions workflows
│   ├── terraform-infra.yaml             # Deploy Terraform infrastructure
│   ├── crossplane-bootstrap.yaml        # Bootstrap Crossplane on base cluster
│   ├── argocd-bootstrap.yaml            # Bootstrap ArgoCD on base cluster
│   ├── register-app-clusters.yaml       # Register new clusters with ArgoCD
│   └── build-application.yaml           # Build and push application images
├── argo-apps/                        # ArgoCD application definitions
│   ├── crossplane/                      # Crossplane resource applications
│   │   └── crossplane-app.yaml          # Application for Crossplane resources
│   └── workloads/                       # Application workload definitions
│       ├── hello-world-app.yaml         # Single cluster application
│       └── multi-cluster-app.yaml       # Multi-cluster application set
├── infra/                            # Terraform infrastructure code
│   ├── modules/                         # Reusable Terraform modules
│   │   ├── vpc/                         # VPC network module
│   │   ├── gke/                         # GKE cluster module
│   │   ├── iam/                         # IAM service accounts module
│   │   └── apis/                        # GCP API enablement module
│   └── environments/                    # Environment-specific configurations
│       └── dev/                         # Development environment
├── crossplane/                       # Crossplane configurations
│   ├── bootstrap/                       # Bootstrap manifests
│   │   ├── namespace.yaml               # Crossplane namespace
│   │   ├── helm-repository.yaml         # Crossplane Helm repo
│   │   ├── crossplane-helm-release.yaml # Crossplane Helm release
│   │   ├── providers.yaml               # Crossplane providers
│   │   ├── provider-configs/            # Provider configurations
│   │   └── argocd/                      # ArgoCD installation manifests
│   ├── compositions/                    # XRM compositions
│   │   └── gke-cluster.yaml             # GKE cluster composition
│   └── xresources/                      # Custom resource definitions & claims
│       ├── gke-cluster-definition.yaml  # GKE cluster XRD
│       └── dev-gke-cluster-claim.yaml   # Dev GKE cluster claim
└── workloads/                        # Application workloads
    └── hello-world/                     # Hello World application
        ├── app/                         # Application source code
        │   ├── main.go                  # Go application
        │   ├── go.mod                   # Go module file
        │   └── Dockerfile               # Container image definition
        ├── Chart.yaml                   # Helm chart metadata
        ├── values.yaml                  # Helm chart values
        └── templates/                   # Helm chart templates
```

## Prerequisites

- Google Cloud Platform account and project
- GitHub repository with secrets configured
- Local development tools:
  - `gcloud` CLI (authenticated to your GCP project)
  - `terraform` CLI (v1.0+)
  - `kubectl` CLI
  - `helm` CLI

## Required Placeholder Replacements

Before deploying, you **MUST** replace these placeholder values with your actual configuration:

| File | Placeholder | Replace With | Description |
|------|-------------|-------------|-------------|
| **Terraform Base Infrastructure** |
| `infra/environments/dev/variables.tf` | `your-gcp-project-id` (line 3) | Your GCP project ID | The GCP project where all resources will be created |
| `infra/environments/dev/backend.tf` | `your-terraform-state-bucket` (line 3) | Your GCS bucket name | GCS bucket for storing Terraform state |
| **Crossplane Configuration** |
| `crossplane/bootstrap/provider-configs/gcp-provider-config.yaml` | `${PROJECT_ID}` (line 7) | Your GCP project ID | **Note**: This will be replaced automatically by the GitHub workflow |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `your-gcp-project-id` (line 12) | Your GCP project ID | Used for Crossplane to provision GKE |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `dev-gke-node-sa@your-gcp-project-id.iam.gserviceaccount.com` (line 30) | Your specific service account | **Note**: This will be replaced automatically by the GitHub workflow |
| **ArgoCD Configuration** |
| `crossplane/bootstrap/argocd/git-repo.yaml` | `your-username` | Your GitHub username | For ArgoCD to access your repository |
| `crossplane/bootstrap/argocd/git-repo.yaml` | `YOUR_GITHUB_PAT_OR_PASSWORD` | Your GitHub token | Personal access token with repo scope |
| `argo-apps/crossplane/crossplane-app.yaml` | `your-username` | Your GitHub username | For ArgoCD application definition |
| `argo-apps/workloads/hello-world-app.yaml` | `your-username` | Your GitHub username | For ArgoCD application definition |
| `argo-apps/workloads/multi-cluster-app.yaml` | `your-username` | Your GitHub username | For ArgoCD application definition |
| **Application Deployment** |
| `workloads/hello-world/values.yaml` | `gcr.io/your-gcp-project-id/hello-world` (line 5) | Your GCR image path | Where your container images will be stored |
| **GitHub Secrets** |
| GitHub repository | N/A | Create secrets | Add `GCP_PROJECT_ID`, `GCP_SA_KEY`, `GCP_TERRAFORM_STATE_BUCKET`, `GH_USERNAME`, and `GH_TOKEN` |

## Getting Started

### Step 1: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Base64-encoded service account key JSON with necessary permissions
- `GCP_TERRAFORM_STATE_BUCKET`: GCS bucket name for Terraform state
- `GH_USERNAME`: Your GitHub username
- `GH_TOKEN`: Your GitHub personal access token (with repo scope)

To create a service account and key:

```bash
# Create service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding your-gcp-project-id \
  --member="serviceAccount:github-actions-sa@your-gcp-project-id.iam.gserviceaccount.com" \
  --role="roles/owner"

# Create and download key
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions-sa@your-gcp-project-id.iam.gserviceaccount.com

# Base64 encode the key for GitHub secret
cat key.json | base64
```

To create a GCS bucket for Terraform state:

```bash
gsutil mb -l us-central1 gs://your-terraform-state-bucket
gsutil versioning set on gs://your-terraform-state-bucket
```

### Step 2: GitHub Actions Workflow Deployment

The project includes several interdependent GitHub Actions workflows that make up the GitOps pipeline:

#### 1. Terraform Infrastructure Deployment

This workflow deploys the base infrastructure:
- Custom VPC network
- IAM service accounts
- GCP API enablement
- Base GKE cluster for Crossplane and ArgoCD

To run:
1. Go to the Actions tab in your GitHub repository
2. Select "Terraform Infrastructure Deployment"
3. Click "Run workflow" and select the branch (default: main)

#### 2. Crossplane Bootstrap

This workflow installs Crossplane on the base GKE cluster:
- Sets up Crossplane via Helm
- Configures GCP provider
- Creates necessary RBAC permissions

To run (will run automatically after successful Terraform workflow):
1. Go to the Actions tab in your GitHub repository
2. Select "Crossplane Bootstrap"
3. Click "Run workflow"

#### 3. ArgoCD Bootstrap

This workflow installs ArgoCD on the base GKE cluster:
- Sets up ArgoCD via Helm
- Configures Git repository access
- Sets up initial applications

To run (will run automatically after successful Crossplane bootstrap):
1. Go to the Actions tab in your GitHub repository
2. Select "ArgoCD Bootstrap"
3. Click "Run workflow"

#### 4. Register Application Clusters

This workflow registers the Crossplane-created GKE clusters with ArgoCD:
- Creates cluster secrets in ArgoCD
- Sets up ApplicationSet for multi-cluster deployment

To run (will run automatically after a new cluster is provisioned):
1. Go to the Actions tab in your GitHub repository
2. Select "Register Application Clusters" 
3. Click "Run workflow" and specify:
   - Environment (dev, staging, prod)
   - Cluster name

#### 5. Build Application

This workflow builds and pushes the container image:
- Builds the container image
- Pushes to Google Container Registry
- Updates the image tag in ArgoCD application definitions

To run (will run automatically when application code changes):
1. Go to the Actions tab in your GitHub repository
2. Select "Build Application"
3. Click "Run workflow"

## How GitOps Works in This Project

This project implements a true GitOps workflow:

1. **Infrastructure as Code**:
   - All infrastructure is defined as code in the repository
   - Terraform defines the base infrastructure
   - Crossplane defines the application clusters
   - ArgoCD applications define the workloads

2. **Declarative Configuration**:
   - All desired states are declared in YAML files
   - No imperative commands are used for deployments
   - Resources are synchronized from Git to the clusters

3. **Pull-Based Deployments**:
   - ArgoCD pulls changes from Git
   - Changes are automatically applied to clusters
   - Deployments happen when Git state changes

4. **Continuous Reconciliation**:
   - ArgoCD continuously compares Git state to cluster state
   - Drift is automatically corrected
   - Self-healing infrastructure and applications

## Accessing and Using ArgoCD

After the ArgoCD bootstrap workflow completes:

1. Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. Access the ArgoCD UI:
   ```bash
   # Using port forwarding
   kubectl port-forward svc/argocd-server -n argocd 8080:80
   # Then open http://localhost:8080 in your browser
   ```

3. View applications and their sync status in the UI

4. Trigger a sync manually if needed:
   ```bash
   # Using argocd CLI
   argocd app sync crossplane-resources
   ```

## Manual Deployment (Alternative to GitHub Actions)

### 1. Terraform Infrastructure

```bash
# Initialize Terraform
cd infra/environments/dev
terraform init

# Apply Terraform configuration
terraform plan
terraform apply
```

### 2. Crossplane and ArgoCD Bootstrap

```bash
# Get credentials for the management cluster
gcloud container clusters get-credentials dev-crossplane-mgmt --region us-central1

# Apply Crossplane bootstrap manifests
kubectl apply -f crossplane/bootstrap/namespace.yaml
kubectl apply -f crossplane/bootstrap/helm-repository.yaml
kubectl apply -f crossplane/bootstrap/crossplane-helm-release.yaml
kubectl apply -f crossplane/bootstrap/providers.yaml

# Wait for Crossplane to be ready
kubectl wait --for=condition=ready helmrelease/crossplane -n crossplane-system --timeout=300s

# Apply ArgoCD bootstrap manifests
kubectl apply -f crossplane/bootstrap/argocd/namespace.yaml
kubectl apply -f crossplane/bootstrap/argocd/helm-repository.yaml
kubectl apply -f crossplane/bootstrap/argocd/argocd-install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready helmrelease/argocd -n argocd --timeout=300s

# Configure Git repository access
kubectl apply -f crossplane/bootstrap/argocd/git-repo.yaml

# Apply ArgoCD applications
kubectl apply -f argo-apps/crossplane/crossplane-app.yaml
```

### 3. Application Development and Deployment

```bash
# Build and push the container image
cd workloads/hello-world/app
docker build -t gcr.io/your-gcp-project-id/hello-world:latest .
docker push gcr.io/your-gcp-project-id/hello-world:latest

# Update the image tag in ArgoCD application definitions
# Then commit and push the changes
git commit -am "Update image tag" && git push

# ArgoCD will automatically detect the changes and deploy the application
```

## Adding a New Environment

To create a new environment (e.g., staging, production):

1. Create environment directory:
   ```bash
   cp -r infra/environments/dev infra/environments/staging
   ```

2. Update variables in `infra/environments/staging/variables.tf`:
   - Change `environment` default to `staging`
   - Update network and subnet names

3. Create a new GKE cluster claim:
   ```bash
   cp crossplane/xresources/dev-gke-cluster-claim.yaml crossplane/xresources/staging-gke-cluster-claim.yaml
   ```

4. Update the claim with staging-specific values:
   - Change labels.environment to `staging`
   - Update the network and subnet references
   - Update serviceAccount if needed

5. Commit and push the changes to trigger the GitOps pipeline

## Clean Up

To clean up resources:

1. Delete ArgoCD applications:
   ```bash
   kubectl delete -n argocd app/hello-world applicationset/hello-world-multi-cluster
   ```

2. Delete application GKE clusters:
   ```bash
   kubectl delete -f crossplane/xresources/dev-gke-cluster-claim.yaml
   ```

3. Delete ArgoCD and Crossplane:
   ```bash
   kubectl delete -f crossplane/bootstrap/argocd/argocd-install.yaml
   kubectl delete -f crossplane/bootstrap/crossplane-helm-release.yaml
   ```

4. Destroy Terraform infrastructure:
   ```bash
   cd infra/environments/dev
   terraform destroy
   ```

## Security Considerations

- All GKE clusters use private nodes with public control plane
- Workload Identity is enabled on all clusters for secure GCP access
- Service accounts follow the principle of least privilege
- Network policies and binary authorization are enabled
- ArgoCD uses repository credentials stored as Kubernetes secrets
- Container images are scanned during CI/CD