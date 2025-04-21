# Multi-Cluster Kubernetes Management Platform

A modern Kubernetes infrastructure management solution using Terraform, Crossplane, and GitHub Actions to implement a multi-cluster Kubernetes environment on Google Cloud Platform.

## Architecture Overview

This platform implements a GitOps-driven infrastructure management approach with two clearly separated layers:

1. **Infrastructure Layer (Terraform + Crossplane)**
   - Small, efficient "infracluster" GKE cluster provisioned with Terraform
   - Crossplane running on the infracluster to manage additional GKE clusters
   - GitHub Actions workflows for automation
   - Infrastructure-as-Code principles throughout

2. **Application Layer**
   - Application GKE clusters ("devcluster") provisioned by Crossplane
   - Standardized cluster configuration
   - Sample application deployment

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
│   └── deploy-app.yaml               # Deploy application to dev cluster
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
└── scripts/                          # Utility scripts
    ├── setup.sh                      # Setup script for GCP resources
    └── cleanup.sh                    # Cleanup script for GCP resources
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

4. **Deploy Application**
   - Builds and deploys the sample application to the dev cluster

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

## Future Enhancements

### ArgoCD Integration (GitOps)

While not implemented in the current version, ArgoCD could be added to enhance GitOps capabilities:

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