terraform {
  required_version = ">= 1.14, < 2.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.13, < 7.0"
    }
  }
}

# Credentials come from the environment, never from code. Attaching repositories to an App
# installation needs a user token (GITHUB_TOKEN set to a classic personal access token of a user
# with admin on the repositories); GitHub App authentication cannot call this endpoint.
provider "github" {
  owner = "acme"
}
