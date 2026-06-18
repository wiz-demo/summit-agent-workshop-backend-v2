provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      owner   = var.owner
      project = "agent-workshop"
      extend  = "true"
    }
  }
}
