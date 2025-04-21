# Multi-Cluster Kubernetes Management Platform

A modern Kubernetes infrastructure management solution using Terraform, Crossplane, and GitHub Actions to implement a multi-cluster Kubernetes environment on Google Cloud Platform.

## Architecture Overview

This platform implements a modular infrastructure management approach with two clearly separated layers:

1. **Infrastructure Layer (Terraform + Crossplane)**
   - Small, efficient "infracluster" GKE cluster provisioned with Terraform
   - Crossplane running on the infracluster to manage additional GKE clusters
   - GitHub Actions workflows for automation
   - Infrastructure-as-Code principles throughout

2. **Application Layer**
   - Application GKE clusters ("devcluster") provisioned by Crossplane
   - Standardized cluster configuration with add-ons (NGINX Ingress, cert-manager, etc.)
   - Secure application deployment with TLS and secret management

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                               GitHub Repository                             │
│                                                                             │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐                  │
│  │  Terraform    │   │  Crossplane   │   │  Application  │                  │
│  │  Workflow     │   │  Workflow     │   │  Workflow     │                  │
│  └───────┬───────┘   └───────┬───────┘   └───────┬───────┘                  │
│          │                   │                   │                          │
└──────────┼───────────────────┼───────────────────┼──────────────────────────┘
           │                   │                   │
           ▼                   │                   │
┌──────────────────┐           │                   │
│                  │           │                   │
│  Google Cloud    │           │                   │
│  Platform        │           │                   │
│                  │           │                   │
│  ┌────────────┐  │           │                   │
│  │ IAM        │  │           │                   │
│  │ Service    │  │           │                   │
│  │ Accounts   │  │           │                   │
│  └────────────┘  │           │                   │
│                  │           │                   │
│  ┌────────────┐  │           │                   │
│  │ VPC        │  │           │                   │
│  │ Network    │  │           │                   │
│  └────────────┘  │           │                   │
│                  │           │                   │
│  ┌────────────┐  │           │                   │
│  │Infracluster│◄─┼───────────┘                   │
│  │            │  │                               │
│  │┌──────────┐│  │                               │
│  ││Crossplane││  │                               │
│  │└────┬─────┘│  │                               │
│  └─────┼──────┘  │                               │
│        │         │                               │
│        ▼         │                               │
│  ┌────────────┐  │                               │
│  │ Dev GKE    │◄─┼───────────────────────────────┘
│  │ Cluster    │  │
│  │            │  │
│  │┌──────────┐│  │
│  ││Hello     ││  │
│  ││World App ││  │
│  │└──────────┘│  │
│  └────────────┘  │
│                  │
└──────────────────┘
```

## Repository Structure

```
lab_commercelab/
├── .github/workflows/                # GitHub Actions workflows
│   ├── terraform-infra.yaml          # Deploy Terraform infrastructure
│   ├── crossplane-bootstrap.yaml     # Bootstrap Crossplane on infracluster
│   ├── provision-dev-cluster.yaml    # Provision dev GKE cluster with Crossplane
│   └── deploy-app.yaml               # Deploy application to dev cluster with TLS
├── kubernetes-addons/                # Kubernetes add-ons
│   ├── install.sh                    # Comprehensive installation script
│   ├── ingress-nginx/                # NGINX Ingress Controller
│   │   └── values.yaml               # Configuration values
│   ├── cert-manager/                 # Certificate Manager
│   │   ├── values.yaml               # Configuration values
│   │   └── cluster-issuers.yaml      # Let's Encrypt issuers
│   ├── reloader/                     # Reloader for auto-updates
│   │   └── values.yaml               # Configuration values
│   └── secret-manager/               # External Secrets Operator
│       ├── values.yaml               # Configuration values
│       └── secret-store.yaml         # SecretStore configurations
├── infra/                            # Terraform infrastructure code
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── vpc/                      # VPC network module
│   │   ├── gke/                      # GKE cluster module
│   │   ├── iam/                      # IAM service accounts module
│   │   └── apis/                     # GCP API enablement module
│   └── environments/                 # Environment-specific configurations
│       └── dev/                      # Development environment
├── crossplane/                       # Crossplane configurations
│   ├── bootstrap/                    # Bootstrap manifests
│   │   ├── namespace.yaml            # Crossplane namespace
│   │   ├── helm-repository.yaml      # Crossplane Helm repo
│   │   ├── crossplane-helm-release.yaml # Crossplane Helm release
│   │   ├── providers.yaml            # Crossplane providers
│   │   └── provider-configs/         # Provider configurations
│   ├── compositions/                 # XRM compositions
│   │   └── gke-cluster.yaml          # GKE cluster composition
│   ├── post-install/                 # Post-install add-ons
│   │   ├── addons.yaml               # NGINX & cert-manager configs
│   │   ├── apply-addons.sh           # Add-ons installation script
│   │   └── flux/                     # GitOps controllers
│   │       ├── controllers.yaml      # Flux controllers
│   │       └── crds.yaml             # Flux CRDs
│   └── xresources/                   # Custom resource definitions & claims
│       ├── gke-cluster-definition.yaml # GKE cluster XRD
│       └── dev-gke-cluster-claim.yaml # Dev GKE cluster claim
├── workloads/                        # Application workloads
│   └── hello-world/                  # Hello World application
│       ├── app/                      # Application source code
│       │   ├── main.go               # Go application
│       │   ├── go.mod                # Go module file
│       │   └── Dockerfile            # Container image definition
│       ├── Chart.yaml                # Helm chart metadata
│       ├── values.yaml               # Helm chart values
│       └── templates/                # Helm chart templates
│           ├── deployment.yaml       # Kubernetes deployment
│           ├── service.yaml          # Kubernetes service
│           └── ingress.yaml          # Kubernetes ingress with TLS
└── scripts/                          # Utility scripts
    ├── setup.sh                      # Setup script for GCP resources
    ├── cleanup.sh                    # Cleanup script for GCP resources
    └── install-cluster-addons.sh     # Installs NGINX Ingress and cert-manager
```

## Prerequisites

- Google Cloud Platform account and project
- GitHub repository with secrets configured
- Local development tools:
  - `gcloud` CLI (authenticated to your GCP project)
  - `kubectl` CLI
  - `helm` CLI (optional for local development)

## Quick Start

### 1. Set Up Cloud Resources

Run the provided setup script to create required GCP resources:

```bash
./scripts/setup.sh
```

This script will:
1. Enable required GCP APIs
2. Create a service account for GitHub Actions
3. Create a GCS bucket for Terraform state
4. Provide instructions for GitHub secrets

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Base64-encoded service account key (provided by the setup script)
- `GCP_TERRAFORM_STATE_BUCKET`: GCS bucket name for Terraform state (provided by the setup script)

### 3. Deploy Infrastructure

The project uses GitHub Actions workflows for deployment. The workflows are triggered in sequence:

1. **Terraform Infrastructure Deployment**
   - Deploys the VPC, IAM, and infracluster GKE

2. **Crossplane Bootstrap**
   - Installs Crossplane on the infracluster
   - Configures Crossplane providers and permissions

3. **Provision Dev Cluster**
   - Uses Crossplane to provision the dev GKE cluster
   - Automatically installs NGINX Ingress Controller and cert-manager as cluster add-ons
   - Configures Let's Encrypt Cluster Issuers for automated TLS

4. **Deploy Application**
   - Uses the pre-installed NGINX Ingress Controller and cert-manager
   - Builds and deploys the sample application with HTTPS support via Let's Encrypt

To start the deployment:
1. Go to the Actions tab in your GitHub repository
2. Select "Terraform Infrastructure Deployment"
3. Click "Run workflow" and select the main branch

Each workflow will trigger the next one upon successful completion.

## Required Placeholder Replacements

Before deploying, these placeholder values need replacement:

| File | Placeholder | Replace With | Description |
|------|-------------|-------------|-------------|
| **Terraform Infrastructure** |
| `infra/environments/dev/variables.tf` | `your-gcp-project-id` | Your GCP project ID | The GCP project for all resources |
| `infra/environments/dev/backend.tf` | `your-terraform-state-bucket` | Your GCS bucket name | From setup.sh output |
| **Crossplane Configuration** |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `your-gcp-project-id` | Your GCP project ID | Used by Crossplane to provision GKE |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `dev-gke-node-sa@your-gcp-project-id.iam.gserviceaccount.com` | Your service account | Will be automatically replaced by GitHub workflow |
| **Application Deployment** |
| `workloads/hello-world/values.yaml` | `gcr.io/your-gcp-project-id/hello-world` | Your GCR image path | For container images |

## Cluster Design

### Infracluster (GKE)

The infracluster is a small, efficient GKE cluster designed to host Crossplane:

- **Size:** Zonal cluster with 1 node (autoscales to 3)
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Cost Optimization:** Uses preemptible VMs
- **Networking:** Private nodes with public control plane access
- **Security:** Workload Identity enabled for GCP access

### Dev Cluster (via Crossplane)

The dev cluster is provisioned by Crossplane running on the infracluster:

- **Size:** Regional cluster with 1 node (autoscales to 3)
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Networking:** Uses the same VPC as the infracluster
- **Security:** Workload Identity, Shielded nodes, and secure boot enabled
- **Add-ons:**
  - NGINX Ingress Controller for efficient ingress management
  - cert-manager for automated TLS certificate management with Let's Encrypt
  - Cluster Issuers configured for both staging and production certificates

## Modular Design

The project follows a modular design philosophy:

1. **Terraform Modules**
   - VPC: Network infrastructure with public/private subnets
   - GKE: GKE cluster with security and scalability options
   - IAM: Service accounts with appropriate permissions
   - APIs: Required GCP API enablement

2. **Crossplane Resources**
   - Custom XRDs for GKE clusters
   - Compositions that translate high-level specs to detailed GCP resources
   - Provider configurations for GCP integration

## Current Implementation

The current implementation focuses on:

1. **Terraform-based Infrastructure**
   - Small, efficient infracluster deployment
   - Modular Terraform code for GKE, IAM, networking, and Container Registry
   - Clean separation of infrastructure components
   - Proper integration between all infrastructure modules

2. **Google Container Registry**
   - Dedicated container registry for storing application images
   - Properly connected to GKE clusters with appropriate IAM permissions
   - Lifecycle policies for automatic cleanup of old images

3. **Secret Management & IAM**
   - Google Secret Manager integration
   - External Secrets Operator for Kubernetes secrets
   - Workload Identity configuration for secure credential management
   - Properly scoped IAM roles and service accounts

4. **Crossplane-based Cluster Management**
   - Using Crossplane for managing additional GKE clusters
   - Crossplane Custom Resource Definitions for standardized cluster deployment
   - Automated dev cluster provisioning with proper resource configuration

5. **Kubernetes Add-ons Management**
   - Comprehensive add-on installation system
   - NGINX Ingress Controller for traffic management
   - cert-manager with Let's Encrypt for automatic TLS certificates
   - Reloader for automatic deployment updates on config changes
   - External Secrets Operator for secure secret management

6. **Application Deployment with GitHub Actions**
   - Complete CI/CD pipelines for building and deploying applications
   - Proper container image building and pushing
   - TLS certificate support for secure application access
   - Secret management via External Secrets Operator

## Future Enhancements

### ArgoCD Integration (GitOps)

A planned future enhancement is to add ArgoCD for full GitOps capabilities:

1. **Infrastructure as Code**
   - ArgoCD would monitor Git repositories for Crossplane resources
   - Changes to Crossplane resources would be automatically applied

2. **Application Deployment**
   - ArgoCD Applications would define application deployments
   - Multi-cluster deployments using ApplicationSets
   - Progressive delivery patterns

Implementation Path:
1. Install ArgoCD on the infracluster alongside Crossplane
2. Configure Git repositories for infrastructure and applications
3. Set up ApplicationSets for deploying to multiple clusters

### Multi-Environment Support

The current design can be extended to support multiple environments:

1. **Additional Cluster Claims**
   - Create staging and production cluster claims
   - Apply different configurations based on environment

2. **Environment-Specific Parameters**
   - Resource limits
   - Scaling parameters
   - Security configurations

## Troubleshooting

### Common Issues

#### Workflow Failures
- Check GitHub Actions logs for detailed error messages
- Verify GitHub secrets are configured correctly

#### Crossplane Issues
- Check Crossplane logs: `kubectl logs -l app=crossplane -n crossplane-system`
- Verify provider configurations: `kubectl get providers -n crossplane-system`

#### Dev Cluster Provisioning
- Check Crossplane claim status: `kubectl get gkecluster.platform.commercelab.io`
- View detailed status: `kubectl describe gkecluster.platform.commercelab.io/dev-gke-cluster`

## Kubernetes Add-ons Architecture

The platform includes a comprehensive set of Kubernetes add-ons to enhance cluster functionality:

1. **Add-ons Installation Process:**
   - All add-ons installed via a modular installation script after cluster provisioning
   - Clean, declarative Helm-based installation for consistency
   - Pre-configured for immediate use with applications

2. **Included Add-ons:**
   - **NGINX Ingress Controller:** Manages incoming traffic and routing
   - **cert-manager:** Automates TLS certificate management with Let's Encrypt
   - **Reloader:** Automatically restarts deployments when ConfigMaps or Secrets change
   - **External Secrets Operator:** Manages secrets from external sources (GCP Secret Manager)

3. **Manual Installation:**
   
   To install or reinstall the add-ons manually:
   
   ```bash
   # Set your kubeconfig to point to the target cluster
   export KUBECONFIG=/path/to/your/kubeconfig.yaml
   
   # Run the comprehensive add-ons installation script
   ./kubernetes-addons/install.sh [EMAIL] [GCP_PROJECT_ID] [GCP_SERVICE_ACCOUNT]
   ```

4. **Add-ons Usage in Applications:**
   - Applications use annotations to leverage add-on functionality
   - TLS certificates are automatically provisioned and renewed
   - Secrets are managed securely through External Secrets
   - Configuration changes are automatically applied via Reloader

## Cleanup

To remove all resources created by this project:

```bash
./scripts/cleanup.sh
```

This script will:
1. Delete the dev GKE cluster
2. Delete the infracluster
3. Delete IAM service accounts
4. Clean up networking resources
5. Optionally delete the Terraform state bucket

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.