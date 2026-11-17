provider "google" {
  project = var.project_id
  region  = var.region

  # Resources written inline in this root get the same reserved labels modules apply (MS-11.5).
  default_labels = local.labels
}
