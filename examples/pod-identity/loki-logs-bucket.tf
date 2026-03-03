# S3 bucket for Loki chunks and index (created by this example; IAM wired via module.eks s3_access)
resource "aws_s3_bucket" "loki_logs" {
  bucket = "loki-logs-geonet-dev"

  tags = merge(local.tags, {
    Name = "loki-logs-geonet-dev"
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
