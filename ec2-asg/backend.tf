terraform {
  backend "s3" {
    bucket         = "terraform-backend-buck-ssm-test"
    region         = "us-east-2"
    key            = "ec2-res/terraform.tfstate"
    #dynamodb_table = "Lock-Files"
    encrypt = true
  }
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source = "hashicorp/aws"
    }
  }
}