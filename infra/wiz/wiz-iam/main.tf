# Look up the tenant ID via the Wiz GraphQL API. Used as the external-id
# bound to the IAM role's trust policy, so only this specific Wiz tenant
# (not any other Wiz customer in the same data center) can assume the role.
data "wiz-v2_graphql_query" "me" {
  query = <<-EOQ
    query {
      viewerV2 {
        tenant { id }
      }
    }
  EOQ
}

locals {
  tenant_id = jsondecode(data.wiz-v2_graphql_query.me.result).viewerV2.tenant.id
}

# Wiz's published terraform module: provisions the customer IAM role with a
# trust policy bound to (wiz_remote_arn, external-id=tenant_id) and attaches
# the AWS-managed + Wiz-custom policies needed for the AWS connector.
module "wiz" {
  source                    = "https://wizio-public.s3.amazonaws.com/deployment-v3/aws/terraform/2527/wiz-aws-native-terraform-terraform-module.zip"
  external-id               = local.tenant_id
  data-scanning             = true
  lightsail-scanning        = false
  eks-scanning              = false
  remote-arn                = var.wiz_remote_arn
  terraform-bucket-scanning = true
  cloud-cost-scanning       = false
  rolename                  = var.wiz_role_name
  iam_policy_suffix         = var.iam_policy_suffix
}

# --- Tenant 1 -----------------------------------------------------------------

data "wiz-v2_graphql_query" "me_t1" {
  provider = wiz-v2.tenant1
  query    = <<-EOQ
    query {
      viewerV2 {
        tenant { id }
      }
    }
  EOQ
}

locals {
  tenant_id_t1 = jsondecode(data.wiz-v2_graphql_query.me_t1.result).viewerV2.tenant.id
}

module "wiz_t1" {
  source                    = "https://wizio-public.s3.amazonaws.com/deployment-v3/aws/terraform/2527/wiz-aws-native-terraform-terraform-module.zip"
  external-id               = local.tenant_id_t1
  data-scanning             = true
  lightsail-scanning        = false
  eks-scanning              = false
  remote-arn                = var.wiz_remote_arn_t1
  terraform-bucket-scanning = true
  cloud-cost-scanning       = false
  rolename                  = var.wiz_role_name_t1
  iam_policy_suffix         = var.iam_policy_suffix_t1
}

# --- Tenant 2 -----------------------------------------------------------------

data "wiz-v2_graphql_query" "me_t2" {
  provider = wiz-v2.tenant2
  query    = <<-EOQ
    query {
      viewerV2 {
        tenant { id }
      }
    }
  EOQ
}

locals {
  tenant_id_t2 = jsondecode(data.wiz-v2_graphql_query.me_t2.result).viewerV2.tenant.id
}

module "wiz_t2" {
  source                    = "https://wizio-public.s3.amazonaws.com/deployment-v3/aws/terraform/2527/wiz-aws-native-terraform-terraform-module.zip"
  external-id               = local.tenant_id_t2
  data-scanning             = true
  lightsail-scanning        = false
  eks-scanning              = false
  remote-arn                = var.wiz_remote_arn_t2
  terraform-bucket-scanning = true
  cloud-cost-scanning       = false
  rolename                  = var.wiz_role_name_t2
  iam_policy_suffix         = var.iam_policy_suffix_t2
}
