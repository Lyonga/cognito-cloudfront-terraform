resource "aws_config_config_rule" "non_approved_ami" {
  name        = "non-approved-ami-rule"
  description = "Check if EC2 instances are launched using non-approved AMIs."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.check_ami.arn  # Reference to your Lambda function

    source_details {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"  # Valid type for CUSTOM_LAMBDA
    }
  }
  

  input_parameters = jsonencode({
    "approved_ami_list" = ["ami-12345678", "ami-87654321"]  # Your approved AMI IDs
  })

  scope {
    compliance_resource_types = ["AWS::EC2::Instance"]
  }
}



# Archive the Python file into a zip
data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../lambda/test.py"
  output_path = "${path.module}/../lambda/test.zip"
}


resource "aws_lambda_function" "check_ami" {
  filename         = data.archive_file.lambda_package.output_path  # Points to the zip archive
  function_name    = "terminate_non_compliant_instance"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "test.lambda_handler"  # Specify the Python file and function name
  runtime          = "python3.8"

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_terminate_ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  role   = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:TerminateInstances",
          "ec2:DescribeInstances"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sns:Publish"
        ],
        Effect   = "Allow",
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}


resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "security-team@example.com"  # Replace with your team's email
}
