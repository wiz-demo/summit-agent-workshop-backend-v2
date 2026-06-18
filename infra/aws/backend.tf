terraform {
  backend "s3" {
    bucket       = "tf-state-800618367342-us-east-1"
    key          = "summit-agent-workshop/infra/aws/terraform.tfstate"
    region       = "us-east-1"
    profile      = "dev-product-cto-play"
    encrypt      = true
    use_lockfile = true
  }
}
