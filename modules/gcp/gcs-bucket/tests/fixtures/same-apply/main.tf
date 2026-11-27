# A root that creates a service account and a topic in the same apply as the bucket. Their
# computed values (member, topic id) are unknown at plan time, so nothing in the module may key a
# for_each or a count on them. tests/same_apply.tftest.hcl plans this with a mock provider, which
# leaves computed values unknown during plan, as a first real apply would.
resource "google_service_account" "reader" {
  project    = "acme-uat"
  account_id = "acme-uat-reader"
}

resource "google_pubsub_topic" "uploads" {
  project = "acme-uat"
  name    = "uploads"
}

module "bucket" {
  source = "../../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name       = "uploads"
  project_id = "acme-uat"
  location   = "US-EAST1"

  iam = {
    readers = { role = "roles/storage.objectViewer", members = { reader = google_service_account.reader.member } }
  }

  notifications = {
    uploads = { topic = google_pubsub_topic.uploads.id }
  }
}
