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

module "gke" {
  source      = "../../modules/gke"
  depends_on  = [module.vpc, module.iam, module.apis]
  project_id  = var.project_id
  region      = var.region
  cluster_name = "${var.environment}-crossplane-mgmt"
  
  # Networking
  network_name = module.vpc.network_name
  subnet_name  = module.vpc.subnet_names["${var.environment}-private-subnet"]
  cluster_secondary_range_name  = module.vpc.subnet_secondary_ranges["${var.environment}-private-subnet"].pods
  services_secondary_range_name = module.vpc.subnet_secondary_ranges["${var.environment}-private-subnet"].services
  
  # GKE configuration
  regional            = true
  release_channel     = "REGULAR"
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  
  # Node pool configuration
  service_account     = module.iam.gke_node_sa_email
  machine_type        = "e2-standard-2"
  disk_size_gb        = 100
  disk_type           = "pd-standard"
  node_count          = 3
  enable_autoscaling  = true
  min_nodes           = 1
  max_nodes           = 5
  preemptible         = false
  
  # Node labels and tags
  node_labels = {
    environment = var.environment
    role        = "crossplane-management"
  }
  node_tags = ["${var.environment}-gke", "crossplane-mgmt"]
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
