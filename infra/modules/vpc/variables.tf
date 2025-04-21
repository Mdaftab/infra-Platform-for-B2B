variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
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
}
