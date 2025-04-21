# Crossplane management service account
resource "google_service_account" "crossplane_sa" {
  account_id   = "${var.environment}-crossplane-sa"
  display_name = "Crossplane Service Account for ${var.environment}"
  project      = var.project_id
  description  = "Service account for Crossplane to manage GCP resources"
}

# Grant permissions to Crossplane service account
resource "google_project_iam_member" "crossplane_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/servicenetworking.networksAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.crossplane_sa.email}"
}

# Create service account key for Crossplane
resource "google_service_account_key" "crossplane_sa_key" {
  service_account_id = google_service_account.crossplane_sa.name
}

# GitHub Actions service account
resource "google_service_account" "github_actions_sa" {
  account_id   = "${var.environment}-github-actions-sa"
  display_name = "GitHub Actions Service Account for ${var.environment}"
  project      = var.project_id
  description  = "Service account for GitHub Actions to deploy infrastructure"
}

# Grant permissions to GitHub Actions service account
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/iam.serviceAccountTokenCreator", # For workload identity federation
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# Create service account key for GitHub Actions
resource "google_service_account_key" "github_actions_sa_key" {
  service_account_id = google_service_account.github_actions_sa.name
}

# GKE node service account
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "GKE Node Service Account for ${var.environment}"
  project      = var.project_id
  description  = "Service account for GKE nodes"
}

# Grant minimum required permissions to GKE node service account
resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}
