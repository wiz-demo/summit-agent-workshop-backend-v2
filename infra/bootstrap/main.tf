# Shared S3 bucket holding remote state for every root module in this repo.
# Apply this module ONCE with local state, then wire each consuming module's
# backend "s3" block to the bucket below. State locking is handled natively
# via `use_lockfile = true` in the consumers' backend blocks (TF >= 1.10),
# so no DynamoDB table is required.

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.id
  description = "Bucket name to wire into each module's backend \"s3\" block."
}
