# Multi-Cluster Kubernetes Management Platform with Enhanced Shared VPC

A modern Kubernetes infrastructure management solution using Terraform, Crossplane, and GitHub Actions to implement a scalable multi-cluster Kubernetes environment on Google Cloud Platform leveraging an enhanced shared VPC architecture for optimal connectivity, security, and future database integration.

## Architecture Overview

This platform implements an advanced infrastructure management approach using a shared VPC architecture:

1. **Infrastructure Layer (Terraform)**
   - Host Project with shared VPC network containing environment-specific subnets
   - Small, efficient "infracluster" GKE cluster provisioned with Terraform
   - Crossplane running on the infracluster to manage application clusters
   - Database subnet reserved for future database deployments
   - Infrastructure-as-Code principles throughout

2. **Service Projects Layer**
   - Separate GCP projects for different environments (dev, staging, prod)
   - Each environment uses dedicated subnets in the shared VPC
   - Subnet-level IAM permissions for fine-grained access control
   - Environment-specific firewall rules for controlled isolation

3. **Cluster Management Layer (Crossplane)**
   - Crossplane running on the infracluster to manage application clusters
   - Declarative custom resources for defining GKE clusters in service projects
   - Standardized compositions for consistent cluster configuration
   - Multi-environment support with unlimited GKE cluster scalability

4. **Application & Database Layer**
   - Application GKE clusters provisioned by Crossplane in service projects
   - Standardized cluster configuration with add-ons
   - Secure application deployment with TLS and secret management
   - Database subnet ready for managed database services

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│                 Host Project (shared-infra)                    │
│                                                                │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                    Shared VPC Network                       ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────┐ ││
│  │  │ Infra Subnet│  │ Dev Subnet  │  │Staging Subnet│ │Prod │ ││
│  │  └──────┬──────┘  └─────┬───────┘  └──────┬──────┘ │Subnet│ ││
│  │         │               │                 │         └──┬──┘ ││
│  │    ┌────┴────┐          │                 │            │    ││
│  │    │Infracluster         │                 │            │    ││
│  │    │(Crossplane)│        │                 │            │    ││
│  │    └────┬─────┘          │                 │            │    ││
│  │         │                │                 │            │    ││
│  └─────────┼────────────────┼─────────────────┼────────────┼────┘│
│  ┌─────────┼────────────────┼─────────────────┼────────────┼────┐│
│  │         │    Database Subnet (Reserved for future use)        ││
│  └─────────┼────────────────┼─────────────────┼────────────┼────┘│
└─────────────────────────────┼─────────────────┼────────────┼─────┘
  ┌─────────────┐  ┌──────────┼───────┐  ┌──────┼───────────┼────┐
  │ Dev Project │  │ Staging Project  │  │  Prod Project    │    │
  │             │  │                  │  │                  │    │
  │ ┌───────────┼──┼┐ ┌──────────────┼──┼┐ ┌───────────────┼────┼┐
  │ │Dev Cluster│  ││ │Staging Cluster│  ││ │Prod Cluster   │    ││
  │ │           │  ││ │               │  ││ │               │    ││
  │ │ ┌─────────┼──┼┼─┼─┐ ┌───────────┼──┼┼─┼─┐ ┌───────────┼────┼┼┐
  │ │ │Applications  │││ │Applications   │││ │Applications    │││
  │ │ └─────────────┘││ └───────────────┘││ └────────────────┘││
  │ └────────────────┘│ └────────────────┘│ └─────────────────┘│
  └──────────────────┘ └─────────────────┘ └──────────────────┘
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

### Enhanced Shared VPC Architecture

The platform uses an enhanced shared VPC architecture with environment-specific subnets to provide optimal connectivity and future database integration:

1. **Centralized Shared VPC in Host Project**
   - Houses all infrastructure and application networking in a single VPC
   - Contains environment-specific subnets for dev, staging, and production
   - Dedicated database subnet reserved for future database deployments
   - Managed by Terraform in the host project
   - Acts as the central management hub for all clusters

2. **Environment-Specific Subnets**
   - Each environment (dev, staging, prod) has its own dedicated subnet in the shared VPC
   - Connected to service projects through the shared VPC model
   - Predefined CIDR ranges optimized for each environment's needs
   - Secondary ranges for GKE pods and services carefully planned to avoid overlap

3. **Subnet-Level Access Control**
   - Fine-grained IAM permissions at the subnet level
   - Environment-specific service accounts given access only to their respective subnets
   - Database subnet accessible by all clusters with controlled permissions
   - Service project principals granted specific subnet access

4. **Benefits of this Architecture**
   - **Unlimited Cluster Scalability:**
     - No VPC peering quotas or networking constraints
     - Add as many GKE clusters as needed across environments
     - Direct connectivity without peering hops for optimal performance
   
   - **Database Integration Ready:**
     - Reserved subnet for future managed database services (Cloud SQL, etc.)
     - All clusters can connect directly to databases in the shared VPC
     - Consistent database access patterns across environments
   
   - **Enhanced Security with Simplicity:**
     - Firewall rules for controlled cross-environment access
     - Network policies for pod-level isolation
     - Simplified troubleshooting with centralized networking
   
   - **Operational Efficiency:**
     - Single network control plane
     - Reduced management overhead compared to multiple VPCs
     - Consistent networking patterns across all environments

### Infracluster (in Host Project)

The infracluster is a GKE cluster in the host project's shared VPC that runs Crossplane:

- **Size:** Regional cluster with 1-3 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 50-100GB SSD persistent disk
- **Networking:** Uses the infra subnet in the shared VPC
- **Security:** Workload Identity, Shielded Nodes, Binary Authorization
- **Purpose:** Hosts Crossplane to dynamically provision and manage application clusters

### Application Clusters (in Service Projects)

Application clusters are provisioned by Crossplane running on the infracluster:

#### Dev Cluster
- **Project:** Development service project
- **Size:** Zonal cluster with 1-3 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 50GB standard persistent disk
- **Networking:** Uses the dev subnet in the shared VPC
- **Environment:** Development and testing

#### Staging Cluster
- **Project:** Staging service project
- **Size:** Regional cluster with 2-5 nodes
- **Machine Type:** e2-standard-2
- **Disk:** 70GB standard persistent disk
- **Networking:** Uses the staging subnet in the shared VPC
- **Environment:** Pre-production validation

#### Production Cluster
- **Project:** Production service project
- **Size:** Regional cluster with 3-7 nodes
- **Machine Type:** e2-standard-4
- **Disk:** 100GB SSD persistent disk
- **Networking:** Uses the production subnet in the shared VPC
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

#### Shared VPC Issues
- Verify service project attachment: `gcloud compute shared-vpc get-host-project SERVICE_PROJECT_ID`
- List subnets in shared VPC: `gcloud compute networks subnets list --network=shared-vpc --project=HOST_PROJECT_ID`
- Check subnet IAM bindings: `gcloud projects get-iam-policy HOST_PROJECT_ID --format=json | grep -A 10 "compute.subnetworks.use"`
- Verify service account permissions: `gcloud projects get-iam-policy HOST_PROJECT_ID`

#### Subnet and Firewall Issues
- List firewall rules: `gcloud compute firewall-rules list --project=HOST_PROJECT_ID --filter="network=shared-vpc"`
- Verify connectivity between subnets: Create temporary pods in different clusters and use `kubectl exec` to run connectivity tests
- Check network policy enforcement: `kubectl get networkpolicies --all-namespaces`
- Examine VPC flow logs for denied traffic: Use Cloud Logging to query flow logs for blocked connectivity

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

## Future Database Integration

The architecture is designed for seamless database integration in the shared VPC:

1. **Database Subnet Configuration:**
   - A dedicated subnet (`db-subnet`) is pre-configured in the shared VPC
   - CIDR range (`10.80.0.0/20`) strategically allocated for database services
   - No secondary IP ranges needed for typical database deployments
   - Environment-specific firewall rules already defined for database access

2. **Supported Database Options:**
   - **Cloud SQL:** Private Service Access already configured for MySQL, PostgreSQL, or SQL Server
   - **Memorystore:** Redis or Memcached instances for caching layers
   - **MongoDB Atlas:** Private endpoint configuration through the shared VPC
   - **Spanner:** Google Cloud Spanner for globally distributed databases
   - **BigTable/BigQuery:** Analytics databases with private connectivity

3. **Deployment Process:**
   ```terraform
   # Example Terraform code for adding Cloud SQL to the architecture
   module "database" {
     source           = "terraform-google-modules/sql-db/google//modules/postgresql"
     project_id       = var.project_id
     name             = "example-db"
     database_version = "POSTGRES_13"
     region           = "us-central1"
     
     # Use the database subnet with private IP
     private_network  = module.shared_vpc.network_id
     ip_configuration = {
       ipv4_enabled       = false
       require_ssl        = true
       private_network    = module.shared_vpc.network_id
       allocated_ip_range = "db-subnet"
     }
   }
   ```

4. **Multi-Environment Database Access:**
   - Each environment can have dedicated database instances in the shared subnet
   - Production data isolation maintained through instance-level separation
   - Consistent connection patterns across all environments
   - Service accounts with fine-grained IAM permissions for database access

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