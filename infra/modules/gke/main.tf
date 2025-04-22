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

locals {
  location = var.regional ? var.region : "${var.region}-${var.zone}"
  # Use a reasonable default node pool name if none is provided
  node_pool_name = "${var.cluster_name}-node-pool"
  # Generate maintenance window if provided
  maintenance_window = var.maintenance_recurrence != null ? {
    recurring_window = {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  } : {
    daily_maintenance_window = {
      start_time = var.maintenance_start_time
    }
  }
}

resource "google_container_cluster" "gke_cluster" {
  name        = var.cluster_name
  description = var.description
  location    = local.location
  project     = var.project_id

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Networking
  network    = var.network_name
  subnetwork = var.subnet_name

  # IP allocation policy (required for GKE private clusters)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable Kubernetes Network Policy if configured
  dynamic "network_policy" {
    for_each = var.enable_network_policy ? [1] : []
    content {
      enabled  = true
      provider = "CALICO"
    }
  }

  # Enable Dataplane V2
  datapath_provider = var.enable_dataplane_v2 ? "ADVANCED_DATAPATH" : "DATAPATH_PROVIDER_UNSPECIFIED"

  # Cluster maintenance window
  dynamic "maintenance_policy" {
    for_each = var.maintenance_start_time != null ? [1] : []
    content {
      dynamic "daily_maintenance_window" {
        for_each = var.maintenance_recurrence == null ? [1] : []
        content {
          start_time = var.maintenance_start_time
        }
      }
      
      dynamic "recurring_window" {
        for_each = var.maintenance_recurrence != null ? [1] : []
        content {
          start_time = var.maintenance_start_time
          end_time   = var.maintenance_end_time
          recurrence = var.maintenance_recurrence
        }
      }
    }
  }

  # Cluster add-ons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = !var.enable_network_policy
    }
    gcp_filestore_csi_driver_config {
      enabled = var.enable_filestore_csi
    }
    gce_persistent_disk_csi_driver_config {
      enabled = var.enable_gce_persistent_disk_csi
    }
    dns_cache_config {
      enabled = var.enable_dns_cache
    }
    istio_config {
      disabled = !var.enable_istio
      auth     = var.enable_istio ? "AUTH_MUTUAL_TLS" : null
    }
    config_connector_config {
      enabled = var.enable_config_connector
    }
  }

  # Binary Authorization if enabled
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  # Vertical Pod Autoscaling if enabled
  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  # Intranode Visibility if enabled
  dynamic "intranode_visibility_config" {
    for_each = var.enable_intranode_visibility ? [1] : []
    content {
      enable_intranode_visibility = true
    }
  }

  # Cluster Autoscaling if enabled
  dynamic "cluster_autoscaling" {
    for_each = var.enable_cluster_autoscaling ? [1] : []
    content {
      enabled = true
      
      auto_provisioning_defaults {
        service_account = var.service_account
        oauth_scopes    = var.oauth_scopes
      }
      
      resource_limits {
        resource_type = "cpu"
        minimum       = var.min_cpu
        maximum       = var.max_cpu
      }
      
      resource_limits {
        resource_type = "memory"
        minimum       = var.min_memory
        maximum       = var.max_memory
      }
    }
  }

  # Enable Shielded Nodes
  enable_shielded_nodes = var.enable_shielded_nodes

  # Master Authorized Networks if configured
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Resource Labels
  resource_labels = var.cluster_labels

  # Default Timeouts
  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }
  
  # Prevent pod IP and node IP address overlaps with service CIDR range
  dynamic "ip_config" {
    for_each = var.stack_type != null ? [1] : []
    content {
      stack_type = var.stack_type
    }
  }
  
  # Node Security configuration
  node_config {
    # Use custom service account for nodes
    service_account = var.service_account
    
    # Configure default node labels
    labels = var.default_node_labels
    tags   = var.default_node_tags
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = var.node_pool_name != null ? var.node_pool_name : local.node_pool_name
  location   = local.location
  cluster    = google_container_cluster.gke_cluster.name
  project    = var.project_id
  node_count = var.enable_autoscaling ? null : var.node_count

  # Configure auto-scaling if enabled
  dynamic "autoscaling" {
    for_each = var.enable_autoscaling ? [1] : []
    content {
      min_node_count = var.min_nodes
      max_node_count = var.max_nodes
      location_policy = var.enable_location_based_autoscaling ? "BALANCED" : null
    }
  }

  # Configure auto-repair and auto-upgrade
  management {
    auto_repair  = var.auto_repair
    auto_upgrade = var.auto_upgrade
  }

  # Node configuration
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    preemptible  = var.preemptible
    spot         = var.spot
    
    # OAuth scopes
    oauth_scopes = var.oauth_scopes

    # Use custom service account for nodes
    service_account = var.service_account

    # Use GKE Sandbox for enhanced node security
    dynamic "gvnic" {
      for_each = var.enable_gvnic ? [1] : []
      content {
        enabled = true
      }
    }

    # Labels and tags
    labels = var.node_labels
    tags   = var.node_tags
    
    # Taints
    dynamic "taint" {
      for_each = var.node_taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Enable workload identity on node pool
    workload_metadata_config {
      mode = var.node_metadata
    }

    # Sandbox configuration
    dynamic "sandbox_config" {
      for_each = var.enable_sandbox_config ? [1] : []
      content {
        sandbox_type = "gvisor"
      }
    }

    # Shielded instance config
    dynamic "shielded_instance_config" {
      for_each = var.enable_shielded_nodes ? [1] : []
      content {
        enable_secure_boot          = var.enable_secure_boot
        enable_integrity_monitoring = var.enable_integrity_monitoring
      }
    }
    
    # Boot disk KMS key if configured
    dynamic "boot_disk_kms_key" {
      for_each = var.disk_kms_key != null ? [var.disk_kms_key] : []
      content {
        kms_key_self_link = boot_disk_kms_key.value
      }
    }
  }

  # Default Timeouts
  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }
  
  # Upgrade settings
  dynamic "upgrade_settings" {
    for_each = var.max_surge > 0 || var.max_unavailable > 0 ? [1] : []
    content {
      max_surge       = var.max_surge
      max_unavailable = var.max_unavailable
      strategy        = var.upgrade_strategy
    }
  }
}