output "provider_names" {
  description = "Full resource name of each provider, for the CI workload_identity_provider setting."
  value       = module.wif.provider_names
}
