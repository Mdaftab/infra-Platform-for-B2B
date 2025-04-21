# Multi-Cluster Kubernetes Management Platform

A modern Kubernetes infrastructure management solution using Terraform, Crossplane, and GitHub Actions to implement a multi-cluster Kubernetes environment on Google Cloud Platform.

## Architecture Overview

This platform implements a modular infrastructure management approach with two clearly separated layers:

1. **Infrastructure Layer (Terraform)**
   - Small, efficient "infracluster" GKE cluster provisioned with Terraform
   - Single shared VPC network for all clusters
   - Standardized IAM service accounts with appropriate permissions
   - Infrastructure-as-Code principles throughout

2. **Cluster Management Layer (Crossplane)**
   - Crossplane running on the infracluster to manage additional GKE clusters
   - Declarative custom resources for defining application clusters
   - Standardized compositions for consistent cluster configuration
   - Multi-environment support (dev, staging, prod)

3. **Application Layer**
   - Application GKE clusters provisioned by Crossplane
   - Standardized cluster configuration with add-ons (NGINX Ingress, cert-manager, etc.)
   - Secure application deployment with TLS and secret management
   - Environment-specific configurations

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
│  │ Shared VPC │  │           │                   │
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
│  │ Dev GKE    │◄─┼──────────────────────┐        │
│  │ Cluster    │  │                      │        │
│  │            │  │                      │        │
│  │┌──────────┐│  │                      │        │
│  ││Hello     ││  │                      │        │
│  ││World App ││  │                      │        │
│  │└──────────┘│  │                      │        │
│  └────────────┘  │                      │        │
│                  │                      │        │
│  ┌────────────┐  │                      │        │
│  │ Staging    │◄─┼──────────────────────┼────────┘
│  │ Cluster    │  │                      │
│  │            │  │                      │
│  │┌──────────┐│  │                      │
│  ││Hello     ││  │                      │
│  ││World App ││  │                      │
│  │└──────────┘│  │                      │
│  └────────────┘  │                      │
│                  │                      │
│  ┌────────────┐  │                      │
│  │ Production │◄─┼──────────────────────┘
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
CM-lab/
├── .github/workflows/                # GitHub Actions workflows
│   ├── terraform-infra.yaml          # Deploy Terraform infrastructure
│   ├── crossplane-bootstrap.yaml     # Bootstrap Crossplane on infracluster
│   ├── provision-dev-cluster.yaml    # Provision application clusters with Crossplane
│   └── deploy-app.yaml               # Deploy application to environment clusters
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
│   │   ├── apis/                     # GCP API enablement module
│   │   └── container-registry/       # Container Registry module
│   └── environments/                 # Environment-specific configurations
│       └── dev/                      # Infrastructure deployment
├── crossplane/                       # Crossplane configurations
│   ├── bootstrap/                    # Bootstrap manifests
│   │   ├── namespace.yaml            # Crossplane namespace
│   │   ├── helm-repository.yaml      # Crossplane Helm repo
│   │   ├── crossplane-helm-release.yaml # Crossplane Helm release
│   │   ├── providers.yaml            # Crossplane providers
│   │   └── provider-configs/         # Provider configurations
│   ├── compositions/                 # XRM compositions
│   │   └── gke-cluster.yaml          # GKE cluster composition
│   └── xresources/                   # Custom resource definitions & claims
│       ├── gke-cluster-definition.yaml # GKE cluster XRD
│       ├── dev-gke-cluster-claim.yaml  # Dev GKE cluster claim
│       ├── staging-gke-cluster-claim.yaml # Staging GKE cluster claim
│       └── prod-gke-cluster-claim.yaml # Production GKE cluster claim
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
  - `helm` CLI
  - `terraform` CLI

## Quick Start

### 1. Set Up Cloud Resources

Run the provided setup script to create required GCP resources:

```bash
./scripts/setup.sh
```

This script will:
1. Enable required GCP APIs
2. Create service accounts for GitHub Actions and infrastructure
3. Create a GCS bucket for Terraform state
4. Provide instructions for GitHub secrets

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Base64-encoded service account key (provided by the setup script)
- `GCP_TERRAFORM_STATE_BUCKET`: GCS bucket name for Terraform state (provided by the setup script)

### 3. Deploy Infrastructure

The project uses GitHub Actions workflows for deployment in the following sequence:

1. **Terraform Infrastructure Deployment**
   - Deploys the VPC, IAM, and infracluster GKE
   - Uses Terraform to create foundational infrastructure

2. **Crossplane Bootstrap**
   - Installs Crossplane on the infracluster
   - Configures Crossplane providers and permissions

3. **Provision Application Clusters**
   - Uses Crossplane to provision application GKE clusters (dev, staging, prod)
   - Automatically installs NGINX Ingress Controller and cert-manager as cluster add-ons
   - Configures Let's Encrypt Cluster Issuers for automated TLS

4. **Deploy Application**
   - Builds and deploys the sample application to the chosen environment
   - Configures environment-specific values (replicas, resources, etc.)
   - Enables TLS with Let's Encrypt certificates

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
| `infra/environments/dev/terraform.tfvars` | `your-gcp-project-id` | Your GCP project ID | The GCP project for all resources |
| `infra/environments/dev/backend.tf` | `your-terraform-state-bucket` | Your GCS bucket name | From setup.sh output |
| **Crossplane Configuration** |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your GCP project ID | Used by Crossplane to provision GKE |
| `crossplane/xresources/staging-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your GCP project ID | Used by Crossplane to provision GKE |
| `crossplane/xresources/prod-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your GCP project ID | Used by Crossplane to provision GKE |
| **Application Deployment** |
| `workloads/hello-world/values.yaml` | `gcr.io/your-gcp-project-id/hello-world` | Your GCR image path | For container images |

## Cluster Architecture

### Infracluster (Terraform-managed)

The infracluster is a small, efficient GKE cluster designed to host Crossplane:

- **Size:** Zonal cluster with 1 node (autoscales to 3)
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Cost Optimization:** Uses preemptible VMs
- **Networking:** Private nodes with public control plane access
- **Security:** Workload Identity enabled for GCP access

### Application Clusters (Crossplane-managed)

Application clusters are provisioned by Crossplane running on the infracluster:

#### Dev Cluster
- **Size:** Regional cluster with 1 node (autoscales to 3)
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Networking:** Uses the same VPC as the infracluster
- **Environment:** Development and testing

#### Staging Cluster
- **Size:** Regional cluster with 2 nodes (autoscales to 5)
- **Machine Type:** e2-standard-2
- **Disk:** 70GB standard persistent disk
- **Networking:** Uses the same VPC as the infracluster
- **Environment:** Pre-production validation

#### Production Cluster
- **Size:** Regional cluster with 3 nodes (autoscales to 7)
- **Machine Type:** e2-standard-4
- **Disk:** 100GB SSD persistent disk
- **Networking:** Uses the same VPC as the infracluster
- **Environment:** Production workloads
- **Security:** Enhanced security configurations

All application clusters include these add-ons:
- NGINX Ingress Controller for efficient ingress management
- cert-manager for automated TLS certificate management with Let's Encrypt
- Cluster Issuers configured for both staging and production certificates
- External Secrets Operator for secure secret management
- Reloader for automatic configuration updates

## Modular Design

The project follows a modular design philosophy:

1. **Terraform Modules**
   - VPC: Shared network infrastructure with public/private subnets
   - GKE: GKE cluster with security and scalability options
   - IAM: Service accounts with appropriate permissions
   - APIs: Required GCP API enablement
   - Container Registry: Image storage and lifecycle management

2. **Crossplane Resources**
   - Custom XRDs for GKE clusters
   - Compositions that translate high-level specs to detailed GCP resources
   - Provider configurations for GCP integration
   - Cluster claims for different environments (dev, staging, prod)

## Troubleshooting

### Common Issues

#### Workflow Failures
- Check GitHub Actions logs for detailed error messages
- Verify GitHub secrets are configured correctly

#### Crossplane Issues
- Check Crossplane logs: `kubectl logs -l app=crossplane -n crossplane-system`
- Verify provider configurations: `kubectl get providers -n crossplane-system`

#### Cluster Provisioning
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

## Cleanup

To remove all resources created by this project:

```bash
./scripts/cleanup.sh
```

This script will:
1. Delete all application GKE clusters provisioned by Crossplane
2. Delete the infracluster
3. Delete IAM service accounts
4. Clean up networking resources
5. Optionally delete the Terraform state bucket

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.