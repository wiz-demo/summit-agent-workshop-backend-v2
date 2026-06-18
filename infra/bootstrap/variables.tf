variable "region" {
  type        = string
  description = "AWS region for the state bucket. Must be SCP-allowed."
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-2"], var.region)
    error_message = "region must be us-east-1, us-east-2, or us-west-2 (SCP-allowed)."
  }
}

variable "aws_profile" {
  type        = string
  description = "AWS profile mapping to the target account."
}

variable "owner" {
  type        = string
  description = "Value for the mandatory owner tag."
}

variable "state_bucket_name" {
  type        = string
  description = "Globally-unique S3 bucket name for Terraform state."
  default     = "tf-state-800618367342-us-east-1"
}
