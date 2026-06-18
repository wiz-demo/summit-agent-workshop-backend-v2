terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    wiz-v2 = {
      source = "tf.app.wiz.io/wizsec/wiz-v2"
    }
  }

  backend "s3" {
    bucket       = "tf-state-800618367342-us-east-1"
    key          = "summit-agent-workshop/infra/wiz/wiz-iam/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "dev-product-cto-play"
  }
}
