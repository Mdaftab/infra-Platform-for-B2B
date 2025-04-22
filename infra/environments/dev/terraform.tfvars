## ==========================================================================
## Shared Infrastructure Environment Configuration
## ==========================================================================

# Project Settings
project_id = "your-gcp-project-id"
region = "us-central1"

# Network - Enhanced Shared VPC Configuration
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
  
  # Subnets configuration with environment-specific subnets in the shared VPC
  subnets = [
    # Infrastructure subnet for the infracluster
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
    
    # Development environment subnet in the shared VPC
    {
      name = "dev-subnet"
      ip_cidr_range = "10.20.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.32.0.0/16"
        services = "10.33.0.0/20"
      }
    },
    
    # Staging environment subnet in the shared VPC
    {
      name = "staging-subnet"
      ip_cidr_range = "10.40.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.48.0.0/16"
        services = "10.49.0.0/20"
      }
    },
    
    # Production environment subnet in the shared VPC
    {
      name = "prod-subnet"
      ip_cidr_range = "10.60.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.64.0.0/16"
        services = "10.65.0.0/20"
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
  
  # Subnet IAM bindings - environment-specific service accounts
  # can use specific subnets in the shared VPC
  subnet_iam_bindings = {
    "dev-subnet" = [
      {
        role = "roles/compute.networkUser"
        members = [
          "serviceAccount:service-{your-dev-project-number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:shared-gke-node-sa@your-dev-project-id.iam.gserviceaccount.com"
        ]
      }
    ],
    "staging-subnet" = [
      {
        role = "roles/compute.networkUser"
        members = [
          "serviceAccount:service-{your-staging-project-number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:shared-gke-node-sa@your-staging-project-id.iam.gserviceaccount.com"
        ]
      }
    ],
    "prod-subnet" = [
      {
        role = "roles/compute.networkUser"
        members = [
          "serviceAccount:service-{your-prod-project-number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:shared-gke-node-sa@your-prod-project-id.iam.gserviceaccount.com"
        ]
      }
    ],
    "db-subnet" = [
      {
        role = "roles/compute.networkUser"
        members = [
          "serviceAccount:service-{your-dev-project-number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:service-{your-staging-project-number}@container-engine-robot.iam.gserviceaccount.com", 
          "serviceAccount:service-{your-prod-project-number}@container-engine-robot.iam.gserviceaccount.com"
        ]
      }
    ]
  }
  
  # Environment-specific firewall rules
  firewall_rules = {
    "allow-dev-to-db" = {
      description = "Allow Dev GKE cluster to access DB subnet"
      source_ranges = ["10.20.0.0/20", "10.32.0.0/16"]
      target_ranges = ["10.80.0.0/20"]
      allow = [{
        protocol = "tcp"
        ports = ["3306", "5432", "6379", "27017"]
      }]
    },
    "allow-staging-to-db" = {
      description = "Allow Staging GKE cluster to access DB subnet"
      source_ranges = ["10.40.0.0/20", "10.48.0.0/16"]
      target_ranges = ["10.80.0.0/20"]
      allow = [{
        protocol = "tcp"
        ports = ["3306", "5432", "6379", "27017"]
      }]
    },
    "allow-prod-to-db" = {
      description = "Allow Prod GKE cluster to access DB subnet"
      source_ranges = ["10.60.0.0/20", "10.64.0.0/16"]
      target_ranges = ["10.80.0.0/20"]
      allow = [{
        protocol = "tcp"
        ports = ["3306", "5432", "6379", "27017"]
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