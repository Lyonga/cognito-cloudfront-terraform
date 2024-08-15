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

