output "network_id" {
  description = "The ID of the VPC"
  value       = module.vpc.network_id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = module.vpc.subnet_ids
}

output "crossplane_sa_email" {
  description = "Email of the Crossplane service account"
  value       = module.iam.crossplane_sa_email
}

output "github_actions_sa_email" {
  description = "Email of the GitHub Actions service account"
  value       = module.iam.github_actions_sa_email
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
