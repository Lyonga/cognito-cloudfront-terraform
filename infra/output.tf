output "bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.s3-static-website.arn
}

output "bucket_id" {
  description = "The ID of the S3 bucket."
  value       = aws_s3_bucket.s3-static-website.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.cf-dist.arn
}

output arn {
  value = aws_ecs_cluster.main.arn
}

output id {
  value = aws_ecs_cluster.main.id
}