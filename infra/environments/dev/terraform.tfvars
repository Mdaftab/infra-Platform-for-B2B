## ==========================================================================
## Infrastructure Environment Configuration
## ==========================================================================

# Project Settings
project_id = "your-gcp-project-id"
region = "us-central1"

# Network 
network_name = "infracluster-vpc"

# Infracluster Settings
infracluster_name = "infracluster"
infracluster_config = {
  regional = false   # Use zonal cluster to save costs
  release_channel = "REGULAR"
  master_ipv4_cidr_block = "172.16.0.0/28"
  machine_type = "e2-standard-2"
  disk_size_gb = 50
  disk_type = "pd-standard"
  node_count = 1
  enable_autoscaling = true
  min_nodes = 1
  max_nodes = 3
  preemptible = true
}