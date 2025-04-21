output "network_id" {
  description = "The ID of the VPC"
  value       = module.vpc.network_id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = module.vpc.subnet_ids
}

output "service_accounts" {
  description = "Service account emails"
  value = {
    crossplane_sa      = module.iam.crossplane_sa_email
    github_actions_sa  = module.iam.github_actions_sa_email
    gke_node_sa        = module.iam.gke_node_sa_email
    external_secrets_sa = module.iam.external_secrets_sa_email
  }
}

output "management_cluster_name" {
  description = "The name of the management GKE cluster"
  value       = module.gke.cluster_name
}

output "management_cluster_endpoint" {
  description = "The endpoint of the management GKE cluster"
  value       = module.gke.cluster_endpoint
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "crossplane_sa_key_path" {
  description = "Path to the Crossplane service account key"
  value       = local_file.crossplane_sa_key.filename
}

output "container_registry_url" {
  description = "URL of the Google Container Registry"
  value       = module.gcr.registry_url
}
