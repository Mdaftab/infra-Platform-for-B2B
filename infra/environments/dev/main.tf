/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

## ==========================================================================
## Infrastructure Configuration
## This implements an infrastructure project with a GKE cluster that runs
## Crossplane to dynamically provision client-specific resources in dedicated projects.
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
  resource_prefix = var.infracluster_config.name
  common_labels = {
    managed_by  = "terraform"
    project     = var.project_id
    application = "crossplane-infrastructure"
    environment = "infrastructure"
  }
}

## ==========================================================================
## API Enablement
## ==========================================================================

module "apis" {
  source         = "../../modules/apis"
  project_id     = var.project_id
  apis_to_enable = var.apis_to_enable
}

## ==========================================================================
## Infrastructure VPC Network
## ==========================================================================

module "infra_vpc" {
  source       = "../../modules/vpc"
  project_id   = var.project_id
  network_name = var.infra_vpc_config.network_name
  region       = var.region
  environment  = "infrastructure"
  
  # Network settings
  subnets               = var.infra_vpc_config.subnets
  enable_flow_logs      = var.infra_vpc_config.enable_flow_logs
  create_nat_gateway    = var.infra_vpc_config.create_nat_gateway
  
  # Firewall rules
  firewall_rules        = lookup(var.infra_vpc_config, "firewall_rules", {})
  
  # Enable more secure networking by preventing destruction
  prevent_destroy       = true
  
  depends_on = [module.apis]
}

## ==========================================================================
## IAM Configuration
## ==========================================================================

module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  environment = "infrastructure" # These service accounts are for the infrastructure cluster
  
  depends_on  = [module.apis]
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
  depends_on  = [module.infra_vpc, module.iam, module.apis]
  
  # Basic cluster configuration
  project_id   = var.project_id
  region       = var.infracluster_config.location
  cluster_name = var.infracluster_config.name
  description  = var.infracluster_config.description
  
  # Networking
  network_name                 = module.infra_vpc.network_name
  subnet_name                  = module.infra_vpc.subnet_names[var.infracluster_config.network_config.subnet_name]
  cluster_secondary_range_name = module.infra_vpc.subnet_secondary_ranges[var.infracluster_config.network_config.subnet_name].pods
  services_secondary_range_name = module.infra_vpc.subnet_secondary_ranges[var.infracluster_config.network_config.subnet_name].services
  
  # GKE configuration
  regional                 = var.infracluster_config.regional
  release_channel          = var.infracluster_config.release_channel
  master_ipv4_cidr_block   = var.infracluster_config.network_config.master_ipv4_cidr_block
  
  # Node pool configuration - for infracluster we use the first node pool
  service_account     = module.iam.gke_node_sa_email
  machine_type        = var.infracluster_config.node_pools[0].machine_type
  disk_size_gb        = var.infracluster_config.node_pools[0].disk_size_gb
  disk_type           = var.infracluster_config.node_pools[0].disk_type
  node_count          = var.infracluster_config.node_pools[0].node_count
  enable_autoscaling  = true
  min_nodes           = var.infracluster_config.node_pools[0].autoscaling.min_node_count
  max_nodes           = var.infracluster_config.node_pools[0].autoscaling.max_node_count
  preemptible         = var.infracluster_config.node_pools[0].preemptible
  
  # Node labels and tags
  node_labels         = merge(local.common_labels, var.infracluster_config.node_pools[0].labels)
  node_tags           = var.infracluster_config.node_pools[0].tags
  
  # Security configuration
  enable_shielded_nodes = lookup(var.infracluster_config.security_config, "enable_shielded_nodes", true)
  enable_binary_authorization = lookup(var.infracluster_config.security_config, "enable_binary_authorization", false)
  enable_network_policy = lookup(var.infracluster_config.security_config, "enable_network_policy", true)
  
  # Maintenance window
  maintenance_start_time = lookup(var.infracluster_config.maintenance_window, "start_time", "03:00")
  maintenance_end_time = lookup(var.infracluster_config.maintenance_window, "end_time", null)
  maintenance_recurrence = lookup(var.infracluster_config.maintenance_window, "recurrence", null)
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

# Store infrastructure VPC info for reference
resource "local_file" "infra_vpc_info" {
  content = jsonencode({
    network_name = module.infra_vpc.network_name
    network_id   = module.infra_vpc.network_id
    subnet_ids   = module.infra_vpc.subnet_ids
    subnet_names = module.infra_vpc.subnet_names
    subnets      = {
      for name, subnet in module.infra_vpc.subnet_names : name => {
        region     = module.infra_vpc.subnet_regions[name]
        cidr_block = module.infra_vpc.subnet_cidr_blocks[name]
        pods_cidr  = module.infra_vpc.subnet_secondary_cidr_blocks[name].pods
        svc_cidr   = module.infra_vpc.subnet_secondary_cidr_blocks[name].services
      }
    }
  })
  filename        = "${path.module}/infra-vpc-info.json"
  file_permission = "0644"
}