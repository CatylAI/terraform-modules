terraform {
  required_version = ">= 1.14, < 2.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.13, < 7.0"
    }
  }
}

# Credentials come from the environment (GITHUB_TOKEN or GitHub App variables), never from code.
provider "github" {
  owner = "acme"
}
