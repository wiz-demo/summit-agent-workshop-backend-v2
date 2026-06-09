# =============================================================================
# Wiz GitHub Connector
# =============================================================================
# Self-contained: connector-specific variables, the resource, and outputs.
#
# Unlike the AWS connector, GitHub auth is self-contained (GitHub App ID +
# private key), so this connector has NO wiz-iam dependency. It is provisioned
# by the root module's `make apply-root` target.
# =============================================================================

# --- Variables --------------------------------------------------------------

variable "github_connector_name" {
  description = "Display name for the Wiz GitHub connector shown in the Wiz UI."
  type        = string
}

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

# --- Resource ---------------------------------------------------------------

resource "wiz-v2_generic_connector" "github" {
  name = var.github_connector_name
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

output "github_connector_id" {
  description = "Wiz GitHub connector ID (visible in the Wiz UI)."
  value       = wiz-v2_generic_connector.github.id
}

output "github_connector_name" {
  description = "Wiz GitHub connector display name."
  value       = wiz-v2_generic_connector.github.name
}

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
