terraform {
  required_version = ">= 1.14, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.3, < 9.0"
    }
  }
}
