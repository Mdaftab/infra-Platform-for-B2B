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

# VPC Network
resource "google_compute_network" "vpc" {
  name                            = var.network_name
  auto_create_subnetworks         = false
  project                         = var.project_id
  description                     = "VPC Network for ${var.environment} environment"
  delete_default_routes_on_create = var.delete_default_routes
  routing_mode                    = "GLOBAL"
  
  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

# Subnets
resource "google_compute_subnetwork" "subnets" {
  for_each                 = { for subnet in var.subnets : subnet.name => subnet }
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  project                  = var.project_id
  private_ip_google_access = each.value.private
  
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges != null ? [1] : []
    content {
      range_name    = "${each.value.name}-pods"
      ip_cidr_range = each.value.secondary_ranges.pods
    }
  }
  
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges != null ? [1] : []
    content {
      range_name    = "${each.value.name}-services"
      ip_cidr_range = each.value.secondary_ranges.services
    }
  }

  # Enable flow logs if specified
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Cloud NAT and Router
resource "google_compute_router" "router" {
  count   = var.create_nat_gateway ? 1 : 0
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id

  bgp {
    asn = var.router_asn
  }
}

resource "google_compute_router_nat" "nat" {
  count                              = var.create_nat_gateway ? 1 : 0
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router[0].name
  region                             = google_compute_router.router[0].region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rules
resource "google_compute_firewall" "internal_allow" {
  name        = "${var.network_name}-internal-allow"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  description = "Allow internal communication between resources in the VPC"
  priority    = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = distinct(concat(
    [for subnet in var.subnets : subnet.ip_cidr_range],
    [for subnet in var.subnets : lookup(subnet.secondary_ranges, "pods", "")]
  ))

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Create default route to internet if enabled
resource "google_compute_route" "default_internet_gateway" {
  count            = var.delete_default_routes && var.create_internet_gateway_route ? 1 : 0
  name             = "${var.network_name}-default-internet-gateway"
  project          = var.project_id
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# VPC Peering for existing VPCs
resource "google_compute_network_peering" "peering" {
  for_each                  = var.peer_vpcs
  name                      = "peering-${var.network_name}-to-${each.key}"
  network                   = google_compute_network.vpc.id
  peer_network              = each.value.vpc_id
  export_custom_routes      = true
  import_custom_routes      = true
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

# VPC Peering for VPCs by name (not yet created)
data "google_compute_network" "peer_networks" {
  for_each = var.vpc_peerings
  name     = each.value.vpc_name
  project  = each.value.project_id
}

resource "google_compute_network_peering" "vpc_peerings" {
  for_each                  = var.vpc_peerings
  name                      = "peering-${var.network_name}-to-${each.key}"
  network                   = google_compute_network.vpc.id
  peer_network              = data.google_compute_network.peer_networks[each.key].id
  export_custom_routes      = each.value.export_custom_routes
  import_custom_routes      = each.value.import_custom_routes
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
  
  depends_on = [
    data.google_compute_network.peer_networks
  ]
}

# Shared VPC configuration if this is the host project
resource "google_compute_shared_vpc_host_project" "host" {
  count      = var.is_shared_vpc_host ? 1 : 0
  project    = var.project_id
}

# Service project attachments if this is a shared VPC
resource "google_compute_shared_vpc_service_project" "service_projects" {
  for_each        = var.is_shared_vpc_host ? toset(var.service_project_ids) : []
  host_project    = var.project_id
  service_project = each.value
  
  depends_on = [
    google_compute_shared_vpc_host_project.host
  ]
}

# IAM permissions for service accounts to use shared VPC
resource "google_project_iam_member" "shared_vpc_users" {
  for_each = var.is_shared_vpc_host ? {
    for pair in var.shared_vpc_users : "${pair.service_account}-${pair.role}" => pair
  } : {}
  
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.service_account}"
}

# Subnet-level IAM bindings for more granular access control
resource "google_compute_subnetwork_iam_binding" "subnet_iam_bindings" {
  for_each = var.is_shared_vpc_host ? {
    for binding_pair in flatten([
      for subnet_name, bindings in var.subnet_iam_bindings : [
        for binding in bindings : {
          subnet_name = subnet_name
          role        = binding.role
          members     = binding.members
        }
      ]
    ]) : "${binding_pair.subnet_name}-${binding_pair.role}" => binding_pair
  } : {}
  
  project     = var.project_id
  region      = var.region
  subnetwork  = google_compute_subnetwork.subnets[each.value.subnet_name].name
  role        = each.value.role
  members     = each.value.members
  
  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_compute_subnetwork.subnets
  ]
}

# Custom firewall rules for environment isolation and connectivity
resource "google_compute_firewall" "custom_rules" {
  for_each    = var.firewall_rules
  
  name        = "${var.network_name}-${each.key}"
  network     = google_compute_network.vpc.self_link
  project     = var.project_id
  description = each.value.description
  priority    = 1000
  
  source_ranges = each.value.source_ranges
  target_tags   = [] # Can be extended with target tags if needed
  
  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }
  
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}