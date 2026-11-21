terraform {
  required_version = ">= 1.14, < 2.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.13, < 7.0"
    }
  }
}

provider "github" {
  owner = "acme"
}
