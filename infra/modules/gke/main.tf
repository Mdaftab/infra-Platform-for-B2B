resource "google_container_cluster" "gke_cluster" {
  name     = var.cluster_name
  location = var.regional ? var.region : "${var.region}-a"
  project  = var.project_id

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
    enable_private_endpoint = false
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

  # Enable Kubernetes Network Policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Enable Dataplane V2
  datapath_provider = "ADVANCED_DATAPATH"

  # Cluster maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
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
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = true
  }

  # Enable Shielded Nodes
  enable_shielded_nodes = true

  # Default Timeouts
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.regional ? var.region : "${var.region}-a"
  cluster    = google_container_cluster.gke_cluster.name
  project    = var.project_id
  node_count = var.node_count

  # Configure auto-scaling if enabled
  dynamic "autoscaling" {
    for_each = var.enable_autoscaling ? [1] : []
    content {
      min_node_count = var.min_nodes
      max_node_count = var.max_nodes
    }
  }

  # Configure auto-repair and auto-upgrade
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    preemptible  = var.preemptible
    
    # Minimum required scopes for GKE
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    # Use custom service account for nodes
    service_account = var.service_account

    # Use GKE Sandbox for enhanced node security
    gvnic {
      enabled = true
    }

    # Labels and tags
    labels = var.node_labels
    tags   = var.node_tags

    # Enable workload identity on node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable Secure Boot
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # Default Timeouts
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}
