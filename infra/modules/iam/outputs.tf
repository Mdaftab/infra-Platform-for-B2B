output "crossplane_sa_email" {
  description = "Email of the Crossplane service account"
  value       = google_service_account.crossplane_sa.email
}

output "crossplane_sa_key" {
  description = "Service account key for Crossplane"
  value       = base64decode(google_service_account_key.crossplane_sa_key.private_key)
  sensitive   = true
}

output "github_actions_sa_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions_sa.email
}

output "github_actions_sa_key" {
  description = "Service account key for GitHub Actions"
  value       = base64decode(google_service_account_key.github_actions_sa_key.private_key)
  sensitive   = true
}

output "gke_node_sa_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_node_sa.email
}

output "external_secrets_sa_email" {
  description = "Email of the External Secrets service account"
  value       = google_service_account.external_secrets_sa.email
}
