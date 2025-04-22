## ==========================================================================
## Shared Infrastructure Environment Configuration
## ==========================================================================

# Project Settings
project_id = "your-gcp-project-id"
region = "us-central1"

# Network - Shared VPC Configuration
shared_vpc_config = {
  # Main network settings
  network_name = "shared-vpc"
  enable_flow_logs = true
  create_nat_gateway = true
  
  # Enable shared VPC host project
  is_shared_vpc_host = true
  
  # Service projects to attach to shared VPC
  service_project_ids = [
    "your-dev-project-id",      # Development environment project
    "your-staging-project-id",  # Staging environment project
    "your-prod-project-id"      # Production environment project
  ]
  
  # Subnets configuration
  subnets = [
    {
      name = "shared-infra-subnet"
      ip_cidr_range = "10.0.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.16.0.0/16"
        services = "10.17.0.0/20"
      }
    },
    {
      name = "shared-proxy-subnet"
      ip_cidr_range = "10.0.16.0/22"
      region = "us-central1"
      private = false
      secondary_ranges = {
        pods = "10.18.0.0/16"
        services = "10.19.0.0/20"
      }
    }
  ]
  
  # VPC Peering configurations
  vpc_peerings = {
    "dev-vpc-peering" = {
      project_id = "your-dev-project-id"
      vpc_name = "dev-vpc"
      export_custom_routes = true
      import_custom_routes = true
    },
    "staging-vpc-peering" = {
      project_id = "your-staging-project-id"
      vpc_name = "staging-vpc"
      export_custom_routes = true
      import_custom_routes = true
    },
    "prod-vpc-peering" = {
      project_id = "your-prod-project-id"
      vpc_name = "prod-vpc"
      export_custom_routes = true
      import_custom_routes = true
    }
  }
}

# Infracluster GKE Configuration
infracluster_config = {
  name = "infracluster"
  description = "Shared infrastructure GKE cluster for Crossplane"
  regional = true  
  location = "us-central1"
  release_channel = "REGULAR"
  network_config = {
    network_name = "shared-vpc"
    subnet_name = "shared-infra-subnet" 
    master_ipv4_cidr_block = "172.16.0.0/28"
    cluster_ipv4_cidr_block = "10.16.0.0/16"
    services_ipv4_cidr_block = "10.17.0.0/20"
  }
  
  # Node pool configuration
  node_pools = [
    {
      name = "default-pool"
      machine_type = "e2-standard-2"
      disk_size_gb = 100
      disk_type = "pd-standard"
      node_count = 1
      autoscaling = {
        min_node_count = 1
        max_node_count = 3
      }
      management = {
        auto_repair = true
        auto_upgrade = true
      }
      node_metadata = "GKE_METADATA"
      preemptible = true
      labels = {
        environment = "shared"
        role = "infrastructure"
      }
      tags = ["shared-vpc", "infracluster"]
    }
  ]
  
  # Maintenance and security settings
  maintenance_window = {
    start_time = "03:00"
    end_time = "08:00"
    recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
  }
  
  # Security settings
  security_config = {
    enable_shielded_nodes = true
    enable_integrity_monitoring = true
    enable_secure_boot = true
    enable_binary_authorization = true
    enable_network_policy = true
    enable_intranode_visibility = true
  }
}