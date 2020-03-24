variable "gcp_project_id" {
  type        = string
  description = "The target GCP project for the cluster."
}

variable "gcp_service_account" {
  type        = string
  description = "The service account for authenticating with GCP APIs."
}

variable "gcp_region" {
  type        = string
  description = "The target GCP region for the cluster."
}

variable "gcp_extra_labels" {
  type = map(string)

  description = <<EOF
(optional) Extra GCP labels to be applied to created resources.
Example: `{ "key" = "value", "foo" = "bar" }`
EOF

  default = {}
}

variable "openshift_master_count" {
  type    = string
  default = 3
}

variable "openshift_worker_count" {
  type    = string
  default = 3
}

variable "openshift_infra_count" {
  type    = string
  default = 0
}

variable "gcp_bootstrap_enabled" {
  type        = bool
  description = "Setting this to false allows the bootstrap resources to be disabled."
  default     = true
}

variable "gcp_bootstrap_lb" {
  type        = bool
  description = "Setting this to false allows the bootstrap resources to be removed from the cluster load balancers."
  default     = true
}

variable "gcp_bootstrap_instance_type" {
  type        = string
  description = "Instance type for the bootstrap node. Example: `n1-standard-4`"
  default     = "n1-standard-4"
}

variable "gcp_master_instance_type" {
  type        = string
  description = "Instance type for the master node(s). Example: `n1-standard-4`"
  default     = "n1-standard-4"
}

variable "gcp_worker_instance_type" {
  type        = string
  description = "Instance type for the bootstrap node. Example: `n1-standard-4`"
  default     = "n1-standard-4"
}

variable "gcp_infra_instance_type" {
  type        = string
  description = "Instance type for the master node(s). Example: `n1-standard-4`"
  default     = "n1-standard-4"
}

variable "gcp_master_os_disk_size" {
  type    = string
  default = 512
}

variable "gcp_worker_os_disk_size" {
  type    = string
  default = 128
}

variable "gcp_infra_os_disk_size" {
  type    = string
  default = 128
}



variable "gcp_image_uri" {
  type        = string
  description = "Image for all nodes."
  default     = "https://storage.googleapis.com/rhcos/rhcos/42.80.20191002.0.tar.gz"
}

variable "gcp_public_dns_zone_name" {
  type        = string
  default     = null
  description = "The name of the public DNS zone to use for this cluster"
}

variable "gcp_publish_strategy" {
  type        = string
  description = "The cluster publishing strategy, either Internal or External"
  default     = "External"
}
##############################################################3

variable "cluster_name" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "machine_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "openshift_cluster_network_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "openshift_cluster_network_host_prefix" {
  type    = string
  default = 23
}

variable "openshift_service_network_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "openshift_pull_secret" {
  type    = string
  default = "pull-secret"
}

variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "airgapped" {
  type = map(string)
  default = {
    enabled    = false
    repository = ""
  }
}
