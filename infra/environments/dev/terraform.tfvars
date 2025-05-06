## ==========================================================================
## Infrastructure Environment Configuration
## ==========================================================================

# Project Settings
project_id = "your-gcp-project-id"
region = "us-central1"

# APIs to enable for this environment
# You can customize this list for each client/environment
apis_to_enable = [
  "container.googleapis.com",         # GKE API
  "compute.googleapis.com",           # Compute Engine API
  "iam.googleapis.com",               # IAM API
  "serviceusage.googleapis.com",      # Service Usage API
  "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
  "artifactregistry.googleapis.com",  # Artifact Registry API
  "containerregistry.googleapis.com", # Container Registry API
  "secretmanager.googleapis.com",     # Secret Manager API
  "servicenetworking.googleapis.com", # Service Networking API
  "monitoring.googleapis.com",        # Cloud Monitoring API
  "logging.googleapis.com",           # Cloud Logging API
  # Add client-specific APIs as needed
  # "cloudfunctions.googleapis.com",  # Example additional API for Function-based client
  # "pubsub.googleapis.com",          # Example additional API for event-driven client
  # "spanner.googleapis.com",         # Example additional API for high-scale client
]

# Network - Infrastructure VPC Configuration
infra_vpc_config = {
  # Main network settings
  network_name = "infra-vpc"
  enable_flow_logs = true
  create_nat_gateway = true
  
  # Subnets configuration for the infrastructure VPC
  subnets = [
    # Infrastructure subnet for the infracluster
    {
      name = "infra-subnet"
      ip_cidr_range = "10.0.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.16.0.0/16"
        services = "10.17.0.0/20"
      }
    },
    
    # Database subnet (reserved for future database deployments)
    {
      name = "db-subnet"
      ip_cidr_range = "10.80.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = null
    },
    
    # External-facing subnet for load balancers and services
    {
      name = "proxy-subnet"
      ip_cidr_range = "10.0.16.0/22"
      region = "us-central1"
      private = false
      secondary_ranges = {
        pods = "10.18.0.0/16"
        services = "10.19.0.0/20"
      }
    }
  ]
  
  # Infrastructure-specific firewall rules
  firewall_rules = {
    "allow-infra-to-db" = {
      description = "Allow Infrastructure GKE cluster to access DB subnet"
      source_ranges = ["10.0.0.0/20", "10.16.0.0/16"]
      target_ranges = ["10.80.0.0/20"]
      allow = [{
        protocol = "tcp"
        ports = ["3306", "5432", "6379", "27017"]
      }]
    },
    "allow-all-internal" = {
      description = "Allow all traffic between internal subnets"
      source_ranges = ["10.0.0.0/8"]
      target_ranges = ["10.0.0.0/8"]
      allow = [{
        protocol = "all"
      }]
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
    network_name = "infra-vpc"
    subnet_name = "infra-subnet" 
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
        environment = "infrastructure"
        role = "infrastructure"
      }
      tags = ["infra-vpc", "infracluster"]
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