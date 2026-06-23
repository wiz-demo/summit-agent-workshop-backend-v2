variable "region" {
  type        = string
  description = "AWS region. Must be one of the SCP-allowed regions."
  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-2"], var.region)
    error_message = "Region must be us-east-1, us-east-2, or us-west-2 (SCP-allowed)."
  }
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile (SSO) for the target account. Verified via `aws sts get-caller-identity --profile <name>`."
}

variable "owner" {
  type        = string
  description = "Required `owner` tag value. Per CLAUDE.md, mandatory on most resources."
}

variable "project" {
  type        = string
  description = "Project tag for cost attribution."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
}

variable "vpc_cidr_by_env" {
  type        = map(string)
  description = "VPC CIDR per environment. Distinct blocks so prod/dev never overlap."
}

variable "environment" {
  type        = string
  description = "Deployment environment. Must be prod or dev. Selects the Terraform workspace, resource-name suffix, and VPC CIDR."
  validation {
    condition     = contains(["prod", "dev"], var.environment)
    error_message = "environment must be \"prod\" or \"dev\"."
  }
}

# =============================================================================
# Wiz Runtime Sensor (ECS daemon)
# =============================================================================
# Consumed by infra/aws/wiz_sensor.tf via the official Wiz Terraform module.
#
# Pull key:       https://app.wiz.io/tenant-info/general (domain dropdown)
# Service acct:   Wiz portal -> Settings -> Service Accounts -> type "Sensor"
# =============================================================================

variable "wiz_sensor_image_pull_username" {
  type        = string
  description = "Username for pulling the Wiz sensor image from the Wiz registry."
}

variable "wiz_sensor_image_pull_password" {
  type        = string
  description = "Password for pulling the Wiz sensor image from the Wiz registry."
  sensitive   = true
}

variable "wiz_sensor_sa_client_id" {
  type        = string
  description = "Client ID of the Wiz service account the sensor authenticates as."
}

variable "wiz_sensor_sa_client_secret" {
  type        = string
  description = "Client secret of the Wiz service account the sensor authenticates as."
  sensitive   = true
}

variable "wiz_sensor_api_security_enabled" {
  type        = bool
  description = "Enable API security in the Wiz sensor."
  default     = true
}

variable "wiz_sensor_ecs_task_logging_enabled" {
  type        = bool
  description = "Enable ECS task logging for the sensor daemon. Useful when troubleshooting."
  default     = true
}

variable "wiz_dc" {
  type        = string
  description = "Wiz data center identifier (e.g. \"us20\", \"us36\"). Find it at https://app.wiz.io/tenant-info/data-center-and-regions under \"Tenant Data Center\". Used to template the Runtime Sensor egress FQDNs in wiz_sensor.tf."
}

variable "wiz_sensor_backend_environment" {
  type        = string
  description = "Wiz backend environment the sensor authenticates against. \"prod\" for app.wiz.io tenants, \"test\" for test.wiz.io tenants. Maps to the BACKEND_ENV env var in the sensor container."
  default     = "prod"
}
