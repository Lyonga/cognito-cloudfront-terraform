resource "aws_cognito_user_pool" "app_cognito_user_pool" {
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
    minimum_length = 6
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

resource "aws_cognito_user_pool_client" "app_cognito_user_pool_client" {
  name         = "app_cognito_user_pool_client"
  user_pool_id = aws_cognito_user_pool.app_cognito_user_pool.id

  prevent_user_existence_errors = "ENABLED"
  supported_identity_providers  = ["COGNITO"]
  generate_secret = false
  refresh_token_validity = 90
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}


resource "aws_cognito_user_pool_domain" "app_cognito_user_pool_domain" {
domain       = "app"
user_pool_id = aws_cognito_user_pool.app_cognito_user_pool.id
}


resource "aws_cognito_user" "example" {
user_pool_id = aws_cognito_user_pool.example.id
username     = "example"

attributes = {
terraform      = true
foo            = "bar"
email          = "no-reply@hashicorp.com"
email_verified = true
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

block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
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
bucket = var.aws_s3_bucket.s3-static-website.id
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
    locations        = ["IN", "US", "CA"]
    }
}

viewer_certificate {
    cloudfront_default_certificate = true
}

tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-cloudfront"
})
}

data "aws_iam_policy_document" "s3_bucket_policy" {
statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arn}/*"]
    principals {
    type        = "Service"
    identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
    test     = "StringEquals"
    variable = "AWS:SourceArn"
    values   =  aws_cloudfront_distribution.cf-dist.arn
    }
}
}

resource "aws_s3_bucket_policy" "static_site_bucket_policy" {
bucket = aws_s3_bucket.s3-static-website.id
policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

