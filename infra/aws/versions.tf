terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }

  backend "s3" {
    bucket       = "tf-state-800618367342-us-east-1"
    key          = "summit-agent-workshop/infra/aws/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "dev-product-cto-play"
  }
}
