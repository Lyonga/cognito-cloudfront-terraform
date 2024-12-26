resource "aws_iam_role" "ec2_instance_role" {
  name               = "myEC2Role"
  description        = "Instance role to attach to EC2 instances"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.Environment}-ec2-role-${var.team}"
    },
    var.tags
  )
}

resource "aws_iam_policy" "ec2_instance_policy" {
  name        = "ec2role_policy"
  description = "Managed policy for EC2 instances"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject*", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          "arn:aws:s3:::${var.bucketname}/",
          "arn:aws:s3:::${var.bucketname}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:CreateLogGroup", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:*", "cloudwatch:DescribeAlarms", "cloudwatch:GetMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_instance_policy_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_instance_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2instanceprofile"
  role = aws_iam_role.ec2_instance_role.name
} 

resource "aws_ssm_document" "my_ssm_document" {
  name          = "myssmdocument"
  document_type = "Automation"
  content       = jsonencode({
    schemaVersion = "1.2"
    description   = "Join instances to an AWS Directory Service domain."
    parameters    = {
      directoryId = {
        type        = "String"
        description = "(Required) The ID of the AWS Directory Service directory."
      }
      directoryName = {
        type        = "String"
        description = "(Required) The name of the directory; e.g., test.example.com."
      }
      dnsIpAddresses = {
        type          = "StringList"
        default       = []
        description   = "(Optional) IP addresses of DNS servers in the directory."
        allowedPattern = "((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
      }
    }
    runtimeConfig = {
      "aws:domainJoin" = {
        properties = {
          directoryId    = "{{ directoryId }}"
          directoryName  = "{{ directoryName }}"
          dnsIpAddresses = "{{ dnsIpAddresses }}"
        }
      }
    }
  })
}


resource "aws_security_group" "web_app_sg" {
  name_prefix        = "webapp-sg-${var.environment_name}-"
  description        = "Allow HTTP/HTTPS and SSH inbound traffic"
  vpc_id             = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name           = "${var.environment_name} WebAppSecurityGroup"
    Project        = "infrastructure-tools"
    Environment    = var.environment_scp_tag
    Service-Name   = "infrastructure"
  }
}

resource "aws_launch_template" "ec2_instance_launch_template" {
  name                  = "NGL-AAE2-IP-LaunchTemplate"
  image_id             = var.ec2_image_id
  instance_type        = var.ec2_instance_type
  key_name             = var.ec2_instance_key_name
  instance_initiated_shutdown_behavior = "terminate"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  user_data = base64encode(<<EOT
    <script>
    powershell -Command "C:\'Program Files'\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c ssm:${var.ssm_key} -s"
    powershell -Command "Start-Sleep -Seconds 30"
    </script>
    EOT
    )



#   user_data = base64encode(<<EOT
#     <script>
#     powershell -Command "C:\'Program Files'\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c ssm:${var.ssm_key} -s"
#     cfn-init.exe -v --stack ${var.stack_id} --resource EC2InstanceLaunchTemplate --region ${var.region} --configsets default
#     powershell -Command "Start-Sleep -Seconds 30"
#     cfn-signal.exe -e %errorlevel% --stack ${var.stack_id} --resource AutoScalingGroup --region ${var.region}
#     </script>
#     EOT
#     )

  tag_specifications {
    resource_type = "instance"
    tags = merge(
    {
      Name = "${var.Environment}-template-${var.team}"
    },
    var.tags
    )
  }

  metadata_options {
    http_tokens               = "required"
    http_endpoint             = "enabled"
    http_put_response_hop_limit = 1
  }
}

resource "aws_instance" "generic" {
  ami                         = aws_launch_template.ec2_instance_launch_template.image_id
  instance_type               = aws_launch_template.ec2_instance_launch_template.instance_type
  subnet_id                   = var.vpc_ec2_subnet1
  availability_zone           = var.availability_zone
  key_name                    = aws_launch_template.ec2_instance_launch_template.key_name
  iam_instance_profile        = aws_launch_template.ec2_instance_launch_template.iam_instance_profile[0].name
  launch_template {
    id      = aws_launch_template.ec2_instance_launch_template.id
    version = aws_launch_template.ec2_instance_launch_template.latest_version
  }
  ebs_optimized = true
  security_groups = [
    aws_security_group.web_app_sg.id
  ]
  tags = merge(
    {
      Name = "${var.Environment}-ec2-instance-${var.team}"
    },
    var.tags
  )

}

resource "aws_ec2_tag" "tags" {
  resource_id = aws_launch_template.ec2_instance_launch_template.id
  key         = "Environment"
  value       = var.environment_scp_tag
}

resource "aws_cloudwatch_metric_alarm" "ec2_instance_auto_recovery" {
  alarm_name                = "EC2AutoRecoveryAlarm"
  alarm_description         = "Automatically recover EC2 instance on failure"
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  statistic                 = "Minimum"
  period                    = 60
  evaluation_periods        = 1
  threshold                 = 1
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_actions             = ["arn:aws:automate:${var.region}:ec2:recover"]
  dimensions = {
    InstanceId = aws_launch_template.ec2_instance_launch_template.id
  }
}

# resource "aws_security_group" "web_app_sg" {
#   name        = "webapp-security-group-${var.Environment}"
#   description = "Allow HTTP/HTTPS and SSH inbound and outbound traffic"
#   vpc_id      = var.vpc_id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 3389
#     to_port     = 3389
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(
#     {
#       Name = "${var.Environment}-ec2-sg-${var.team}"
#     },
#     var.tags
#     )
# }

resource "aws_ssm_association" "domain_join" {
  name = "${var.ec2-association-name}"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.generic.id]
  }

  parameters = {
    directoryId    = [var.ad_directory_id]
    directoryName  = [var.ad_directory_name]
    dnsIpAddresses = [var.ad_dns_ip_address1, var.ad_dns_ip_address2]
  }

  association_name = "DomainJoinAssociation"
  max_concurrency  = "1"
  max_errors       = "0"
  compliance_severity = "CRITICAL"
}

resource "aws_launch_template" "asg_instance_launch_template" {
  name          = "NGL-AAE2-IP-VSA01AutoScaling"
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_instance_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = element(var.subnet_ids, 0)
    security_groups             = [aws_security_group.web_server.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      delete_on_termination = true
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
    {
      Name = "${var.Environment}-asg-template-${var.team}"
    },
    var.tags
    )
  }
}

resource "aws_autoscaling_group" "ec2_asg" {
  launch_template {
    id      = aws_launch_template.asg_instance_launch_template.id
    version = "$Latest"
  }

  #vpc_zone_identifier       = var.subnet_ids
  vpc_zone_identifier = [
    var.vpc_ec2_subnet1,
    var.vpc_ec2_subnet2
  ]
  min_size                  = var.ec2_autoscale_min_size
  max_size                  = var.ec2_autoscale_max_size
  desired_capacity          = var.ec2_autoscale_desired_capacity
  health_check_type         = "EC2"
  health_check_grace_period = 900
  lifecycle {
    create_before_destroy = true
  }
  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance"
  ]
  target_group_arns = [aws_lb_target_group.ec2_target_group.arn]

  tag {
    key                 = "Name"
    value               = "${var.environment_name}-DomainJoin"
    propagate_at_launch = true
  }
}

# Scaling Policies, CloudWatch Alarms, etc. (cluster scenario)
########################################
resource "aws_autoscaling_policy" "cluster_cpu_policy" {
  name                  = "${var.stack_name}-scaling-out-Policy"
  policy_type           = "TargetTrackingScaling"
  adjustment_type       = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}

resource "aws_autoscaling_policy" "scaling_policy" {
  name                  = "${var.stack_name}-scaling-in-Policy"
  adjustment_type       = "ChangeInCapacity"
  scaling_adjustment    = 1
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "${var.stack_name}-cpuHighAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm if CPU > 80%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scaling_policy.arn
  ]
}

resource "aws_security_group" "web_server" {
  name        = "${var.environment_name}-webapp-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.Environment}-ec2-sg-${var.team}"
    },
    var.tags
    )
}

resource "aws_lb" "alb" {
  name               = "ngl-test-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server.id]
  #subnets            = var.subnet_ids
  subnets = length(var.subnet_ids) > 0 ? var.subnet_ids : [var.vpc_ec2_subnet1, var.vpc_ec2_subnet2]

  tags = merge(
    {
      Name = "${var.Environment}-ec2-alb-${var.team}"
    },
    var.tags
    )
}

resource "aws_lb_target_group" "ec2_target_group" {
  name        = "ngl-test-alb-trp"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 5
    matcher             = "200"
    port     = "80"
    protocol = "HTTP"
    path     = "/"
    timeout  = 5
  }

  tags = {
    Name         = "NGL-AAE2-IP-VSA01CloudFormationTG"
    Project      = "infrastructure-tools"
    Environment  = var.environment_name
    Backup       = "true"
    Service-Name = "infrastructure"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_target_group.arn
  }
}

resource "aws_sns_topic" "warning_sns" {
  name = var.warning_sns
}

resource "aws_sns_topic" "critical_sns" {
  name = var.critical_sns
}

resource "aws_sns_topic_subscription" "warning_email" {
  topic_arn = aws_sns_topic.warning_sns.arn
  protocol  = "email"
  endpoint  = var.email_address
}

resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical_sns.arn
  protocol  = "email"
  endpoint  = var.email_address
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_warning" {
  alarm_name                = "CPUAlarmWARNING"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 70
  alarm_description         = "High CPU Usage 70%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm_critical" {
  alarm_name                = "MemoryAlarmCRITICAL"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "mem_used_percent"
  namespace                 = "CWAgent"
  period                    = 900
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "High Memory Usage 90%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_status_alarm_critical" {
  alarm_name                = "InstanceStatusAlarmCRITICAL"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 3
  metric_name               = "StatusCheckFailed_Instance"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "Instance Status Check Failed"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_space_alarm_critical" {
  alarm_name                = "DiskSpaceAlarmCRITICAL"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "disk_used_percent"
  namespace                 = "CWAgent"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 95
  alarm_description         = "Disk Space Usage Over 95%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
    device     = var.volume
    path       = var.path
    fstype     = var.fstype
  }
}

resource "aws_cloudwatch_metric_alarm" "system_status_alert_critical" {
  alarm_name                = "SystemStatusAlertCRITICAL"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "System Status Check Failed"
  alarm_actions             = [aws_sns_topic.critical_sns.arn, "arn:aws:automate:${var.region}:ec2:recover"]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}


resource "aws_ssm_association" "asg_domain_join" {
  name = aws_ssm_document.my_ssm_document.name

  targets {
    key    = "tag:Name"
    values = ["${var.environment_name}-DomainJoin"]
  }

  parameters = {
    directoryId    = var.ad_directory_id
    directoryName  = var.ad_directory_name
    dnsIpAddresses = "${var.ad_dns_ip_address1},${var.ad_dns_ip_address2}" # Join IPs into a string
  }

  max_concurrency     = "1"
  max_errors          = "0"
  compliance_severity = "CRITICAL"
  depends_on = [
    aws_ssm_document.my_ssm_document,
    aws_launch_template.ec2_instance_launch_template
  ]
}


# AWS EFS file system
resource "aws_efs_file_system" "ds_efs_file_system" {
  creation_token   = var.efs_file_system_creation_token
  encrypted        = var.efs_file_system_encrypted
  kms_key_id       = var.efs_file_system_kms_key_id
  performance_mode = var.efs_file_system_performance_mode

  throughput_mode  = var.efs_file_system_throughput_mode
  tags = merge(
    {
      Name = "${var.Environment}-ec2-efs-${var.team}"
    },
    var.tags
    )

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }


}

#--mount target
resource "aws_efs_mount_target" "efs_mount_target" {
  count = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.ds_efs_file_system.id
  subnet_id       = var.efs_mount_target_subnet_ids[count.index]
  #ip_address      = var.efs_mount_target_ip_address
  security_groups = [aws_security_group.efs_security_grp.id]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = []
  }

  depends_on = [
    aws_efs_file_system.ds_efs_file_system
  ]
}
/*
#efs policy
resource "aws_efs_file_system_policy" "efs_policy" {
  file_system_id = aws_efs_file_system.ds_efs_file_system.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "Policy01",
    "Statement": [
        {
            "Sid": "Statement01",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "${aws_efs_file_system.ds_efs_file_system.arn}",
            "Action": [
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "true"
                }
            }
        }
    ]
}
POLICY
}
*/
resource "aws_efs_backup_policy" "data_science_policy" {
  file_system_id = aws_efs_file_system.ds_efs_file_system.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_security_group" "efs_security_grp" {
   name = "${var.Environment}-efs-security-group}"
   description = "Allows inbound efs traffic from ec2"
   vpc_id     =  var.vpc_id
   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
   tags = merge(
    {
      Name = "${var.Environment}-efs-resiliency-${var.team}"
    },
    var.tags
   )
 }
