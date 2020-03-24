variable "cluster_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "master_count" {
  type = string
}

variable "node_count" {
  type = string
}

variable "infra_count" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_network_cidr" {
  type = string
}

variable "cluster_network_host_prefix" {
  type = string
}

variable "machine_cidr" {
  type = string
}

variable "service_network_cidr" {
  type = string
}

variable "openshift_pull_secret" {
  type = string
}

variable "public_ssh_key" {
  type = string
}

variable "openshift_installer_url" {
  type    = string
  default = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
}

variable "openshift_version" {
  type    = string
  default = "latest"
}


variable "gcp_region" {
  type = string
}

variable "master_vm_type" {
  type = string
}

variable "infra_vm_type" {
  type = string
}

variable "worker_vm_type" {
  type = string
}

variable "worker_os_disk_size" {
  type    = string
  default = 128
}

variable "infra_os_disk_size" {
  type    = string
  default = 128
}

variable "master_os_disk_size" {
  type    = string
  default = 1024
}

variable "zones" {
  type = list(string)
}

variable "public_dns_zone_name" {
  type = string
}

variable "serviceaccount_encoded" {
  type = string
}

variable "airgapped" {
  type = map(string)
  default = {
    enabled    = false
    repository = ""
  }
}
