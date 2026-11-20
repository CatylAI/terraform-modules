locals {
  pool_name = one(google_iam_workload_identity_pool.this[*].name)

  # Custom attributes are pool-wide: an IAM principal set matches the attribute whichever provider
  # mapped it, so the output is the union over every provider.
  custom_attributes = toset(flatten([
    for p in values(local.providers) : [for k in keys(p.attribute_mapping) : trimprefix(k, "attribute.") if startswith(k, "attribute.")]
  ]))
}

output "pool_name" {
  description = "Full resource name of the pool: projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>. Null when the module is disabled."
  value       = local.pool_name
}

output "pool_id" {
  description = "Short pool id (the last segment of pool_name). Null when the module is disabled."
  value       = one(google_iam_workload_identity_pool.this[*].workload_identity_pool_id)
}

output "provider_names" {
  description = "Full resource name of each provider, keyed like var.oidc_providers: projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>/providers/<key>. This is the value CI takes as workload_identity_provider."
  value       = { for k, p in google_iam_workload_identity_pool_provider.this : k => p.name }
}

output "principal_sets" {
  description = "IAM member prefix per custom attribute mapped by any provider, keyed by the attribute name without 'attribute.': principalSet://iam.googleapis.com/<pool_name>/attribute.<name>/. Append the attribute value to get a member: the repository entry followed by acme/app matches that one repository. google.* mappings get no entry."
  value       = { for a in(local.pool_name == null ? [] : local.custom_attributes) : a => "principalSet://iam.googleapis.com/${local.pool_name}/attribute.${a}/" }
}
