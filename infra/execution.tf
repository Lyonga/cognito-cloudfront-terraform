resource "aws_iam_role_policy" "main_ecs_tasks" {
    name = "main_ecs_tasks-${var.name}-policy"
    role = aws_iam_role.main_ecs_tasks.id
  
    policy = <<EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "s3:Get*",
                  "s3:List*"
              ],
              "Resource": ["*"]
          },
          {
              "Effect": "Allow",
              "Resource": [
                "*"
              ],
              "Action": [
                  "ecr:GetAuthorizationToken",
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:BatchGetImage",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents",
                  "logs:CreateLogGroup",  // Added permission
                  "logs:DescribeLogStreams",
                  "logs:DescribeLogGroups", // Ensure this permission is included
                  "events:PutRule",
                  "events:PutTargets",
                  "events:DescribeRule",
                  "events:ListTargetsByRule",
                  "ecs:DescribeServices",
                  "ecs:UpdateService",
                  "cloudwatch:DescribeAlarms",
                  "cloudwatch:PutMetricAlarm",
                  "ecs:RunTask",
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:Describe*",
                  "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                  "elasticloadbalancing:DeregisterTargets",
                  "elasticloadbalancing:Describe*",
                  "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                  "elasticloadbalancing:RegisterTargets"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "kms:Decrypt",
                  "secretsmanager:GetSecretValue"
              ],
              "Resource": [
                  "*"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ec2:DescribeTags",
                  "ecs:CreateCluster",
                  "ecs:DeregisterContainerInstance",
                  "ecs:DiscoverPollEndpoint",
                  "ecs:Poll",
                  "ecs:RegisterContainerInstance",
                  "ecs:StartTelemetrySession",
                  "ecs:UpdateContainerInstancesState",
                  "ecs:Submit*",
                  "ecr:GetAuthorizationToken",
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:BatchGetImage",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": "ecs:TagResource",
              "Resource": "*",
              "Condition": {
                  "StringEquals": {
                      "ecs:CreateAction": [
                          "CreateCluster",
                          "RegisterContainerInstance"
                      ]
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": "iam:PassRole",
              "Resource": [
                  "*"
              ],
              "Condition": {
                  "StringLike": {
                      "iam:PassedToService": "ecs-tasks.amazonaws.com"
                  }
              }
          },
          {
              "Effect": "Allow",
              "Action": "ecs:TagResource",
              "Resource": "*",
              "Condition": {
                  "StringEquals": {
                      "ecs:CreateAction": [
                          "RunTask"
                      ]
                  }
              }
          }
      ]
  }
  EOF
  }
  
  resource "aws_iam_role_policy_attachment" "main_ecs_tasks_ecs_policy" {
    role       = aws_iam_role.main_ecs_tasks.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }
  