output "cluster_name" {
  description = "The name of the cluster"
  value       = google_container_cluster.gke_cluster.name
}

output "cluster_location" {
  description = "The location of the cluster"
  value       = google_container_cluster.gke_cluster.location
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.gke_cluster.endpoint
}

output "client_certificate" {
  description = "The public certificate of the cluster"
  value       = google_container_cluster.gke_cluster.master_auth.0.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "The private key of the cluster"
  value       = google_container_cluster.gke_cluster.master_auth.0.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The public CA certificate of the cluster"
  value       = google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes config to connect to the cluster"
  value       = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name    = google_container_cluster.gke_cluster.name
    endpoint        = google_container_cluster.gke_cluster.endpoint
    cluster_ca      = google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate
    client_cert     = google_container_cluster.gke_cluster.master_auth.0.client_certificate
    client_key      = google_container_cluster.gke_cluster.master_auth.0.client_key
  })
  sensitive   = true
}
