# Infrastructure Resources

This directory contains Terraform code for provisioning the base infrastructure of the Multi-Cluster Kubernetes Management Platform.

## Directory Structure

- **modules/**: Reusable Terraform modules
  - **vpc/**: Network and VPC configuration
  - **gke/**: GKE cluster configuration
  - **iam/**: IAM permissions and service accounts
  - **apis/**: Configurable API enablement
  - **container-registry/**: Container Registry setup

- **environments/**: Environment-specific configurations
  - **dev/**: Development environment configuration

## Key Features

### Flexible API Management

The APIs module now supports customizable API enablement per environment:

```hcl
module "apis" {
  source         = "../../modules/apis"
  project_id     = var.project_id
  apis_to_enable = var.apis_to_enable
}
```

This allows different clients to enable only the APIs they need, which improves security and reduces unnecessary service enablement.

### Two Architecture Options

1. **Shared VPC Architecture**
   - Defined in the `vpc` module
   - Central host project with service projects attached
   - Subnet-level isolation for different environments

2. **Dedicated VPC Architecture**
   - Dynamically created by Crossplane compositions
   - Complete network isolation per client
   - Independent billing and quota management

## Usage

The infrastructure is typically deployed using the GitHub Actions workflow or manually with:

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

After the base infrastructure is deployed, Crossplane is used to dynamically provision client resources.