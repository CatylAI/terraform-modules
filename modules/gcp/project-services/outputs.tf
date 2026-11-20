output "services" {
  description = "Enabled API names keyed like var.services. Empty when the module is disabled. Reference it to make a resource wait for its API."
  value       = { for k, s in google_project_service.this : k => s.service }
}
