# =============================================================================
# Wiz Project — Development Environment
# =============================================================================
# Groups the dev workloads scanned by the AWS connector into a dedicated Wiz
# project. Membership is rule-based: a resource joins this project when it
# lives in the target AWS account AND carries the environment=ra-workshop-dev
# tag that the infra/aws stack stamps on every dev resource (via default_tags).
# =============================================================================

# --- Variables --------------------------------------------------------------

variable "project_name_dev" {
  description = "Display name for the dev Wiz project (follows the TF-…-AgentWorkshop convention used by the connectors)."
  type        = string
}

variable "project_name_dev_t1" {
  description = "Display name for the tenant 1 dev Wiz project."
  type        = string
}

variable "project_name_dev_t2" {
  description = "Display name for the tenant 2 dev Wiz project."
  type        = string
}

# --- Data: resolve the Wiz cloud-account object ID --------------------------
# cloud_account_links wants Wiz's internal cloud-account ID, not the raw AWS
# account number. Look it up by external_id (the AWS account) so the config
# stays keyed to var.aws_account_id.

data "wiz-v2_cloud_accounts" "dev" {
  search = [var.aws_account_id]
}

locals {
  dev_cloud_account_id = one([
    for a in data.wiz-v2_cloud_accounts.dev.cloud_accounts :
    a.id if a.external_id == var.aws_account_id
  ])
}

# Tenant 1's cloud-account object ID.
data "wiz-v2_cloud_accounts" "dev_t1" {
  provider = wiz-v2.tenant1
  search   = [var.aws_account_id]
}

locals {
  dev_cloud_account_id_t1 = one([
    for a in data.wiz-v2_cloud_accounts.dev_t1.cloud_accounts :
    a.id if a.external_id == var.aws_account_id
  ])
}

# Tenant 2's cloud-account object ID.
data "wiz-v2_cloud_accounts" "dev_t2" {
  provider = wiz-v2.tenant2
  search   = [var.aws_account_id]
}

locals {
  dev_cloud_account_id_t2 = one([
    for a in data.wiz-v2_cloud_accounts.dev_t2.cloud_accounts :
    a.id if a.external_id == var.aws_account_id
  ])
}

# --- Resource ---------------------------------------------------------------

resource "wiz-v2_project" "dev" {
  name        = var.project_name_dev
  slug        = "tf-project-dev-agentworkshop"
  description = "Development and sandbox workloads (account ${var.aws_account_id}, tag environment=ra-workshop-dev)."

  risk_profile = {
    business_impact       = "LBI"
    is_actively_developed = "YES"
    has_authentication    = "NO"
    has_exposed_api       = "YES"
    is_internet_facing    = "YES"
    is_customer_facing    = "YES"
    stores_data           = "NO"
    is_regulated          = "NO"
    sensitive_data_types  = []
    regulatory_standards  = []
  }


  cloud_account_links = [
    {
      cloud_account = local.dev_cloud_account_id
      environment   = "DEVELOPMENT"
      resource_tags_v3 = {
        equals_any = [
          { key_equals = "environment", value_equals = "ra-workshop-dev" },
        ]
      }

    },
  ]

  repository_links = []
}

# --- Tenant 1 ---------------------------------------------------------------

resource "wiz-v2_project" "dev_t1" {
  provider = wiz-v2.tenant1

  name        = var.project_name_dev_t1
  slug        = "tf-project-dev-agentworkshop-t1"
  description = "Tenant 1: development and sandbox workloads (account ${var.aws_account_id}, tag environment=ra-workshop-dev)."

  risk_profile = {
    business_impact       = "LBI"
    is_actively_developed = "YES"
    has_authentication    = "NO"
    has_exposed_api       = "YES"
    is_internet_facing    = "YES"
    is_customer_facing    = "YES"
    stores_data           = "NO"
    is_regulated          = "NO"
    sensitive_data_types  = []
    regulatory_standards  = []
  }

  cloud_account_links = [
    {
      cloud_account = local.dev_cloud_account_id_t1
      environment   = "DEVELOPMENT"
      resource_tags_v3 = {
        equals_any = [
          { key_equals = "environment", value_equals = "ra-workshop-dev" },
        ]
      }
    },
  ]

  repository_links = []
}

# --- Tenant 2 ---------------------------------------------------------------

resource "wiz-v2_project" "dev_t2" {
  provider = wiz-v2.tenant2

  name        = var.project_name_dev_t2
  slug        = "tf-project-dev-agentworkshop-t2"
  description = "Tenant 2: development and sandbox workloads (account ${var.aws_account_id}, tag environment=ra-workshop-dev)."

  risk_profile = {
    business_impact       = "LBI"
    is_actively_developed = "YES"
    has_authentication    = "NO"
    has_exposed_api       = "YES"
    is_internet_facing    = "YES"
    is_customer_facing    = "YES"
    stores_data           = "NO"
    is_regulated          = "NO"
    sensitive_data_types  = []
    regulatory_standards  = []
  }

  cloud_account_links = [
    {
      cloud_account = local.dev_cloud_account_id_t2
      environment   = "DEVELOPMENT"
      resource_tags_v3 = {
        equals_any = [
          { key_equals = "environment", value_equals = "ra-workshop-dev" },
        ]
      }
    },
  ]

  repository_links = []
}

# --- Outputs ----------------------------------------------------------------

output "project_dev_id" {
  description = "Wiz project ID for the dev environment (visible in the Wiz UI)."
  value       = wiz-v2_project.dev.id
}

output "project_dev_name" {
  description = "Wiz project display name."
  value       = wiz-v2_project.dev.name
}

output "project_dev_id_t1" {
  description = "Tenant 1 Wiz project ID for the dev environment (visible in the Wiz UI)."
  value       = wiz-v2_project.dev_t1.id
}

output "project_dev_name_t1" {
  description = "Tenant 1 Wiz project display name."
  value       = wiz-v2_project.dev_t1.name
}

output "project_dev_id_t2" {
  description = "Tenant 2 Wiz project ID for the dev environment (visible in the Wiz UI)."
  value       = wiz-v2_project.dev_t2.id
}

output "project_dev_name_t2" {
  description = "Tenant 2 Wiz project display name."
  value       = wiz-v2_project.dev_t2.name
}
