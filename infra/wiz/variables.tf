# =============================================================================
# Wiz Provider Variables (Tenant 1 + Tenant 2)
# =============================================================================

# ----- Tenant 1 -----

variable "wiz_env_t1" {
  description = "Wiz environment (data center) for tenant 1."
  type        = string
}

variable "wiz_client_id_t1" {
  description = "Tenant 1 Wiz service account client ID."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.wiz_client_id_t1) > 0
    error_message = "wiz_client_id_t1 must not be empty."
  }
}

variable "wiz_client_secret_t1" {
  description = "Tenant 1 Wiz service account client secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.wiz_client_secret_t1) > 0
    error_message = "wiz_client_secret_t1 must not be empty."
  }
}

# ----- Tenant 2 (disabled) -----
/* Tenant 2 vars disabled — provider and resources are commented out.
variable "wiz_env_t2" {
  description = "Wiz environment (data center) for tenant 2."
  type        = string
}

variable "wiz_client_id_t2" {
  description = "Tenant 2 Wiz service account client ID."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.wiz_client_id_t2) > 0
    error_message = "wiz_client_id_t2 must not be empty."
  }
}

variable "wiz_client_secret_t2" {
  description = "Tenant 2 Wiz service account client secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.wiz_client_secret_t2) > 0
    error_message = "wiz_client_secret_t2 must not be empty."
  }
}
*/

# =============================================================================
# AWS Provider Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for provider configuration. SCP-allowed values only."
  type        = string

  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-2"], var.aws_region)
    error_message = "aws_region must be us-east-1, us-east-2, or us-west-2 (SCP-allowed)."
  }
}

variable "aws_profile" {
  description = "AWS named profile that maps to the target account."
  type        = string
}

variable "owner" {
  description = "Required `owner` tag (mandatory in this playground account per CLAUDE.md)."
  type        = string
}
