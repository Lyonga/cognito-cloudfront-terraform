variable "tags" {
  description = "A list of tag blocks. Each element should have keys named key, value, etc."
  type        = map(string)
  default = {
      Environment = "dev"
      Project     = "Traverse"
      Service-Name = "infrastructure"
      created_by  = "terraform"
  }
}

variable "ostype" {
  description = "Specify the operating system type ('linux' or 'windows')."
  type        = string
  default     = "linux"
}

variable "agent_list" {
  description = "Comma-separated list of agents to install."
  type        = string
  default     = "CrowdStrike,Rapid7,Syxsense"
}

variable "target_tag_key" {
  description = "Tag key used to identify target instances."
  type        = string
  default     = "AGENT_DEPLOY"
}

variable "target_tag_value" {
  description = "Tag value used to identify target instances."
  type        = string
  default     = "TRUE"
}

variable "bucketname" {
  description = "Name of the S3 bucket containing the agent installers."
  type        = string
  default     = "charlyo-mini"
}

variable "schedule_rate_expression" {
  description = "SSM association application cycle (minimum 30 minutes)."
  type        = string
  default     = "30 minutes"
}

variable "max_concurrency" {
  description = "Maximum percentage of targets SSM should handle concurrently."
  type        = string
  default     = "100%"
}

variable "max_errors" {
  description = "Error threshold percentage before stopping."
  type        = string
  default     = "25%"
}

variable "automation_role_name" {
  description = "Name of the IAM role for Automation."
  type        = string
  default     = "ssm-install-role"
}

variable "stack_name" {
  description = "Name of stack, change to suit your naming style"
  type        = string
  default     = "dev-test-resiliency"
}

variable "environment_name" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "environment_scp_tag" {
  description = "Required tag value for SCP"
  type        = string
  default     = "dev"
}

variable "deployment_type" {
  description = "Specify 'generic' for standalone EC2 instance or 'cluster' for ASG with ELB."
  type        = string
  default     = "generic"
  validation {
    condition     = contains(["generic", "cluster"], var.deployment_type)
    error_message = "Must be 'generic' or 'cluster'."
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-8f8856f2"
}

variable "vpc_ec2_subnet1" {
  description = "EC2 subnet 1 (AZ-a)"
  type        = string
  default     = "subnet-5a75fc7b"
}

variable "vpc_ec2_subnet2" {
  description = "EC2 subnet 2 (AZ-c)"
  type        = string
  default     = "subnet-ec81d3a1"
}

variable "subnet_ids" {
  description = "EC2 subnet 2 (AZ-c)"
  type        = string
  default     = ["subnet-5a75fc7b", "subnet-ec81d3a1"]
}

variable "duo_radius_port" {
  description = "The port for inbound RADIUS communication into the Duo Proxy. Defaults to 1645."
  type        = number
  default     = 1645
}

variable "ssm_key" {
  description = "Name of parameter store which contains the json configuration of CWAgent."
  type        = string
  default     = "/ec2/resiliency/cloudwatch/agent"
}

variable "ec2_image_id" {
  description = "AMI ID"
  type        = string
  default     = "ami-0f908ade2d5734ce2"
}

variable "ec2_instance_type" {
  description = "EC2 InstanceType"
  type        = string
  default     = "t2.micro"
}

variable "instance_name" {
  description = "The name of the instance"
  type        = string
  default     = "myTestEC2Instance"
}

variable "volume" {
  description = "The volume name or device "
  type        = string
  default     = "/dev/xvda"
}

variable "warning_sns" {
  description = "SNS topic for near-critical alerts."
  type        = string
  default     = "warning-sns-topic"
}

variable "critical_sns" {
  description = "SNS topic for critical alerts."
  type        = string
  default     = "critical-sns-topic"
}

variable "ec2_instance_key_name" {
  description = "EC2 SSH Key"
  type        = string
  default     = "NGL-USE2-Infra"
}

variable "availability_zone" {
  description = "The AZ for deployment"
  type        = string
  default     = "us-east-2b"
}

variable "region" {
  description = "The AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "ec2_instance_tag_name" {
  description = "EC2 Tag Name"
  type        = string
  default     = "AAE2-IP-VSA01"
}

variable "ec2_autoscale_min_size" {
  description = "AutoScalingGroup MinSize"
  type        = number
  default     = 1
}

variable "ec2_autoscale_max_size" {
  description = "AutoScalingGroup MaxSize"
  type        = number
  default     = 4
}

variable "ec2_autoscale_desired_capacity" {
  description = "AutoScalingGroup DesiredCapacity"
  type        = number
  default     = 1
}

variable "ad_directory_id" {
  description = "Active Directory ID"
  type        = string
  default     = "NGL"
}

variable "ad_directory_name" {
  description = "Active Directory Name"
  type        = string
  default     = "nglic.local"
}

variable "ad_dns_ip_address1" {
  description = "Active Directory DNS 1"
  type        = string
  default     = "10.49.2.10"
}

variable "ad_dns_ip_address2" {
  description = "Active Directory DNS 2"
  type        = string
  default     = "10.49.1.10"
}

variable "bucket_name" {
  description = "S3 storage name"
  type        = string
  default     = "ngl-ssm-sec-agent-install-dev"
}

variable "object_prefix" {
  description = "CW agent location"
  type        = string
  default     = "agent"
}

variable "email_address" {
  description = "Enter Your Email Address."
  type        = string
  default     = "c.lyonga03@yahoo.com"
}

variable "path" {
  description = "Provide path"
  type        = string
  default     = "/"
}

variable "fstype" {
  description = "Choose fstype - ext4 or xfs"
  type        = string
  default     = "ext4"
  validation {
    condition     = contains(["ext4", "xfs", "btrfs"], var.fstype)
    error_message = "You must specify ext4, xfs, or btrfs."
  }
}

variable "enable_efs_file_system" {
  description = "Enable EFS usage"
  default     = true
}

variable "efs_file_system_performance_mode" {
  description = "The file system performance mode. Can be either 'generalPurpose' or 'maxIO' (Default: 'generalPurpose')."
  default     = "generalPurpose"
}

variable "efs_file_system_encrypted" {
  description = "If true, the disk will be encrypted."
  default     = true
}

variable "efs_file_system_kms_key_id" {
  description = "The ARN for the KMS encryption key. When specifying kms_key_id, encrypted needs to be set to true."
  default     = ""
}

variable "efs_file_system_creation_token" {
  description = "used as reference when creating the Elastic File System to ensure idempotent file system creation."
  default     = "data-science-efs"
}

variable "efs_file_system_throughput_mode" {
  description = "When using provisioned, also set provisioned_throughput_in_mibps."
  default     = "bursting"
}

variable "efs_file_system_lifecycle_policy" {
  description = "(Optional) A file system lifecycle policy object"
  default     = []
}

# AWS EFS mount targets
variable "enable_efs_mount_target" {
  description = "Enable EFS mount target usage"
  default     = false
}

variable "efs_mount_target_subnet_ids" {
  description = "The ID of the subnets to add the mount target in."
  default     = ["subnet-0b881a78934ddb180", "subnet-0b07f65916df83ea9", "subnet-045c9c37f55ee80de"]
}


variable "efs_mount_target_ip_address" {
  description = "The address (within the address range of the specified subnet) at which the file system may be mounted via the mount target."
  default     = "10.30.57.241"
}

# AWS EFS file system policy
variable "enable_efs_file_system_policy" {
  description = "Enable EFS file system policy usage"
  default     = true
}

variable "efs_file_system_policy_file_system_id" {
  description = "The ID of the EFS file system."
  default     = ""
}

variable "efs_file_system_policy_policy" {
  description = "(Required) The JSON formatted file system policy for the EFS file system. see Docs for more info."
  default     = null
}

#EFS security group
variable "inbound_tcp_port" {
  default     = [2049]
}

variable "outbound_tcp_port" {
  default     = [2049]
}

variable "Environment" {
  default     = "dev"
}

variable "team" {
  default     = "EIS"
}
variable "ec2-association-name" {
  default     = "ec2-instance-association"
}
variable "asg-association-name" {
  default     = "asg-instance-association"
}

variable "falcon_client_id_parameter_name" {
  type        = string
  description = "Name of the SSM parameter storing the Falcon Client ID"
  default     = "/my/crowdstrike/FalconClientID"
}

variable "falcon_client_secret_parameter_name" {
  type        = string
  description = "Name of the SSM parameter storing the Falcon Client Secret"
  default     = "/my/crowdstrike/FalconClientSecret"
}

variable "trusted_ip_address" {
  type        = string
  description = "The CIDR block to allow RDP access"
  default     = "1.2.3.4/32"
}

variable "ami_parameter_name" {
  type        = string
  description = "Parameter name for the Windows AMI in SSM"
  default     = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
}

variable "tag_key" {
  type    = string
  default = "AutoInstallAgents"
}

variable "tag_value" {
  type    = string
  default = "true"
}

variable "crowdstrike_exe_s3_url" {
  type        = string
  description = "S3 path or presigned URL to the CrowdStrike EXE installer"
    default     = "https://s3.us-east-2.amazonaws.com/crowdstrike-windows-agent-install/FalconSensor.exe"
}

variable "duo_msi_s3_url" {
  type        = string
  description = "S3 path or presigned URL to the Duo MSI installer"
  default     = "https://s3.us-east-2.amazonaws.com/duo-windows-agent-install/duo_agent_v2.7.1"
}

variable "rapid7_msi_s3_url" {
  type        = string
  description = "S3 path or presigned URL to the Rapid7 MSI installer"
  default     = "https://s3.us-east-2.amazonaws.com/rapid7-windows-agent-install/Rapid7-Agent-v5.24"
}