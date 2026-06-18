terraform {
  backend "s3" {
    bucket       = "summit-workshop-tfstate-975800360817"
    key          = "aws/terraform.tfstate"
    region       = "us-east-1"
    profile      = "summit-workshop"
    encrypt      = true
    use_lockfile = true
  }
}
