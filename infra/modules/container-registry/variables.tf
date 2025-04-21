variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "location" {
  description = "Location for the Container Registry (multi-region: us, eu, asia or region: us-central1, etc.)"
  type        = string
  default     = "us"
  
  validation {
    condition     = contains(["us", "eu", "asia", "us-central1", "us-east1", "us-west1", "us-west2", "us-east4", "europe-west1", "europe-west2", "europe-west3", "europe-west4", "asia-east1", "asia-northeast1", "asia-southeast1"], var.location)
    error_message = "Must be a valid GCR location: multi-region (us, eu, asia) or region specific."
  }
}

variable "gke_node_sa_email" {
  description = "Email address of the GKE node service account"
  type        = string
}

variable "github_actions_sa_email" {
  description = "Email address of the GitHub Actions service account"
  type        = string
}