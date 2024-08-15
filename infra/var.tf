variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
  default     = "my-static-website-bucket"
}

variable "naming_prefix" {
  description = "A prefix for naming resources."
  type        = string
  default     = "myapp"
}

variable "common_tags" {
  description = "A map of tags to be applied to resources."
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "amplifier"
  }
}

variable "source_files" {
  description = "The local directory containing files to be uploaded to the S3 bucket."
  type        = string
  default     = "./webfiles"
}

variable "s3_bucket_id" {
  description = "The ID of the S3 bucket to use with CloudFront."
  type        = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 bucket."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution."
  type        = string
}

# variable "bucket_id" {
#   description = "The ID of the S3 bucket to apply the policy to."
#   type        = string
# }
