# Same shape as the root module's variables, redeclared here because the
# wiz-iam sub-module has its own provider config and tfstate. Values are
# supplied from the shared infra/wiz/terraform.tfvars (no defaults).

variable "aws_region" {
  description = "AWS region for provider configuration."
  type        = string
}

variable "aws_profile" {
  description = "AWS named profile that maps to the target account."
  type        = string
}

variable "owner" {
  description = "Required `owner` tag (mandatory in this playground account)."
  type        = string
}

# ----- Tenant 1 -----

variable "wiz_env_t1" {
  description = "Wiz environment (data center) for tenant 1."
  type        = string
}

variable "wiz_client_id_t1" {
  description = "Tenant 1 Wiz service account client ID. Needed for the data.wiz-v2_graphql_query that fetches tenant 1's tenant ID for the IAM role external-id."
  type        = string
  sensitive   = true
}

variable "wiz_client_secret_t1" {
  description = "Tenant 1 Wiz service account client secret."
  type        = string
  sensitive   = true
}

variable "wiz_role_name_t1" {
  description = "Name of the IAM role to create for Wiz tenant 1 to assume. Must differ from wiz_role_name and wiz_role_name_t2 (same AWS account)."
  type        = string
}

variable "iam_policy_suffix_t1" {
  description = "Suffix appended to tenant 1's Wiz custom IAM policy names. Must differ from iam_policy_suffix and iam_policy_suffix_t2 (same AWS account)."
  type        = string
}

variable "wiz_remote_arn_t1" {
  description = "Wiz data-center role ARN allowed to assume tenant 1's customer IAM role. Provided by Wiz; may differ from wiz_remote_arn if tenant 1 is in another data center."
  type        = string
}

# ----- Tenant 2 (disabled) -----
/* Tenant 2 vars disabled — provider and resources are commented out.
variable "wiz_env_t2" {
  description = "Wiz environment (data center) for tenant 2."
  type        = string
}

variable "wiz_client_id_t2" {
  description = "Tenant 2 Wiz service account client ID. Needed for the data.wiz-v2_graphql_query that fetches tenant 2's tenant ID for the IAM role external-id."
  type        = string
  sensitive   = true
}

variable "wiz_client_secret_t2" {
  description = "Tenant 2 Wiz service account client secret."
  type        = string
  sensitive   = true
}

variable "wiz_role_name_t2" {
  description = "Name of the IAM role to create for Wiz tenant 2 to assume. Must differ from wiz_role_name and wiz_role_name_t1 (same AWS account)."
  type        = string
}

variable "iam_policy_suffix_t2" {
  description = "Suffix appended to tenant 2's Wiz custom IAM policy names. Must differ from iam_policy_suffix and iam_policy_suffix_t1 (same AWS account)."
  type        = string
}

variable "wiz_remote_arn_t2" {
  description = "Wiz data-center role ARN allowed to assume tenant 2's customer IAM role. Provided by Wiz; may differ from wiz_remote_arn if tenant 2 is in another data center."
  type        = string
}
*/
