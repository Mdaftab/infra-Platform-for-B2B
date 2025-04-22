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
  description = "The project ID to host the cluster in"
  type        = string
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "description" {
  description = "The description of the cluster"
  type        = string
  default     = "GKE Cluster"
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
}

variable "zone" {
  description = "The zone to host the cluster in (when regional is false)"
  type        = string
  default     = "a"
}

variable "regional" {
  description = "Whether the cluster should be regional or zonal"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "cluster_secondary_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "The name of the secondary range for services"
  type        = string
}

variable "enable_private_endpoint" {
  description = "When true, the cluster's private endpoint is used as the cluster endpoint"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "stack_type" {
  description = "IP stack type that could be 'IPV4' or 'IPV4_IPV6'"
  type        = string
  default     = null
}

variable "release_channel" {
  description = "The release channel of the cluster (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
  
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE."
  }
}

variable "machine_type" {
  description = "The machine type for the nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "The disk size in GB for each node"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "The disk type for the nodes"
  type        = string
  default     = "pd-standard"
}

variable "disk_kms_key" {
  description = "The Cloud KMS key self link to use for disk encryption"
  type        = string
  default     = null
}

variable "preemptible" {
  description = "Whether the nodes should be preemptible"
  type        = bool
  default     = false
}

variable "spot" {
  description = "Whether the nodes should use spot VMs"
  type        = bool
  default     = false
}

variable "service_account" {
  description = "The service account email to use for the nodes"
  type        = string
}

variable "node_count" {
  description = "The number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "enable_autoscaling" {
  description = "Whether to enable autoscaling for the node pool"
  type        = bool
  default     = true
}

variable "min_nodes" {
  description = "The minimum number of nodes in the node pool when autoscaling is enabled"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "The maximum number of nodes in the node pool when autoscaling is enabled"
  type        = number
  default     = 5
}

variable "enable_location_based_autoscaling" {
  description = "Whether to enable location-based node autoscaling"
  type        = bool
  default     = false
}

variable "node_labels" {
  description = "The labels to apply to the nodes"
  type        = map(string)
  default     = {}
}

variable "default_node_labels" {
  description = "The default labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "The network tags to apply to the nodes"
  type        = list(string)
  default     = []
}

variable "default_node_tags" {
  description = "The default network tags to apply to nodes"
  type        = list(string)
  default     = []
}

variable "node_taints" {
  description = "The Kubernetes taints to apply to cluster nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "node_metadata" {
  description = "How to expose the node metadata to the workload running on the node (GKE_METADATA, GCE_METADATA, UNSPECIFIED)"
  type        = string
  default     = "GKE_METADATA"
}

variable "node_pool_name" {
  description = "The name of the node pool if not using the default name"
  type        = string
  default     = null
}

variable "auto_repair" {
  description = "Whether to enable auto-repair for the node pool"
  type        = bool
  default     = true
}

variable "auto_upgrade" {
  description = "Whether to enable auto-upgrade for the node pool"
  type        = bool
  default     = true
}

variable "max_surge" {
  description = "The maximum number of nodes that can be created beyond the desired number of nodes during an upgrade"
  type        = number
  default     = 1
}

variable "max_unavailable" {
  description = "The maximum number of nodes that can be simultaneously unavailable during an upgrade"
  type        = number
  default     = 0
}

variable "upgrade_strategy" {
  description = "The strategy to use for node pool upgrades (SURGE or BLUE_GREEN)"
  type        = string
  default     = "SURGE"
}

variable "maintenance_start_time" {
  description = "Start time of the daily or recurring maintenance window (RFC3339 format - 'HH:MM')"
  type        = string
  default     = "03:00"
}

variable "maintenance_end_time" {
  description = "End time of the recurring maintenance window (RFC3339 format - 'HH:MM')"
  type        = string
  default     = null
}

variable "maintenance_recurrence" {
  description = "RFC 5545 RRULE for when maintenance windows occur (e.g. 'FREQ=WEEKLY;BYDAY=SA,SU')"
  type        = string
  default     = null
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for the cluster"
  type        = bool
  default     = false
}

variable "enable_network_policy" {
  description = "Enable network policy enforcement for the cluster"
  type        = bool
  default     = true
}

variable "enable_dataplane_v2" {
  description = "Enable GKE Dataplane V2 (GKE Advanced Datapath)"
  type        = bool
  default     = true
}

variable "enable_filestore_csi" {
  description = "Enable Filestore CSI driver for the cluster"
  type        = bool
  default     = true
}

variable "enable_gce_persistent_disk_csi" {
  description = "Enable GCE Persistent Disk CSI driver for the cluster"
  type        = bool
  default     = true
}

variable "enable_dns_cache" {
  description = "Enable NodeLocal DNSCache for the cluster"
  type        = bool
  default     = false
}

variable "enable_istio" {
  description = "Enable Istio for the cluster"
  type        = bool
  default     = false
}

variable "enable_config_connector" {
  description = "Enable ConfigConnector for the cluster"
  type        = bool
  default     = false
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable vertical pod autoscaling"
  type        = bool
  default     = true
}

variable "enable_intranode_visibility" {
  description = "Enable intra-node visibility for the cluster"
  type        = bool
  default     = false
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded Nodes features on all nodes in this cluster"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot for Shielded Nodes"
  type        = bool
  default     = true
}

variable "enable_integrity_monitoring" {
  description = "Enable Integrity Monitoring for Shielded Nodes"
  type        = bool
  default     = true
}

variable "enable_gvnic" {
  description = "Enable Google Virtual NIC (gVNIC) on nodes"
  type        = bool
  default     = true
}

variable "enable_sandbox_config" {
  description = "Enable GKE Sandbox (gVisor) on nodes"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaling" {
  description = "Enable cluster autoscaling"
  type        = bool
  default     = false
}

variable "min_cpu" {
  description = "Minimum CPU cores for cluster autoscaling"
  type        = number
  default     = 1
}

variable "max_cpu" {
  description = "Maximum CPU cores for cluster autoscaling"
  type        = number
  default     = 10
}

variable "min_memory" {
  description = "Minimum memory (GB) for cluster autoscaling"
  type        = number
  default     = 2
}

variable "max_memory" {
  description = "Maximum memory (GB) for cluster autoscaling"
  type        = number
  default     = 32
}

variable "master_authorized_networks" {
  description = "List of master authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "oauth_scopes" {
  description = "The OAuth scopes to be attached to nodes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/devstorage.read_only",
  ]
}

variable "cluster_labels" {
  description = "The resource labels to apply to the GKE cluster"
  type        = map(string)
  default     = {}
}

variable "create_timeout" {
  description = "The timeout for creating a cluster"
  type        = string
  default     = "45m"
}

variable "update_timeout" {
  description = "The timeout for updating a cluster"
  type        = string
  default     = "45m"
}

variable "delete_timeout" {
  description = "The timeout for deleting a cluster"
  type        = string
  default     = "45m"
}