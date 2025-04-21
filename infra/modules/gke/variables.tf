variable "project_id" {
  description = "The project ID to host the cluster in"
  type        = string
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
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

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "release_channel" {
  description = "The release channel of the cluster (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
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

variable "preemptible" {
  description = "Whether the nodes should be preemptible"
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

variable "node_labels" {
  description = "The labels to apply to the nodes"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "The network tags to apply to the nodes"
  type        = list(string)
  default     = []
}
