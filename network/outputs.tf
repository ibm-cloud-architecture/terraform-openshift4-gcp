output "cluster_ip" {
  value = google_compute_forwarding_rule.api_internal.ip_address
}

output "cluster_public_ip" {
  value = var.public_endpoints ? google_compute_forwarding_rule.api[0].ip_address : null
}

output "network" {
  value = local.cluster_network
}

output "worker_subnet" {
  value = google_compute_subnetwork.worker_subnet.self_link
}

output "master_subnet" {
  value = local.master_subnet
}

output "zones" {
  value = local.zones
}
