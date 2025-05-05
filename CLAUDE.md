# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-Cluster Kubernetes Management Platform is a solution for deploying and managing multiple GKE clusters across environments using Terraform, Crossplane, and GitHub Actions. It creates a central infrastructure cluster that can provision and manage application clusters across development, staging, and production environments using a shared VPC architecture.

## Key Components

1. **Infrastructure Cluster (Infracluster)**
   - Central GKE cluster that runs Crossplane 
   - Provisions and manages application clusters
   - Located in the Host Project's shared VPC

2. **Application Clusters**
   - Dynamically provisioned using Crossplane
   - Located in separate service projects
   - Connected to the shared VPC network
   - Environment-specific configurations (dev, staging, prod)

3. **Shared VPC Architecture**
   - Host project containing the shared VPC network
   - Separate subnets for each environment
   - Service projects for application workloads

## Important Files

- `/infra/environments/dev/main.tf`: Main Terraform configuration for the infrastructure
- `/infra/modules/`: Reusable Terraform modules (gke, vpc, iam, etc.)
- `/crossplane/compositions/gke-cluster.yaml`: Crossplane composition for GKE clusters
- `/crossplane/xresources/*.yaml`: Cluster definitions and claims for different environments
- `/workloads/hello-world/`: Sample application for deployment

## Required Environment Variables

When deploying the platform, these environment variables need to be set:

- `GCP_HOST_PROJECT_ID`: The host project ID for shared VPC
- `GCP_PROJECT_ID`: The service project ID for application clusters
- `GCP_SA_KEY`: Base64-encoded service account key
- `GCP_TERRAFORM_STATE_BUCKET`: GCS bucket for Terraform state

## Common Commands

### Setup and Initial Deployment

```bash
# Set up required GCP resources
./scripts/setup.sh

# Deploy infrastructure using Terraform
cd infra/environments/dev
terraform init
terraform plan
terraform apply

# Install cluster add-ons
./scripts/install-cluster-addons.sh
```

### Working with Crossplane

```bash
# Get GKE clusters managed by Crossplane
kubectl --context=infracluster get gkecluster.platform.commercelab.io

# Create a new GKE cluster claim
kubectl --context=infracluster apply -f crossplane/xresources/dev-gke-cluster-claim.yaml

# Delete a GKE cluster claim
kubectl --context=infracluster delete -f crossplane/xresources/dev-gke-cluster-claim.yaml
```

### Deploying Workloads

```bash
# Connect to a specific GKE cluster
gcloud container clusters get-credentials dev-gke-cluster \
  --project=your-dev-project-id --region=us-central1

# Deploy the sample application
helm upgrade --install hello-world ./workloads/hello-world \
  --namespace default \
  --set environment=development
```

### Cleanup Resources

```bash
# Clean up all GCP resources
./scripts/cleanup.sh \
  --host-project your-host-project-id \
  --service-projects your-dev-project-id,your-staging-project-id,your-prod-project-id
```

## Architecture Considerations

1. **Network Architecture**
   - Subnets are carefully allocated to prevent IP conflicts
   - Each environment has dedicated pod and service CIDRs
   - Private clusters with limited public access

2. **Security**
   - GKE clusters are configured with shielded nodes
   - Network policies enabled by default
   - Private GKE clusters with limited public access
   - Service accounts with least privilege

3. **High Availability**
   - Staging and production clusters use regional configuration
   - Custom maintenance windows avoid business hours
   - Node auto-scaling enabled for all clusters

## Workflow

1. Terraform provisions the base infrastructure (VPC, IAM, Infracluster)
2. Crossplane is installed on the Infracluster
3. Crossplane provisions application clusters in service projects
4. Kubernetes add-ons are installed on all clusters
5. Applications are deployed to application clusters

## Troubleshooting

When troubleshooting issues, check:

1. GCP service account permissions
2. Shared VPC configuration and subnet IAM bindings
3. Crossplane logs in the infracluster
4. Cluster connectivity between environments