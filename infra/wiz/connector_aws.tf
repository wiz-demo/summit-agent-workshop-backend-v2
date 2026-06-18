# =============================================================================
# Wiz AWS Connectors (Tenant 1 + Tenant 2)
# =============================================================================
# PREREQUISITE: the wiz-iam/ sub-project must be applied first (it provisions
# the IAM roles these connectors consume). The Makefile's `make apply` runs
# them in the right order.
# =============================================================================

# --- Variables --------------------------------------------------------------

variable "aws_account_id" {
  description = "AWS account ID Wiz should scan. Used to pin the connector scope (the precondition asserts the role ARN's account matches)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit number."
  }
}

variable "connector_name_t1" {
  description = "Display name for the tenant 1 Wiz AWS connector shown in the Wiz UI."
  type        = string
}

# Tenant 2 connector_name disabled — resource is commented out.
# variable "connector_name_t2" {
#   description = "Display name for the tenant 2 Wiz AWS connector shown in the Wiz UI."
#   type        = string
# }

# --- Resource ---------------------------------------------------------------

data "terraform_remote_state" "wiz_iam" {
  backend = "s3"
  config = {
    bucket  = "tf-state-800618367342-us-east-1"
    key     = "summit-agent-workshop/infra/wiz/wiz-iam/terraform.tfstate"
    region  = "us-east-1"
    profile = "dev-product-cto-play"
  }
}

# --- Tenant 1 ---------------------------------------------------------------

resource "wiz-v2_generic_connector" "aws_t1" {
  provider = wiz-v2.tenant1

  name = var.connector_name_t1
  type = "aws"

  auth_params = jsonencode({
    customerRoleARN = data.terraform_remote_state.wiz_iam.outputs.role_arn_t1
  })

  lifecycle {
    precondition {
      condition     = split(":", data.terraform_remote_state.wiz_iam.outputs.role_arn_t1)[4] == var.aws_account_id
      error_message = "Tenant 1 role ARN's account (${split(":", data.terraform_remote_state.wiz_iam.outputs.role_arn_t1)[4]}) does not match var.aws_account_id (${var.aws_account_id})."
    }
  }

  extra_config = jsonencode({
    skipOrganizationScan = true
  })
}

# --- Tenant 2 (disabled) ----------------------------------------------------

/* Tenant 2 disabled for the fork — provider and IAM role module are gated off.
resource "wiz-v2_generic_connector" "aws_t2" {
  provider = wiz-v2.tenant2

  name = var.connector_name_t2
  type = "aws"

  auth_params = jsonencode({
    customerRoleARN = data.terraform_remote_state.wiz_iam.outputs.role_arn_t2
  })

  lifecycle {
    precondition {
      condition     = split(":", data.terraform_remote_state.wiz_iam.outputs.role_arn_t2)[4] == var.aws_account_id
      error_message = "Tenant 2 role ARN's account (${split(":", data.terraform_remote_state.wiz_iam.outputs.role_arn_t2)[4]}) does not match var.aws_account_id (${var.aws_account_id})."
    }
  }

  extra_config = jsonencode({
    skipOrganizationScan = true
  })
}
*/

# --- Outputs ----------------------------------------------------------------

output "aws_role_arn_t1" {
  description = "ARN of the IAM role Wiz tenant 1 assumes to scan the account."
  value       = data.terraform_remote_state.wiz_iam.outputs.role_arn_t1
}

output "aws_connector_id_t1" {
  description = "Tenant 1 Wiz AWS connector ID (visible in the Wiz UI)."
  value       = wiz-v2_generic_connector.aws_t1.id
}

output "aws_connector_name_t1" {
  description = "Tenant 1 Wiz AWS connector display name."
  value       = wiz-v2_generic_connector.aws_t1.name
}

# Tenant 2 outputs disabled — resource is commented out.
# output "aws_role_arn_t2" {
#   description = "ARN of the IAM role Wiz tenant 2 assumes to scan the account."
#   value       = data.terraform_remote_state.wiz_iam.outputs.role_arn_t2
# }
#
# output "aws_connector_id_t2" {
#   description = "Tenant 2 Wiz AWS connector ID (visible in the Wiz UI)."
#   value       = wiz-v2_generic_connector.aws_t2.id
# }
#
# output "aws_connector_name_t2" {
#   description = "Tenant 2 Wiz AWS connector display name."
#   value       = wiz-v2_generic_connector.aws_t2.name
# }
