output "service_account_member" {
  description = "IAM member string of the service account, for grants made elsewhere."
  value       = module.service_account.member
}
