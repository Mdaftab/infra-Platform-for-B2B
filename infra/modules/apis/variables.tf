variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "apis_to_enable" {
  description = "List of APIs to enable for this specific project/environment"
  type        = list(string)
  default = [
    "container.googleapis.com",         # GKE API
    "compute.googleapis.com",           # Compute Engine API
    "iam.googleapis.com",               # IAM API
    "serviceusage.googleapis.com",      # Service Usage API
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
    "artifactregistry.googleapis.com",  # Artifact Registry API
    "containerregistry.googleapis.com", # Container Registry API
    "secretmanager.googleapis.com",     # Secret Manager API
    "servicenetworking.googleapis.com", # Service Networking API
    "monitoring.googleapis.com",        # Cloud Monitoring API
    "logging.googleapis.com",           # Cloud Logging API
    "stackdriver.googleapis.com",       # Stackdriver API
    "iamcredentials.googleapis.com",    # IAM Credentials API
    "dns.googleapis.com",               # Cloud DNS API
    "cloudbuild.googleapis.com",        # Cloud Build API
  ]
}