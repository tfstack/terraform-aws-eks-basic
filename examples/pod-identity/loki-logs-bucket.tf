# S3 bucket for Loki chunks and index (created by this example; IAM wired via module.eks s3_access).
# Bucket name uses cluster_name so it is unique in your account and avoids a hard-coded global S3 name.
resource "aws_s3_bucket" "loki_logs" {
  bucket = "${var.cluster_name}-loki-logs"

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-loki-logs"
  })
}

resource "aws_s3_bucket_versioning" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
