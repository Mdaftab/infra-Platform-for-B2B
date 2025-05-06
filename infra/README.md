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

### Dedicated VPC Architecture

The platform uses a dedicated VPC architecture:
- Dynamically created by Crossplane compositions
- Complete network isolation per client in separate projects
- Independent billing and quota management
- Full tenant isolation with dedicated resources

## Usage

The infrastructure is typically deployed using the GitHub Actions workflow or manually with:

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

After the base infrastructure is deployed, Crossplane is used to dynamically provision client resources.