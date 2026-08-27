variable "region" {
  type    = string
  default = "europe-west2"
}

variable "project_id" {
  type        = string
  description = "The project id in GCP"
}

/* variable "k8s_min_master_version" {
  type        = string
  description = "The minimum version of the master"
  default     = "1.33"
} */

variable "k8s_machine_type" {
  type        = string
  description = "The machine type to provision"
  default     = "custom-2-2560"
}

variable "k8s_autoscaling_max_node_count" {
  type        = number
  description = "The maximum number of Kubernetes nodes (per region)"
  default     = 5
}
