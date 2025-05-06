## ==========================================================================
## Infrastructure (Infracluster) Variables
## ==========================================================================

variable "project_id" {
  description = "The GCP project ID for the infrastructure project"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project IDs must be between 6 and 30 characters, lowercase letters, numbers, and hyphens only, must start with a letter and cannot end with a hyphen."
  }
}

variable "region" {
  description = "The GCP region for the infrastructure"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region (e.g., us-central1)."
  }
}

variable "apis_to_enable" {
  description = "List of GCP APIs to enable for this environment. Different clients/environments may need different sets of APIs."
  type        = list(string)
  default = [
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
  ]
}

## ==========================================================================
## Infrastructure VPC Network Configuration
## ==========================================================================

variable "infra_vpc_config" {
  description = "Configuration for the infrastructure VPC network"
  type = object({
    network_name        = string
    enable_flow_logs    = optional(bool, true)
    create_nat_gateway  = optional(bool, true)
    subnets = list(object({
      name           = string
      ip_cidr_range  = string
      region         = string
      private        = bool
      secondary_ranges = object({
        pods     = string
        services = string
      })
    }))
  })

  validation {
    condition     = length(var.infra_vpc_config.subnets) > 0
    error_message = "At least one subnet must be defined in the infrastructure VPC."
  }
}

## ==========================================================================
## Infracluster Configuration
## ==========================================================================

variable "infracluster_config" {
  description = "Configuration for the infrastructure GKE cluster (infracluster)"
  type = object({
    name                 = string
    description          = optional(string, "Shared infrastructure GKE cluster for Crossplane")
    regional             = optional(bool, true)
    location             = string
    release_channel      = string
    network_config = object({
      network_name            = string
      subnet_name             = string
      master_ipv4_cidr_block  = string
      cluster_ipv4_cidr_block = optional(string)
      services_ipv4_cidr_block = optional(string)
    })
    node_pools = list(object({
      name          = string
      machine_type  = string
      disk_size_gb  = number
      disk_type     = string
      node_count    = number
      autoscaling   = object({
        min_node_count = number
        max_node_count = number
      })
      management    = object({
        auto_repair  = bool
        auto_upgrade = bool
      })
      node_metadata = string
      preemptible   = bool
      labels        = map(string)
      tags          = list(string)
    }))
    maintenance_window = optional(object({
      start_time  = string
      end_time    = optional(string)
      recurrence  = optional(string)
    }))
    security_config = optional(object({
      enable_shielded_nodes       = optional(bool, true)
      enable_integrity_monitoring = optional(bool, true)
      enable_secure_boot          = optional(bool, true)
      enable_binary_authorization = optional(bool, false)
      enable_network_policy       = optional(bool, true)
      enable_intranode_visibility = optional(bool, false)
    }))
  })

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.infracluster_config.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }

  validation {
    condition     = length(var.infracluster_config.node_pools) > 0
    error_message = "At least one node pool must be defined for the infracluster."
  }
}