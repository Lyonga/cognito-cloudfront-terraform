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
  description = "container port number"
  default     = 80
}

variable "public_subnet_ids" {
  type = list(string)
  description = "IDs for public subnets"
  default = ["subnet-836b2f8d", "subnet-fef97b98"]
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

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default = "amplifier-cluster"
}

variable "cluster_tag_name" {
  type        = string
  description = "Name tag for the cluster"
  default     = "amplifier-cluster"
}



variable "name" {
  type        = string
  description = "The name of the application and the family"
  default     = "amplifier-task"
}

variable "fargate_cpu" {
  type = number
  description = "Fargate cpu allocation"
  default = 512
}

variable "fargate_memory" {
  type = number
  description = "Fargate memory allocation"
  default     = 1024
}

variable "app_count" {
  type = number 
  description = "The number of instances of the task definition to place and keep running."
  default = 1
}

variable "vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block range for vpc"
}

variable "private_subnet_cidr_blocks" {
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.4.0/24"]
  description = "CIDR block range for the private subnets"
}

variable "security_group_lb_name" {
  type        = string
  default     = "alb-sg"
  description = "Load Balancer security group name"
}

variable "security_group_lb_description" {
  type        = string
  default     = "controls access to the ALB"
  description = "Load Balancer security group description"
}

variable "security_group_ecs_tasks_name" {
  type        = string
  default     = "ecs-tasks-sg"
  description = "ECS Tasks security group name"
}