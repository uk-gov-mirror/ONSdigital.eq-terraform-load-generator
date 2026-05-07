terraform {
  backend "gcs" {
    bucket = "eq-terraform-load-generator-tfstate"
  }
  required_version = ">= 1.9.6"
}

provider "google" {
  region = var.region
}

output "region" {
  value = var.region
}

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "logging" {
  project = var.project_id
  service = "logging.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_compute_network" "k8s" {
  #checkov:skip=CKV2_GCP_18:Ensure GCP network defines a firewall and does not use the default firewall
  depends_on              = [google_project_service.compute]
  name                    = "k8s"
  auto_create_subnetworks = "true"
  project                 = var.project_id
}

// GKE

# service account for compute engine instances
resource "google_service_account" "compute" {
  account_id   = "compute"
  display_name = "Compute Engine service account"
  project      = var.project_id
}

resource "google_project_iam_member" "compute" {
  #checkov:skip=CKV_GCP_117:Ensure basic roles are not used at project level.
  #checkov:skip=CKV_GCP_49:Ensure roles do not impersonate or manage Service Accounts used at project level
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.compute.email}"
}

resource "google_container_cluster" "runner-benchmark" {
  #checkov:skip=CKV_GCP_20:Ensure master authorized networks is set to enabled in GKE clusters
  #checkov:skip=CKV_GCP_61:Enable VPC Flow Logs and Intranode Visibility
  #checkov:skip=CKV_GCP_25:Ensure Kubernetes Engine clusters have private nodes
  #checkov:skip=CKV_GCP_23:Ensure Kubernetes Cluster is created with Alias IP ranges enabled
  #checkov:skip=CKV_GCP_12:Ensure Network Policy is enabled on Kubernetes Engine Clusters
  #checkov:skip=CKV_GCP_64:Ensure clusters are created with Private Nodes
  #checkov:skip=CKV_GCP_70:Ensure the GKE Release Channel is set
  #checkov:skip=CKV_GCP_24:Ensure PodSecurityPolicy controller is enabled on the Kubernetes Engine Clusters
  #checkov:skip=CKV_GCP_69:Ensure the GKE Metadata Server is Enabled
  #checkov:skip=CKV_GCP_117:Ensure basic roles are not used at project level.
  #checkov:skip=CKV_GCP_66:Ensure use of Binary Authorization
  #checkov:skip=CKV_GCP_21:Ensure Kubernetes Clusters are configured with Labels
  #chekov:skip=CKV_GCP_20:Ensure master authorized networks is set to enabled in GKE clusters
  #checkov:skip=CKV_GCP_65:Manage Kubernetes RBAC users with Google Groups for GKE
  depends_on               = [google_project_service.container]
  name                     = "runner-benchmark"
  description              = "Kubernetes Cluster - Dev Benchmark environment"
  location                 = var.region
  min_master_version       = var.k8s_min_master_version
  initial_node_count       = 1
  remove_default_node_pool = true
  project                  = var.project_id
  network                  = google_compute_network.k8s.self_link
  deletion_protection      = false

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      // GMT
      start_time = "05:00"
    }
  }

}

resource "google_container_node_pool" "main-node-pool" {
  #checkov:skip=CKV_GCP_68:Ensure Secure Boot for Shielded GKE Nodes is Enabled
  #checkov:skip=CKV_GCP_69:Ensure the GKE Metadata Server is Enabled
  #checkov:skip=CKV_GCP_22:Ensure Container-Optimized OS (cos) is used for Kubernetes Engine Clusters Node image

  depends_on = [google_project_service.container]
  name       = "main-node-pool"
  location   = var.region
  cluster    = google_container_cluster.runner-benchmark.name
  node_count = 1
  project    = var.project_id
  version    = var.k8s_min_master_version

  lifecycle {
    ignore_changes = [
      node_count,
      version,
    ]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = var.k8s_autoscaling_max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.k8s_machine_type

    oauth_scopes = [
      "compute-rw",
      "storage-rw",
      "logging-write",
      "monitoring",
    ]

    service_account = google_service_account.compute.email
    tags            = ["k8s-node", "default-node-pool"]
  }
}

resource "google_storage_bucket" "benchmark-output-storage" {
  #checkov:skip=CKV_GCP_114:Ensure public access prevention is enforced on Cloud Storage bucket
  #checkov:skip=CKV_GCP_78:Ensure Cloud storage has versioning enabled
  #checkov:skip=CKV_GCP_62:Bucket should log access
  name                        = "${var.project_id}-outputs"
  location                    = var.region
  force_destroy               = "true"
  project                     = var.project_id
  uniform_bucket_level_access = true

  retention_policy {
    is_locked        = false
    retention_period = 31536000
  }
}

output "benchmark-output-storage" {
  value = google_storage_bucket.benchmark-output-storage.name
}
