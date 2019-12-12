
variable "cluster_id" {
  type = string
}

variable "bootstrap_instances" {
  type        = list(string)
  description = "The bootstrap instance."
}

variable "bootstrap_instance_groups" {
  type        = list(string)
  description = "The bootstrap instance groups."
}

variable "bootstrap_lb" {
  type        = bool
  description = "If the bootstrap instance should be in the load balancers."
  default     = true
}

variable "master_instances" {
  type        = list(string)
  description = "The master instances."
}

variable "master_instance_groups" {
  type        = list(string)
  description = "The master instance groups."
}

variable "network_cidr" {
  type = string
}

variable "public_endpoints" {
  type        = bool
  description = "If the bootstrap instance should have externally accessible resources."
}
