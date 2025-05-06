/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project IDs must be between 6 and 30 characters, lowercase letters, numbers, and hyphens only, must start with a letter and cannot end with a hyphen."
  }
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.network_name))
    error_message = "Network name must start with a letter and be lowercase letters, numbers, and hyphens only, max 63 characters."
  }
}

variable "region" {
  description = "The GCP region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region (e.g., us-central1)."
  }
}

variable "environment" {
  description = "Environment name (e.g., infrastructure, dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["infrastructure", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: infrastructure, dev, staging, prod."
  }
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

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC flow logs for this network"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Whether to create a NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "router_asn" {
  description = "ASN for the Cloud Router"
  type        = number
  default     = 64514
}

variable "delete_default_routes" {
  description = "Whether to delete the default routes when creating the VPC"
  type        = bool
  default     = false
}

variable "create_internet_gateway_route" {
  description = "Whether to create a route to the internet gateway"
  type        = bool
  default     = true
}

variable "peer_vpcs" {
  description = "Map of VPCs to peer with. Each entry needs a vpc_id."
  type = map(object({
    vpc_id = string
  }))
  default = {}
}


variable "prevent_destroy" {
  description = "Whether to prevent destruction of the VPC resource"
  type        = bool
  default     = false
}

variable "vpc_peerings" {
  description = "VPC peering configurations for connecting to external VPCs"
  type = map(object({
    project_id = string
    vpc_name = string
    export_custom_routes = bool
    import_custom_routes = bool
  }))
  default = {}
}


variable "firewall_rules" {
  description = "Custom firewall rules to create for the VPC"
  type = map(object({
    description = string
    source_ranges = list(string)
    target_ranges = list(string)
    allow = list(object({
      protocol = string
      ports = list(string)
    }))
  }))
  default = {}
}