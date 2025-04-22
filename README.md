# Multi-Cluster Kubernetes Management Platform with VPC Peering

A modern Kubernetes infrastructure management solution using Terraform, Crossplane, and GitHub Actions to implement a multi-cluster Kubernetes environment on Google Cloud Platform leveraging a multi-VPC architecture with VPC peering for enhanced isolation and controlled connectivity between infrastructure and application environments.

## Architecture Overview

This platform implements an advanced infrastructure management approach with a multi-VPC architecture:

1. **Infrastructure Layer (Terraform)**
   - Host Project with shared VPC network
   - Small, efficient "infracluster" GKE cluster provisioned with Terraform
   - Crossplane running on the infracluster to manage application clusters
   - VPC peering connections to environment-specific VPCs
   - Infrastructure-as-Code principles throughout

2. **Service Projects Layer**
   - Separate GCP projects for different environments (dev, staging, prod)
   - Each environment has its own dedicated VPC
   - All environment VPCs connected to the shared VPC via peering
   - Clear network isolation with controlled cross-environment communication

3. **Cluster Management Layer (Crossplane)**
   - Crossplane running on the infracluster to manage application clusters
   - Declarative custom resources for defining GKE clusters in service projects
   - Standardized compositions for consistent cluster configuration
   - Multi-environment support (dev, staging, prod)

4. **Application Layer**
   - Application GKE clusters provisioned by Crossplane in environment-specific VPCs
   - Standardized cluster configuration with add-ons
   - Secure application deployment with TLS and secret management
   - Environment-specific configurations

```
┌─────────────────────────────────────────────┐
│                                             │
│       Host Project (shared-infra)           │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │         Shared VPC Network              ││
│  └───────────────┬─────────────────────────┘│
│                  │                          │
│  ┌───────────────┴───────────────────────┐  │
│  │        Infracluster (GKE)             │  │
│  │                                       │  │
│  │  ┌────────────────────────────────┐   │  │
│  │  │        Crossplane              │   │  │
│  │  └────────────────────────────────┘   │  │
│  └───────────────────────────────────────┘  │
└─────────────────┬─────────────┬─────────────┘
                  │             │
                  │ VPC Peering │
                  │             │
┌─────────────────┴─────┐   ┌───┴───────────────────┐
│                       │   │                       │
│    Dev Project        │   │   Staging Project     │
│                       │   │                       │
│  ┌──────────────────┐ │   │ ┌──────────────────┐  │
│  │    Dev VPC       │ │   │ │   Staging VPC    │  │
│  └────────┬─────────┘ │   │ └────────┬─────────┘  │
│           │           │   │          │            │
│  ┌────────┴─────────┐ │   │ ┌────────┴─────────┐  │
│  │   Dev Cluster    │ │   │ │  Staging Cluster │  │
│  │                  │ │   │ │                  │  │
│  │ ┌──────────────┐ │ │   │ │ ┌──────────────┐ │  │
│  │ │ Applications │ │ │   │ │ │ Applications │ │  │
│  │ └──────────────┘ │ │   │ │ └──────────────┘ │  │
│  └──────────────────┘ │   │ └──────────────────┘  │
└───────────────────────┘   └───────────────────────┘
            │                           │
            │       VPC Peering         │
            │                           │
            │                           │
┌───────────┴───────────────────────────┴───┐
│                                           │
│          Production Project               │
│                                           │
│  ┌────────────────────────────────────┐   │
│  │             Prod VPC               │   │
│  └──────────────┬─────────────────────┘   │
│                 │                         │
│  ┌──────────────┴─────────────────────┐   │
│  │        Production Cluster          │   │
│  │                                    │   │
│  │  ┌─────────────────────────────┐   │   │
│  │  │        Applications         │   │   │
│  │  └─────────────────────────────┘   │   │
│  └────────────────────────────────────┘   │
└───────────────────────────────────────────┘
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

- Google Cloud Platform account with organization-level access
- Ability to create and manage projects
- GitHub repository with secrets configured
- Local development tools:
  - `gcloud` CLI (authenticated to your GCP organization)
  - `kubectl` CLI
  - `helm` CLI
  - `terraform` CLI

## Quick Start

### 1. Set Up Google Cloud Projects

First, set up the necessary GCP projects:

1. **Host Project (shared-infra)**
   - Will contain the shared VPC
   - Will run the infracluster with Crossplane

2. **Service Projects**
   - Create separate projects for dev, staging, and production environments
   - These projects will be attached to the shared VPC

Run the provided setup script to create required GCP resources:

```bash
./scripts/setup.sh --host-project your-host-project-id \
  --service-projects your-dev-project-id,your-staging-project-id,your-prod-project-id
```

This script will:
1. Enable required GCP APIs on all projects
2. Create service accounts with appropriate permissions
3. Set up the shared VPC in the host project
4. Create a GCS bucket for Terraform state
5. Provide instructions for GitHub secrets

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `GCP_HOST_PROJECT_ID`: Your GCP host project ID
- `GCP_PROJECT_ID`: Your GCP service project ID (initially for dev)
- `GCP_SA_KEY`: Base64-encoded service account key (provided by the setup script)
- `GCP_TERRAFORM_STATE_BUCKET`: GCS bucket name for Terraform state (provided by the setup script)
- `GCP_DEV_PROJECT_ID`: Your development project ID
- `GCP_STAGING_PROJECT_ID`: Your staging project ID
- `GCP_PROD_PROJECT_ID`: Your production project ID

### 3. Deploy Infrastructure

The project uses GitHub Actions workflows for deployment in the following sequence:

1. **Terraform Infrastructure Deployment**
   - Deploys the shared VPC in the host project
   - Configures Shared VPC service project attachments
   - Deploys the infracluster GKE in the host project

2. **Crossplane Bootstrap**
   - Installs Crossplane on the infracluster
   - Configures Crossplane providers for GCP with appropriate permissions
   - Sets up custom resource definitions for managing GKE clusters

3. **Provision Application Clusters**
   - Uses Crossplane to provision application GKE clusters in service projects
   - Clusters connect to the shared VPC in the host project
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
| `infra/environments/dev/terraform.tfvars` | `your-gcp-project-id` | Your host GCP project ID | The host project for shared VPC |
| `infra/environments/dev/terraform.tfvars` | `your-dev-project-id` | Your dev project ID | Service project for dev environment |
| `infra/environments/dev/terraform.tfvars` | `your-staging-project-id` | Your staging project ID | Service project for staging environment |
| `infra/environments/dev/terraform.tfvars` | `your-prod-project-id` | Your prod project ID | Service project for prod environment |
| `infra/environments/dev/backend.tf` | `your-terraform-state-bucket` | Your GCS bucket name | From setup.sh output |
| **Crossplane Configuration** |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your dev project ID | Service project for dev GKE |
| `crossplane/xresources/dev-gke-cluster-claim.yaml` | `${GCP_HOST_PROJECT_ID}` | Your host project ID | Host project with shared VPC |
| `crossplane/xresources/staging-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your staging project ID | Service project for staging GKE |
| `crossplane/xresources/staging-gke-cluster-claim.yaml` | `${GCP_HOST_PROJECT_ID}` | Your host project ID | Host project with shared VPC |
| `crossplane/xresources/prod-gke-cluster-claim.yaml` | `${GCP_PROJECT_ID}` | Your prod project ID | Service project for prod GKE |
| `crossplane/xresources/prod-gke-cluster-claim.yaml` | `${GCP_HOST_PROJECT_ID}` | Your host project ID | Host project with shared VPC |
| **Application Deployment** |
| `workloads/hello-world/values.yaml` | `gcr.io/your-gcp-project-id/hello-world` | Your GCR image path | For container images |

## Google Cloud Architecture

### Multi-VPC Architecture with VPC Peering

The platform uses a multi-VPC architecture with VPC peering to provide enhanced isolation with controlled connectivity:

1. **Shared VPC in Host Project**
   - Houses the infracluster that runs Crossplane
   - Managed by Terraform in the host project
   - Acts as the central management hub for all clusters

2. **Environment-Specific VPCs in Service Projects**
   - Each environment (dev, staging, prod) has its own dedicated VPC
   - Complete network isolation between environments
   - Application clusters run in their respective VPCs
   - Separate CIDR ranges for each environment to avoid overlap

3. **VPC Peering Connections**
   - Connects each environment VPC to the shared VPC
   - Configured with Terraform's VPC peering resources
   - Bi-directional route exchange for cross-VPC communication
   - Enables the infracluster to manage application clusters across VPCs

4. **Benefits of this Architecture**
   - **Enhanced Security and Isolation:**
     - Application environments completely isolated from each other
     - Prevents unauthorized cross-environment access
     - Simplifies compliance with security requirements
   
   - **Flexible Network Design:**
     - Each environment can have custom network configurations
     - Independent subnet and CIDR planning
     - Environment-specific network policies
   
   - **Clear Resource Boundaries:**
     - Clean separation between infrastructure and applications
     - Different teams can manage different environments
     - Enhanced security through project and network boundaries
   
   - **Scalable Administration:**
     - Different IAM roles for infrastructure vs. application teams
     - Reduced risk of accidental infrastructure changes
     - Controlled access to production resources

### Infracluster (in Host Project)

The infracluster is a GKE cluster in the host project's shared VPC that runs Crossplane:

- **Size:** Regional cluster with 1-3 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 50-100GB SSD persistent disk
- **Networking:** Shared VPC with private nodes and VPC peering to all environment VPCs
- **Security:** Workload Identity, Shielded Nodes, Binary Authorization
- **Purpose:** Hosts Crossplane to manage application clusters across all environments

### Application Clusters (in Service Projects)

Application clusters are provisioned by Crossplane running on the infracluster:

#### Dev Cluster
- **Project:** Development service project
- **Size:** Zonal cluster with 1-3 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Networking:** Uses its own VPC (dev-vpc) with peering to the shared VPC
- **Environment:** Development and testing

#### Staging Cluster
- **Project:** Staging service project
- **Size:** Regional cluster with 2-5 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 70GB standard persistent disk
- **Networking:** Uses its own VPC (staging-vpc) with peering to the shared VPC
- **Environment:** Pre-production validation

#### Production Cluster
- **Project:** Production service project
- **Size:** Regional cluster with 3-7 nodes
- **Machine Type:** e2-standard-4
- **Disk:** 100GB SSD persistent disk
- **Networking:** Uses its own VPC (prod-vpc) with peering to the shared VPC
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

3. **Kubernetes Add-ons**
   - Managed as Helm charts with environment-specific values
   - Automated installation through workflows
   - Standardized configuration across environments

## Troubleshooting

### Common Issues

#### Workflow Failures
- Check GitHub Actions logs for detailed error messages
- Verify GitHub secrets are configured correctly
- Ensure service accounts have appropriate permissions

#### Crossplane Issues
- Check Crossplane logs: `kubectl logs -l app=crossplane -n crossplane-system`
- Verify provider configurations: `kubectl get providers -n crossplane-system`
- Check provider status: `kubectl get providers.pkg.crossplane.io -A -o wide`

#### VPC Peering Issues
- Verify VPC peering status: `gcloud compute networks peerings list --network=shared-vpc --project=HOST_PROJECT_ID`
- Check environment VPCs: `gcloud compute networks list --project=ENV_PROJECT_ID`
- Verify peering connectivity: `gcloud compute networks peerings describe peering-shared-vpc-to-dev-vpc --network=shared-vpc --project=HOST_PROJECT_ID`
- Check routes exchanged: `gcloud compute routes list --filter="network=shared-vpc" --project=HOST_PROJECT_ID`
- Test connectivity between VPCs: Create temporary VMs in each VPC and use `ping` to verify network connectivity

#### Shared VPC Issues
- Verify service project attachment: `gcloud compute shared-vpc get-host-project SERVICE_PROJECT_ID`
- Check subnets: `gcloud compute networks subnets list --network=shared-vpc --project=HOST_PROJECT_ID`
- Verify service account permissions: `gcloud projects get-iam-policy HOST_PROJECT_ID`

#### Cluster Provisioning
- Check Crossplane claim status: `kubectl get gkecluster.platform.commercelab.io`
- View detailed status: `kubectl describe gkecluster.platform.commercelab.io/dev-gke-cluster`
- Check Crossplane events: `kubectl get events -n crossplane-system`

## Security Considerations

The platform includes multiple security features:

1. **Network Security**
   - Private GKE clusters with authorized networks
   - Network policies for pod-to-pod communication
   - Shared VPC with controlled access

2. **Identity and Access Management**
   - Workload Identity for GCP service access
   - Least privilege service accounts
   - Separate IAM roles by project and environment

3. **Node Security**
   - Shielded nodes for enhanced VM security
   - Secure boot and integrity monitoring
   - Node auto-upgrades for security patches

4. **Workload Security**
   - Binary Authorization (optional for production)
   - Container image vulnerability scanning
   - Secrets management via External Secrets Operator

5. **Cluster Security**
   - GKE enterprise security features
   - Regular security scans
   - Maintenance windows for updates

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
   ./kubernetes-addons/install.sh \
     --email admin@example.com \
     --project your-gcp-project-id \
     --service-account your-external-secrets-sa@your-gcp-project-id.iam.gserviceaccount.com \
     --environment dev \
     --cluster-name dev-gke-cluster
   ```

## Cleanup

To remove all resources created by this project:

```bash
./scripts/cleanup.sh --host-project your-host-project-id \
  --service-projects your-dev-project-id,your-staging-project-id,your-prod-project-id
```

This script will:
1. Delete all application GKE clusters provisioned by Crossplane
2. Delete the infracluster
3. Delete IAM service accounts
4. Remove the shared VPC configuration
5. Clean up networking resources
6. Optionally delete the Terraform state bucket

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.