# Canonical internal state definitions for this module.
# read only: only locals and data source definitions allowed. No resources or module blocks in this file

data "google_compute_zones" "available" {}

locals {
  master_subnet_cidr = cidrsubnet(var.network_cidr, 3, 0) #master subnet is a smaller subnet within the vnet. i.e from /21 to /24
  worker_subnet_cidr = cidrsubnet(var.network_cidr, 3, 1) #node subnet is a smaller subnet within the vnet. i.e from /21 to /24
  cluster_network    = google_compute_network.cluster_network.self_link
  master_subnet      = google_compute_subnetwork.master_subnet.self_link
  zones              = data.google_compute_zones.available.names
}
