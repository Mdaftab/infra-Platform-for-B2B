resource "google_project_service" "gcp_apis" {
  for_each = toset([
    "container.googleapis.com",         # GKE API
    "compute.googleapis.com",           # Compute Engine API
    "iam.googleapis.com",               # IAM API
    "serviceusage.googleapis.com",      # Service Usage API
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
    "artifactregistry.googleapis.com",  # Artifact Registry API
    "servicenetworking.googleapis.com", # Service Networking API
    "monitoring.googleapis.com",        # Cloud Monitoring API
    "logging.googleapis.com",           # Cloud Logging API
    "stackdriver.googleapis.com",       # Stackdriver API
    "iamcredentials.googleapis.com",    # IAM Credentials API
  ])
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
