output "registry_id" {
  description = "The ID of the GCR registry bucket"
  value       = google_container_registry.registry.id
}

output "registry_url" {
  description = "The URL of the GCR registry"
  value       = "gcr.io/${var.project_id}"
}

output "registry_location" {
  description = "The location of the GCR registry"
  value       = var.location
}