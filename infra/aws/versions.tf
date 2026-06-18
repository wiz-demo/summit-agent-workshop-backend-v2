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
}
