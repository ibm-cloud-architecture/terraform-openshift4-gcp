provider "google" {
  credentials = file(var.gcp_service_account)
  project     = var.gcp_project_id
  region      = var.gcp_region
}

resource "random_string" "cluster_id" {
  length  = 5
  special = false
  upper   = false
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "write_private_key" {
  content         = tls_private_key.installkey.private_key_pem
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = tls_private_key.installkey.public_key_openssh
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa.pub"
  file_permission = 0600
}

locals {
  labels     = var.gcp_extra_labels
  cluster_id = "${var.cluster_name}-${random_string.cluster_id.result}"

  master_subnet_cidr = cidrsubnet(var.machine_cidr, 3, 0) #master subnet is a smaller subnet within the vnet. i.e from /21 to /24
  worker_subnet_cidr = cidrsubnet(var.machine_cidr, 3, 1) #worker subnet is a smaller subnet within the vnet. i.e from /21 to /24
  tags = merge(
    {
      "kubernetes.io_cluster.${local.cluster_id}" = "owned"
    },
    var.gcp_extra_labels,
  )
  public_endpoints = var.airgapped["enabled"] ? false : true
}

module "network" {
  source = "./network"

  cluster_id                = local.cluster_id
  network_cidr              = var.machine_cidr
  bootstrap_instances       = module.bootstrap.bootstrap_instances
  bootstrap_instance_groups = module.bootstrap.bootstrap_instance_groups
  master_instances          = module.master.master_instances
  master_instance_groups    = module.master.master_instance_groups

  public_endpoints = local.public_endpoints
}

module "ignition" {
  source = "./ignition"

  master_count                = var.openshift_master_count
  node_count                  = var.openshift_worker_count
  infra_count                 = var.openshift_infra_count
  cluster_id                  = local.cluster_id
  project_id                  = var.gcp_project_id
  base_domain                 = var.base_domain
  public_dns_zone_name        = var.gcp_public_dns_zone_name
  cluster_name                = var.cluster_name
  cluster_network_cidr        = var.openshift_cluster_network_cidr
  cluster_network_host_prefix = var.openshift_cluster_network_host_prefix
  machine_cidr                = var.machine_cidr
  service_network_cidr        = var.openshift_service_network_cidr
  gcp_region                  = var.gcp_region
  openshift_pull_secret       = var.openshift_pull_secret
  public_ssh_key              = chomp(tls_private_key.installkey.public_key_openssh)
  master_vm_type              = var.gcp_master_instance_type
  worker_vm_type              = var.gcp_worker_instance_type
  infra_vm_type               = var.gcp_infra_instance_type
  master_os_disk_size         = var.gcp_master_os_disk_size
  worker_os_disk_size         = var.gcp_worker_os_disk_size
  infra_os_disk_size          = var.gcp_infra_os_disk_size
  zones                       = module.network.zones
  airgapped                   = var.airgapped
  serviceaccount_encoded      = chomp(base64encode(file(var.gcp_service_account)))
  openshift_version           = var.openshift_version
}

module "bootstrap" {
  source = "./bootstrap"

  bootstrap_enabled = var.gcp_bootstrap_enabled

  image            = google_compute_image.cluster.self_link
  machine_type     = var.gcp_bootstrap_instance_type
  cluster_id       = local.cluster_id
  ignition         = module.ignition.bootstrap_ignition
  network          = module.network.network
  network_cidr     = var.machine_cidr
  public_endpoints = local.public_endpoints
  subnet           = module.network.master_subnet
  zone             = module.network.zones[0]
  root_volume_size = var.gcp_master_os_disk_size

  labels = local.labels
}

module "master" {
  source = "./master"

  image          = google_compute_image.cluster.self_link
  instance_count = var.openshift_master_count
  machine_type   = var.gcp_master_instance_type
  cluster_id     = local.cluster_id
  ignition       = module.ignition.master_ignition
  subnet         = module.network.master_subnet
  zones          = distinct(module.network.zones)

  root_volume_size = var.gcp_master_os_disk_size

  labels = local.labels
}

module "iam" {
  source = "./iam"

  cluster_id = local.cluster_id
}


module "dns" {
  source = "./dns"

  cluster_id           = local.cluster_id
  public_dns_zone_name = var.gcp_public_dns_zone_name
  network              = module.network.network
  etcd_ip_addresses    = flatten(module.master.ip_addresses)
  etcd_count           = var.openshift_master_count
  cluster_domain       = "${var.cluster_name}.${var.base_domain}"
  api_external_lb_ip   = module.network.cluster_public_ip
  api_internal_lb_ip   = module.network.cluster_ip
  public_endpoints     = local.public_endpoints
}

resource "google_compute_image" "cluster" {
  name = "${local.cluster_id}-rhcos-image"

  raw_disk {
    source = var.gcp_image_uri
  }
}
