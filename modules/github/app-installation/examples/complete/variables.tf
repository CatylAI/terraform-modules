# The root's optional installation id. Null where the App is installed by hand in the GitHub UI.
variable "release_app_installation_id" {
  description = "Installation id of the release App, or null where the App is installed by hand in the GitHub UI."
  type        = number
  default     = 12345678
}
