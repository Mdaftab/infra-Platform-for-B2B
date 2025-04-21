/*
  Google Container Registry module
  Creates a GCR repository and sets up IAM permissions
*/

# Enable GCR for the project (this actually uses a GCS bucket behind the scenes)
resource "google_container_registry" "registry" {
  project  = var.project_id
  location = var.location
}

# Grant the GKE service account access to pull images
resource "google_storage_bucket_iam_member" "gke_node_sa_gcr_access" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.gke_node_sa_email}"
}

# Grant the GitHub Actions service account access to push/pull images
resource "google_storage_bucket_iam_member" "github_actions_sa_gcr_access" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.github_actions_sa_email}"
}

# Create a lifecycle policy to clean up untagged images older than 14 days
resource "google_storage_bucket_object" "lifecycle_policy" {
  name    = "gcr-lifecycle-policy.json"
  bucket  = google_container_registry.registry.id
  content = jsonencode({
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 14,
          "tagState": "untagged"
        }
      }
    ]
  })
}