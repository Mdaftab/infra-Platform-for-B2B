output "network_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.id }
}

output "subnet_names" {
  description = "The names of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => subnet.name }
}

output "subnet_secondary_ranges" {
  description = "The secondary ranges of the subnets"
  value       = { for name, subnet in google_compute_subnetwork.subnets : name => {
    pods     = "${subnet.name}-pods"
    services = "${subnet.name}-services"
  } }
}
