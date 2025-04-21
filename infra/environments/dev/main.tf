provider "google" {
  project = var.project_id
  region  = var.region
}

module "vpc" {
  source       = "../../modules/vpc"
  project_id   = var.project_id
  network_name = var.network_name
  region       = var.region
  environment  = var.environment
  subnets      = var.subnets
}

module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  environment = var.environment
}

module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

module "gcr" {
  source                = "../../modules/container-registry"
  project_id            = var.project_id
  location              = "us"  # Multi-regional registry for better performance
  gke_node_sa_email     = module.iam.gke_node_sa_email
  github_actions_sa_email = module.iam.github_actions_sa_email
  depends_on            = [module.apis] # Ensure APIs are enabled first
}

module "gke" {
  source      = "../../modules/gke"
  depends_on  = [module.vpc, module.iam, module.apis]
  project_id  = var.project_id
  region      = var.region
  cluster_name = "infracluster"
  
  # Networking
  network_name = module.vpc.network_name
  subnet_name  = module.vpc.subnet_names["${var.environment}-private-subnet"]
  cluster_secondary_range_name  = module.vpc.subnet_secondary_ranges["${var.environment}-private-subnet"].pods
  services_secondary_range_name = module.vpc.subnet_secondary_ranges["${var.environment}-private-subnet"].services
  
  # GKE configuration - Smaller zonal cluster for infrastructure management
  regional            = false  # Use zonal cluster to save costs
  release_channel     = "REGULAR"
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  
  # Node pool configuration - Smaller, more efficient nodes
  service_account     = module.iam.gke_node_sa_email
  machine_type        = "e2-standard-2"
  disk_size_gb        = 50     # Reduced disk size
  disk_type           = "pd-standard"
  node_count          = 1      # Single node pool to start
  enable_autoscaling  = true
  min_nodes           = 1
  max_nodes           = 3      # Reduced max nodes
  preemptible         = true   # Use preemptible VMs to reduce cost
  
  # Node labels and tags
  node_labels = {
    environment = var.environment
    role        = "infrastructure"
  }
  node_tags = ["${var.environment}-gke", "infracluster"]
}

# Store kubeconfig as a local file for GitHub Actions to use
resource "local_file" "kubeconfig" {
  content  = module.gke.kubeconfig
  filename = "${path.module}/kubeconfig"
}

# Store Crossplane service account key for bootstrapping
resource "local_file" "crossplane_sa_key" {
  content  = module.iam.crossplane_sa_key
  filename = "${path.module}/crossplane-sa-key.json"
}
