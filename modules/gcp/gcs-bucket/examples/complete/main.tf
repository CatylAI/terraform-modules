# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "bucket" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "storefront"
    repo        = "storefront"
    labels      = { team = "platform" }
  }
  name          = "assets"
  name_override = null
  project_id    = "acme-uat"
  location      = "US-EAST1"
  storage_class = "STANDARD"

  versioning          = { enabled = true }
  soft_delete         = { retention_days = 14 }
  encryption          = { kms_key_name = "projects/acme-uat/locations/us-east1/keyRings/data/cryptoKeys/gcs" }
  deletion_protection = { enabled = true }
  retention_policy    = { enabled = false }
  autoclass           = { enabled = false }
  access_logging      = { log_bucket = "acme-uat-access-logs", log_object_prefix = "assets/" }

  lifecycle_rules = {
    expire-noncurrent = {
      action    = { type = "Delete" }
      condition = { days_since_noncurrent_time = 30 }
    }
    abort-multipart = {
      action    = { type = "AbortIncompleteMultipartUpload" }
      condition = { age = 1 }
    }
  }

  cors = {
    site = { origins = ["https://www.example.com"], methods = ["GET", "HEAD"], max_age_seconds = 3600 }
  }

  iam = {
    api-read = { role = "roles/storage.objectViewer", members = ["serviceAccount:api@acme-uat.iam.gserviceaccount.com"] }
  }

  notifications = {
    uploads = { topic = "projects/acme-uat/topics/assets-uploaded", object_name_prefix = "incoming/" }
  }
}
