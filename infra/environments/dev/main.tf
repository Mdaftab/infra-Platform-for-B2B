## ==========================================================================
## Infrastructure Configuration
## This is the ONLY infrastructure managed directly by Terraform.
## All application clusters will be managed by Crossplane running on this infracluster.
## ==========================================================================

# Configure provider with minimal access scopes for security
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Add local variables for consistent naming and tagging
locals {
  resource_prefix = var.infracluster_name
  common_tags = {
    managed_by  = "terraform"
    project     = var.project_id
    purpose     = "infrastructure"
  }
}

## ==========================================================================
## Networking Setup - Shared by all clusters
## ==========================================================================

module "vpc" {
  source       = "../../modules/vpc"
  project_id   = var.project_id
  network_name = var.network_name
  region       = var.region
  environment  = "shared" # This network is shared by all clusters
  subnets      = var.subnets
}

## ==========================================================================
## IAM Configuration
## ==========================================================================

module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  environment = "shared" # These service accounts are shared among all clusters
}

## ==========================================================================
## API Enablement
## ==========================================================================

module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

## ==========================================================================
## Container Registry
## ==========================================================================

module "gcr" {
  source                   = "../../modules/container-registry"
  project_id               = var.project_id
  location                 = "us"  # Multi-regional registry for better performance
  gke_node_sa_email        = module.iam.gke_node_sa_email
  github_actions_sa_email  = module.iam.github_actions_sa_email
  depends_on               = [module.apis] # Ensure APIs are enabled first
}

## ==========================================================================
## Infrastructure GKE Cluster (Infracluster)
## ==========================================================================

module "gke" {
  source      = "../../modules/gke"
  depends_on  = [module.vpc, module.iam, module.apis]
  
  # Basic cluster configuration
  project_id   = var.project_id
  region       = var.region
  cluster_name = var.infracluster_name
  
  # Networking
  network_name = module.vpc.network_name
  subnet_name  = module.vpc.subnet_names["${var.infracluster_name}-private-subnet"]
  cluster_secondary_range_name  = module.vpc.subnet_secondary_ranges["${var.infracluster_name}-private-subnet"].pods
  services_secondary_range_name = module.vpc.subnet_secondary_ranges["${var.infracluster_name}-private-subnet"].services
  
  # GKE configuration
  regional                 = var.infracluster_config.regional
  release_channel          = var.infracluster_config.release_channel
  master_ipv4_cidr_block   = var.infracluster_config.master_ipv4_cidr_block
  
  # Node configuration
  service_account     = module.iam.gke_node_sa_email
  machine_type        = var.infracluster_config.machine_type
  disk_size_gb        = var.infracluster_config.disk_size_gb
  disk_type           = var.infracluster_config.disk_type
  node_count          = var.infracluster_config.node_count
  enable_autoscaling  = var.infracluster_config.enable_autoscaling
  min_nodes           = var.infracluster_config.min_nodes
  max_nodes           = var.infracluster_config.max_nodes
  preemptible         = var.infracluster_config.preemptible
  
  # Node labels and tags
  node_labels = {
    purpose = "infrastructure"
    cluster = var.infracluster_name
  }
  node_tags = ["${var.infracluster_name}", "infrastructure"]
}

## ==========================================================================
## Output Files for GitHub Actions
## ==========================================================================

# Store kubeconfig as a local file for GitHub Actions to use
resource "local_file" "kubeconfig" {
  content         = module.gke.kubeconfig
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600" # Ensure secure permissions for kubeconfig file
}

# Store Crossplane service account key for bootstrapping
resource "local_file" "crossplane_sa_key" {
  content         = module.iam.crossplane_sa_key
  filename        = "${path.module}/crossplane-sa-key.json"
  file_permission = "0600" # Ensure secure permissions for key file
}