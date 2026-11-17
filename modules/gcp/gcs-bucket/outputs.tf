output "name" {
  description = "Bucket name. Null when the module is disabled."
  value       = one(google_storage_bucket.this[*].name)
}

output "url" {
  description = "gs:// URL of the bucket. Null when the module is disabled."
  value       = one(google_storage_bucket.this[*].url)
}

output "self_link" {
  description = "API self link of the bucket. Null when the module is disabled."
  value       = one(google_storage_bucket.this[*].self_link)
}

output "notification_ids" {
  description = "Notification ids keyed like var.notifications."
  value       = { for k, n in google_storage_notification.this : k => n.notification_id }
}
