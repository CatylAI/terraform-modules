output "workload_identity_provider" {
  description = "Full resource name of the GitHub provider, for the CI workload_identity_provider setting."
  value       = module.wif.provider_names["github"]
}
