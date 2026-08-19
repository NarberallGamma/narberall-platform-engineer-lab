resource "aws_s3_bucket" "export" {
  bucket = "example-export-prod"
}

resource "aws_s3_bucket_public_access_block" "export" {
  bucket                  = aws_s3_bucket.export.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "export" {
  bucket = aws_s3_bucket.export.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_user" "export" {
  name = "export-job"
}

resource "aws_iam_user_policy" "export" {
  name = "export-job-s3"
  user = aws_iam_user.export.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.export.arn, "${aws_s3_bucket.export.arn}/*"]
      }
    ]
  })
}
