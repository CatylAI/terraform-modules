output "email" {
  description = "Email address of the service account. Null when the module is disabled."
  value       = one(google_service_account.this[*].email)
}

output "member" {
  description = "IAM member string for the service account, serviceAccount:<email>, for granting it roles elsewhere. Null when the module is disabled."
  value       = one(google_service_account.this[*].member)
}

output "unique_id" {
  description = "Stable numeric unique id of the service account. Null when the module is disabled."
  value       = one(google_service_account.this[*].unique_id)
}

output "name" {
  description = "Full resource name of the service account, projects/<project>/serviceAccounts/<email>. Null when the module is disabled."
  value       = one(google_service_account.this[*].name)
}
