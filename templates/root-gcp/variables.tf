# Set in envs/common.tfvars: identical in every environment.
variable "allowed_tenants" {
  description = "The organisation's tenant list. Policy belongs in the root, not the modules (module-standard MS-15.2)."
  type        = list(string)
}

variable "tenant" {
  description = "Tenant that owns this stack; must be one of allowed_tenants."
  type        = string

  validation {
    condition     = contains(var.allowed_tenants, var.tenant)
    error_message = "tenant must be one of allowed_tenants."
  }
}

variable "component" {
  description = "This stack's component name, kebab-case. Part of every resource name and of the state prefix."
  type        = string
}

variable "repo" {
  description = "Repository that holds this root."
  type        = string
}

# Passed only by scripts/tf.sh as -var environment=<env> (MS-11.2). No default: a forgotten value
# fails at plan time instead of planning against the wrong environment.
variable "environment" {
  description = "Environment being planned. Set by scripts/tf.sh from its first argument; never in tfvars."
  type        = string

  validation {
    condition     = contains(["local", "test", "dev", "uat", "staging", "prod"], var.environment)
    error_message = "environment must be one of: local, test, dev, uat, staging, prod."
  }
}

# Set in envs/<env>.tfvars: these differ per environment and so have no defaults (MS-2.4).
variable "project_id" {
  description = "GCP project this environment deploys into."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
}

variable "uploads_bucket" {
  description = "Settings for the example bucket that differ per environment. Unset attributes keep the module's secure defaults."
  type = object({
    location               = string
    soft_delete_days       = optional(number, 7)
    deletion_protection_on = optional(bool, true)
  })
}
