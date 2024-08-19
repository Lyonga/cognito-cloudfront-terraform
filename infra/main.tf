resource "aws_cognito_user_pool" "amplifier_cognito_user_pool" {
  name = "app_cognito_user_pool"

  username_attributes         = ["email"]
  auto_verified_attributes = ["email"]
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
  password_policy {
    minimum_length = 8
    require_lowercase = true
    require_numbers = true
    require_symbols = true
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject = "Account Confirmation"
    email_message = "Your confirmation code is {####}"
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
}

resource "aws_cognito_user_pool_client" "amplifiercognito_user_pool_client" {
  name         = "app_cognito_user_pool_client"
  user_pool_id = aws_cognito_user_pool.amplifier_cognito_user_pool.id

  prevent_user_existence_errors = "ENABLED"
  supported_identity_providers  = ["COGNITO"]
  generate_secret = false
  refresh_token_validity = 90
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  # callback_urls = ["https://your-app.com/callback"]
  # logout_urls = ["https://your-app.com/logout"]
}


resource "aws_cognito_user_pool_domain" "app_cognito_user_pool_domain" {
domain       = "amplifier"
user_pool_id = aws_cognito_user_pool.amplifier_cognito_user_pool.id
}


resource "aws_cognito_user" "amplifier" {
user_pool_id = aws_cognito_user_pool.amplifier_cognito_user_pool.id
username     = "charles.lyonga03@gmail.com"

attributes = {
#terraform      = true
#foo            = "bar"
email          = "charles.lyonga03@gmail.com"
email_verified = true
}
}
resource "aws_cognito_user" "amplifier_users" {
  for_each    = var.cognito_users
  user_pool_id = aws_cognito_user_pool.amplifier_cognito_user_pool.id
  username     = each.key

  attributes = {
    email          = each.value.email
    email_verified = each.value.email_verified
  }
}

# S3 static website bucket
resource "aws_s3_bucket" "s3-static-website" {
bucket = var.bucket_name
tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-s3-bucket"
})
}

# S3 public access settings
resource "aws_s3_bucket_public_access_block" "static_site_bucket_public_access" {
bucket = aws_s3_bucket.s3-static-website.id
block_public_acls       = false
block_public_policy     = false
ignore_public_acls      = false
restrict_public_buckets = false
}

# S3 bucket static website configuration
resource "aws_s3_bucket_website_configuration" "static_site_bucket_website_config" {
bucket = aws_s3_bucket.s3-static-website.id

index_document {
    suffix = "index.html"
}

error_document {
    key = "error.html"
}
}

# Upload files to S3 Bucket 
resource "aws_s3_object" "provision_source_files" {
bucket = aws_s3_bucket.s3-static-website.id

# webfiles/ is the Directory contains files to be uploaded to S3
for_each = fileset("${var.source_files}/", "**/*.*")

key          = each.value
source       = "${var.source_files}/${each.value}"
content_type = each.value
}


data "aws_s3_bucket" "selected_bucket" {
bucket = aws_s3_bucket.s3-static-website.id
}

# Create AWS Cloudfront distribution
resource "aws_cloudfront_origin_access_control" "cf-s3-oac" {
name                              = "CloudFront S3 OAC"
description                       = "CloudFront S3 OAC"
origin_access_control_origin_type = "s3"
signing_behavior                  = "always"
signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cf-dist" {
enabled             = true
default_root_object = "index.html"

origin {
    domain_name              = data.aws_s3_bucket.selected_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.s3-static-website.id
    origin_access_control_id = aws_cloudfront_origin_access_control.cf-s3-oac.id
}

default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.s3-static-website.id
    forwarded_values {
    query_string = false

    cookies {
        forward = "none"
    }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
}

price_class = "PriceClass_All"

restrictions {
    geo_restriction {
    restriction_type = "whitelist"
    locations        = ["IN", "US"]
    }
}

viewer_certificate {
    cloudfront_default_certificate = true
}
web_acl_id = aws_wafv2_web_acl.cf_web_acl.arn
tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-cloudfront"
})
}
#####WAF
resource "aws_wafv2_web_acl" "cf_web_acl" {
  name        = "cf-web-acl"
  description = "Basic WAF for CloudFront"
  scope       = "CLOUDFRONT" # Required for CloudFront distributions
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cfWebAcl"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
}
resource "aws_s3_bucket_policy" "static_site_bucket_policy" {
bucket = aws_s3_bucket.s3-static-website.id
#policy = data.aws_iam_policy_document.s3_bucket_policy.json
policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3-static-website.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cf-dist.arn
          }
        }
      }
    ]
  })
}

################################
resource "aws_s3_bucket" "amplifier_media_bucket" {
bucket = "${var.bucket_name}-amplifier_media_bucket"
tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-s3-bucket"
})
}

# S3 public access settings
resource "aws_s3_bucket_public_access_block" "amplifier_media_bucket_public_access" {
bucket = aws_s3_bucket.amplifier_media_bucket.id
block_public_acls       = false
block_public_policy     = false
ignore_public_acls      = false
restrict_public_buckets = false
}

# CORS configuration for S3 Bucket
resource "aws_s3_bucket_cors_configuration" "amplifier_media_bucket_cors" {
  bucket = aws_s3_bucket.amplifier_media_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    allowed_origins = ["https://${aws_cloudfront_distribution.cf-dist.domain_name}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Bucket Policy to allow CloudFront to access the media bucket
resource "aws_s3_bucket_policy" "amplifier_media_bucket_policy" {
  bucket = aws_s3_bucket.amplifier_media_bucket.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.amplifier_media_bucket.id}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "${aws_cloudfront_distribution.cf-dist.arn}"
                }
            }
        }
    ]
}
EOF
}

# resource "aws_cloudwatch_log_group" "ecs_log_group" {
#   name              = "/ecs/amplifier/awslog"
#   retention_in_days = 7 # Adjust the retention period as needed
# }