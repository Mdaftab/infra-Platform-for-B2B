variable "project_id" {
  description = "The GCP project ID"
  default     = "your-gcp-project-id"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  default     = "dev"
}

variable "region" {
  description = "The GCP region"
  default     = "us-central1"
}

variable "network_name" {
  description = "The name of the VPC network"
  default     = "dev-vpc"
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
      name          = "dev-private-subnet"
      ip_cidr_range = "10.0.0.0/20"
      region        = "us-central1"
      private       = true
      secondary_ranges = {
        pods     = "10.16.0.0/16"
        services = "10.17.0.0/20"
      }
    },
    {
      name          = "dev-public-subnet"
      ip_cidr_range = "10.0.16.0/20"
      region        = "us-central1"
      private       = false
      secondary_ranges = {
        pods     = "10.18.0.0/16"
        services = "10.19.0.0/20"
      }
    }
  ]
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the control plane"
  default     = "172.16.0.0/28"
}
