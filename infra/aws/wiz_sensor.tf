# =============================================================================
# Wiz Runtime Sensor — deployed onto this ECS cluster as a daemon service.
# =============================================================================
# The official Wiz module fetches a zip on every `terraform init` (no version
# pin in the URL). For workshop use this is fine; for reproducible builds we
# would vendor the zip locally and source it from disk.
# =============================================================================

module "ecs_cluster_wiz_sensor" {
  source = "https://downloads.wiz.io/customer-files/aws/wiz-aws-sensor-ecs-terraform-module.zip"

  ecs_cluster_arn = aws_ecs_cluster.this.arn

  wiz_sensor_image_pull_username = var.wiz_sensor_image_pull_username
  wiz_sensor_image_pull_password = var.wiz_sensor_image_pull_password

  wiz_sensor_service_account_client_id     = var.wiz_sensor_sa_client_id
  wiz_sensor_service_account_client_secret = var.wiz_sensor_sa_client_secret

  wiz_sensor_api_security_enabled = var.wiz_sensor_api_security_enabled
  ecs_task_logging_enabled        = var.wiz_sensor_ecs_task_logging_enabled

  wiz_sensor_backend_environment = var.wiz_sensor_backend_environment
}

output "ecs_cluster_wiz_sensor" {
  value       = module.ecs_cluster_wiz_sensor
  description = "Outputs from the Wiz sensor module (task definition ARN, service name, etc.)."
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Required egress FQDNs for the Runtime Sensor (Wiz Commercial, registry.wiz.io,
# Linux container / ECS-on-EC2 flavor). Documented in Wiz docs under
# "Required URLs for Runtime Sensor".
#
# The backend security group (infra/aws/ec2.tf) currently allows all outbound
# (0.0.0.0/0), so these are reachable today. Security groups cannot filter by
# FQDN — if you ever need FQDN-level egress restriction, feed the list below to
# AWS Network Firewall (aws_networkfirewall_rule_group) or a forward proxy.
#
# Two endpoints are listed only for Wiz's static-IP mode; remove them if that
# mode is not in use.
# -----------------------------------------------------------------------------

locals {
  wiz_sensor_required_fqdns = [
    "registry.wiz.io",                                # sensor image pulls
    "auth.app.wiz.io",                                # sensor auth
    "agent.${var.wiz_dc}.app.wiz.io",                 # definitions / logs / detections
    "prod-${var.wiz_dc}-sensor.app.wiz.io",           # tenant comms
    "prod-${var.wiz_dc}-sensor-pubsub.app.wiz.io",    # RTC channel
    "agent-si.${var.wiz_dc}.app.wiz.io",              # static-IP mode (optional)
    "prod-${var.wiz_dc}-sensor-si.app.wiz.io",        # static-IP mode (optional)
    "prod-${var.wiz_dc}-sensor-pubsub-si.app.wiz.io", # static-IP mode (optional)
  ]
}

output "wiz_sensor_required_fqdns" {
  value       = local.wiz_sensor_required_fqdns
  description = "FQDNs the Runtime Sensor needs outbound access to. Already reachable via the wide-open egress on aws_security_group.backend; surfaced here so a Network Firewall or proxy rule can consume the list directly."
}
