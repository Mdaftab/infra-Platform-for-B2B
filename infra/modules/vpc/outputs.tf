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

output "network_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "The self-link of the VPC"
  value       = google_compute_network.vpc.self_link
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.id }
}

output "subnet_self_links" {
  description = "The self-links of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.self_link }
}

output "subnet_names" {
  description = "The names of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.name }
}

output "subnet_regions" {
  description = "The regions of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.region }
}

output "subnet_cidr_blocks" {
  description = "The CIDR blocks of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.ip_cidr_range }
}

output "subnet_secondary_ranges" {
  description = "The secondary ranges of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => {
    pods     = "${subnet.name}-pods"
    services = "${subnet.name}-services"
  } }
}

output "subnet_secondary_cidr_blocks" {
  description = "The secondary CIDR blocks of the subnets"
  value = {
    for name, subnet in google_compute_subnetwork.subnets : name => {
      pods     = [for sr in subnet.secondary_ip_range : sr.ip_cidr_range if sr.range_name == "${subnet.name}-pods"][0]
      services = [for sr in subnet.secondary_ip_range : sr.ip_cidr_range if sr.range_name == "${subnet.name}-services"][0]
    }
  }
}

output "router_id" {
  description = "The ID of the router"
  value       = var.create_nat_gateway ? google_compute_router.router[0].id : null
}

output "router_name" {
  description = "The name of the router"
  value       = var.create_nat_gateway ? google_compute_router.router[0].name : null
}

output "nat_ip" {
  description = "The IP address of the NAT gateway"
  value       = var.create_nat_gateway ? google_compute_router_nat.nat[0].nat_ip_allocate_option : null
}

output "is_shared_vpc_host" {
  description = "Whether this VPC is a shared VPC host project"
  value       = var.is_shared_vpc_host
}

output "service_project_ids" {
  description = "List of service project IDs attached to this shared VPC host project"
  value       = var.is_shared_vpc_host ? var.service_project_ids : []
}