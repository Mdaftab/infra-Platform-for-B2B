## ==========================================================================
## Infrastructure (Infracluster) Variables
## ==========================================================================

variable "project_id" {
  description = "The GCP project ID"
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

## ==========================================================================
## Network Configuration
## ==========================================================================

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "infracluster-vpc"
}

variable "subnets" {
  description = "Subnet configurations for the VPC"
  type = list(object({
    name          = string
    ip_cidr_range = string
    region        = string
    private       = bool
    secondary_ranges = object({
      pods     = string
      services = string
    })
  }))
  default = [
    {
      name          = "infracluster-private-subnet"
      ip_cidr_range = "10.0.0.0/20"
      region        = "us-central1"
      private       = true
      secondary_ranges = {
        pods     = "10.16.0.0/16"
        services = "10.17.0.0/20"
      }
    },
    {
      name          = "infracluster-public-subnet"
      ip_cidr_range = "10.0.16.0/20"
      region        = "us-central1"
      private       = false
      secondary_ranges = {
        pods     = "10.18.0.0/16" 
        services = "10.19.0.0/20"
      }
    }
  ]

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }
}

## ==========================================================================
## Infracluster Configuration
## ==========================================================================

variable "infracluster_name" {
  description = "Name of the infrastructure GKE cluster"
  type        = string
  default     = "infracluster"
}

variable "infracluster_config" {
  description = "Configuration for the infrastructure GKE cluster"
  type = object({
    regional               = bool
    release_channel        = string
    master_ipv4_cidr_block = string
    machine_type           = string
    disk_size_gb           = number
    disk_type              = string
    node_count             = number
    enable_autoscaling     = bool
    min_nodes              = number
    max_nodes              = number
    preemptible            = bool
  })
  default = {
    regional               = false
    release_channel        = "REGULAR"
    master_ipv4_cidr_block = "172.16.0.0/28"
    machine_type           = "e2-standard-2"
    disk_size_gb           = 50
    disk_type              = "pd-standard"
    node_count             = 1
    enable_autoscaling     = true
    min_nodes              = 1
    max_nodes              = 3
    preemptible            = true
  }

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.infracluster_config.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }

  validation {
    condition     = var.infracluster_config.master_ipv4_cidr_block != null && can(cidrnetmask(var.infracluster_config.master_ipv4_cidr_block))
    error_message = "Master CIDR block must be a valid CIDR notation."
  }
}