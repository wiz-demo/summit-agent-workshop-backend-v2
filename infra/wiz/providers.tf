# =============================================================================
# AWS Provider Configuration
# =============================================================================

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

# =============================================================================
# Wiz v2 Provider Configuration
# =============================================================================
#
# Provider source: tf.app.wiz.io/wizsec/wiz-v2 (private registry).
# `terraform login tf.app.wiz.io` may be required before first init, depending
# on the registry's auth setup.

provider "wiz-v2" {
  env           = var.wiz_env
  client_id     = var.wiz_client_id
  client_secret = var.wiz_client_secret
}

provider "wiz-v2" {
  alias         = "tenant1"
  env           = var.wiz_env_t1
  client_id     = var.wiz_client_id_t1
  client_secret = var.wiz_client_secret_t1
}

provider "wiz-v2" {
  alias         = "tenant2"
  env           = var.wiz_env_t2
  client_id     = var.wiz_client_id_t2
  client_secret = var.wiz_client_secret_t2
}
