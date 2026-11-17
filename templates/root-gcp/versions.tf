terraform {
  required_version = ">= 1.16.4, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.3"
    }
  }

  # Partial on purpose: scripts/tf.sh supplies envs/<env>.gcs.tfbackend (module-standard MS-11).
  backend "gcs" {}
}
