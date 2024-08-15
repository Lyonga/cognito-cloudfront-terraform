variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
  default     = "amplifier-demo-sandbox-bucket"
}

variable "naming_prefix" {
  description = "A prefix for naming resources."
  type        = string
  default     = "amplifier-app"
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

variable "cognito_users" {
  description = "Map of Cognito users to create with their attributes"
  type = map(map(string))
  default = {
    "usertwo@example.com" = {
      email_verified = "true"
      email          = "usertwo@example.com"
    }
    "userone@example.com" = {
      email_verified = "true"
      email          = "userone@example.com"
    },
    "userthree@example.com" = {
      email_verified = "true"
      email          = "userthree@example.com"
    }
  }
}

variable "amplifier_vpclinkname" {
  description = "A prefix for naming resources."
  type        = string
  default     = "amplifier-link"
}

variable "nlb_arn" {
  description = "A prefix for naming resources."
  type        = string
  default     = ""
}

variable "app_port" {
  type = number
  description = "Application port number"
  default     = 80
}

variable "public_subnet_ids" {
  type = list(string)
  description = "IDs for private subnets"
  default = [subnet-836b2f8d, subnet-fef97b98]
}

variable "vpc_id" {
  type = string 
  description = "The id for the VPC where the ECS container instance should be deployed"
  default = "vpc-8f8856f2"
}

variable "environment" {
  type = string
  description = "amplifier tes environment"
  default = "dev"
}