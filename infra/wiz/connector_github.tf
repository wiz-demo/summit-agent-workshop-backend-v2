# =============================================================================
# Wiz GitHub Connectors (Tenant 1 + Tenant 2)
# =============================================================================
# GitHub auth is self-contained (GitHub App ID + private key), so these
# connectors have NO wiz-iam dependency. Provisioned by `make apply-root`.
# =============================================================================

# --- Variables --------------------------------------------------------------

# GitHub connector vars disabled — all github_* resources are commented out below.
/*
variable "github_app_id" {
  description = "GitHub App ID Wiz authenticates as. Found in the GitHub App's settings page."
  type        = string

  validation {
    condition     = length(var.github_app_id) > 0
    error_message = "github_app_id must not be empty."
  }
}

variable "github_app_private_key_path" {
  description = "Filesystem path (relative to infra/wiz/) to the GitHub App private key PEM. Must point at a gitignored .pem; never commit the key."
  type        = string
}

variable "github_connector_name_t1" {
  description = "Display name for the tenant 1 Wiz GitHub connector shown in the Wiz UI."
  type        = string
}

variable "github_connector_name_t2" {
  description = "Display name for the tenant 2 Wiz GitHub connector shown in the Wiz UI."
  type        = string
}
*/

# --- Tenant 1 ---------------------------------------------------------------

# Tenant 1 GitHub connector. Reuses the same GitHub App (github_app_id + PEM)
# as the original tenant, onboarded into the tenant-1 Wiz provider.
/* Tenant 1 GitHub connector temporarily disabled.
resource "wiz-v2_generic_connector" "github_t1" {
  provider = wiz-v2.tenant1

  name = var.github_connector_name_t1
  type = "github"

  auth_params = jsonencode({
    serverType = "github.com"
    apps = [{
      id         = var.github_app_id
      privateKey = file("${path.module}/${var.github_app_private_key_path}")
    }]
  })

  extra_config = jsonencode({
    scan = {
      scheduled = {
        enabled                        = true
        gitHistoryScanningEnabled      = false
        scanPublicRepositories         = true
        scanPublicPersonalRepositories = true
        modules = {
          vulnerabilities     = { enabled = true }
          data                = { enabled = true }
          iac                 = { enabled = true }
          secrets             = { enabled = true }
          sast                = { enabled = true }
          softwareSupplyChain = { enabled = true }
        }
      }
    }
  })
}
*/

# --- Tenant 2 ---------------------------------------------------------------

# Tenant 2 GitHub connector. Reuses the same GitHub App (github_app_id + PEM)
# as the original tenant, onboarded into the tenant-2 Wiz provider.
/* Tenant 2 GitHub connector temporarily disabled.
resource "wiz-v2_generic_connector" "github_t2" {
  provider = wiz-v2.tenant2

  name = var.github_connector_name_t2
  type = "github"

  auth_params = jsonencode({
    serverType = "github.com"
    apps = [{
      id         = var.github_app_id
      privateKey = file("${path.module}/${var.github_app_private_key_path}")
    }]
  })

  extra_config = jsonencode({
    scan = {
      scheduled = {
        enabled                        = true
        gitHistoryScanningEnabled      = false
        scanPublicRepositories         = true
        scanPublicPersonalRepositories = true
        modules = {
          vulnerabilities     = { enabled = true }
          data                = { enabled = true }
          iac                 = { enabled = true }
          secrets             = { enabled = true }
          sast                = { enabled = true }
          softwareSupplyChain = { enabled = true }
        }
      }
    }
  })
}
*/

# --- Outputs ----------------------------------------------------------------

/* Tenant 1 GitHub connector outputs temporarily disabled.
output "github_connector_id_t1" {
  description = "Tenant 1 Wiz GitHub connector ID (visible in the Wiz UI)."
  value       = wiz-v2_generic_connector.github_t1.id
}

output "github_connector_name_t1" {
  description = "Tenant 1 Wiz GitHub connector display name."
  value       = wiz-v2_generic_connector.github_t1.name
}
*/

/* Tenant 2 GitHub connector outputs temporarily disabled.
output "github_connector_id_t2" {
  description = "Tenant 2 Wiz GitHub connector ID (visible in the Wiz UI)."
  value       = wiz-v2_generic_connector.github_t2.id
}

output "github_connector_name_t2" {
  description = "Tenant 2 Wiz GitHub connector display name."
  value       = wiz-v2_generic_connector.github_t2.name
}
*/
