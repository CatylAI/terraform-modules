# The live estate's tflint config, plus the rules a module repository needs on top.
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Modules declare required_providers but never configure them; examples carry the provider block.
rule "terraform_standard_module_structure" {
  enabled = true
}
