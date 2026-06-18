output "role_arn_t1" {
  description = "Tenant 1 Wiz IAM role ARN. Consumed by the root module's connector_aws.tf via terraform_remote_state."
  value       = module.wiz_t1.role_arn
}

# Tenant 2 output disabled — module.wiz_t2 is commented out.
# output "role_arn_t2" {
#   description = "Tenant 2 Wiz IAM role ARN. Consumed by the root module's connector_aws.tf via terraform_remote_state."
#   value       = module.wiz_t2.role_arn
# }
