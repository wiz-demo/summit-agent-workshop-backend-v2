provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "agent-workshop-wiz-connector"
      Environment = terraform.workspace
      ManagedBy   = "Terraform"
      owner       = var.owner
      extend      = "true"
    }
  }
}

provider "wiz-v2" {
  alias         = "tenant1"
  env           = var.wiz_env_t1
  client_id     = var.wiz_client_id_t1
  client_secret = var.wiz_client_secret_t1
}

# Tenant 2 provider disabled — all tenant 2 resources are commented out.
# provider "wiz-v2" {
#   alias         = "tenant2"
#   env           = var.wiz_env_t2
#   client_id     = var.wiz_client_id_t2
#   client_secret = var.wiz_client_secret_t2
# }
