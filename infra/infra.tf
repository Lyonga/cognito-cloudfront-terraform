resource "aws_api_gateway_rest_api" "amplifier" {
  name = "amplifier-poc-api"
  description = "API Gateway for amplifier poc application"
}

resource "aws_api_gateway_resource" "amplifier_resource" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  parent_id = aws_api_gateway_rest_api.amplifier.root_resource_id
  path_part = "{proxy+}"  # This defines the catch-all path
}

resource "aws_api_gateway_method" "amplifier_method" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = "ANY" # This allows all HTTP methods (GET, POST, PUT, DELETE, etc.)
  authorization = "NONE"
  api_key_required = false  # Requires API key for access? (implimentation is below, uncomment)
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration with NLB via VPC Link
resource "aws_api_gateway_integration" "app_integration" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method.http_method
  integration_http_method = "ANY"
  type = "HTTP_PROXY"
  uri = "http://${aws_lb.nlb.dns_name}/{proxy}"

  connection_type = "VPC_LINK"
  connection_id = aws_api_gateway_vpc_link.amplifier_vpclink.id
  timeout_milliseconds = 180000
  cache_key_parameters = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Define the OPTIONS method for CORS
resource "aws_api_gateway_method" "amplifier_method_options" {
  rest_api_id   = aws_api_gateway_rest_api.amplifier.id
  resource_id   = aws_api_gateway_resource.amplifier_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.Origin"         = false,
    "method.request.header.Access-Control-Request-Method"  = false,
    "method.request.header.Access-Control-Request-Headers" = false,
  }
}

# Integration response for OPTIONS method (CORS)
resource "aws_api_gateway_integration" "app_integration_options" {
  rest_api_id             = aws_api_gateway_rest_api.amplifier.id
  resource_id             = aws_api_gateway_resource.amplifier_resource.id
  http_method             = aws_api_gateway_method.amplifier_method_options.http_method
  type                    = "MOCK"
  integration_http_method = "OPTIONS"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  passthrough_behavior = "WHEN_NO_MATCH"
}

# Method response for OPTIONS method
resource "aws_api_gateway_method_response" "amplifier_method_response_options" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method_options.http_method
  status_code = "200"


  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true,
  }
}
# Integration Response for OPTIONS method
resource "aws_api_gateway_integration_response" "app_integration_response_options" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method_options.http_method
  status_code = "200"
  depends_on = [
    aws_api_gateway_integration.app_integration_options
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
  }
}


resource "aws_api_gateway_deployment" "dev" {
  depends_on = [
    aws_api_gateway_method.amplifier_method,
    aws_api_gateway_integration.app_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  stage_name  = "dev"

}

###### Below is used for API Key and Usage Plan +===}========>

# resource "aws_api_gateway_usage_plan" "amplifier_usage_plan" {
#   name = "amplifier-usage-plan"
#   api_stages {
#     api_id = aws_api_gateway_rest_api.amplifier.id
#     stage  = aws_api_gateway_deployment.dev.stage_name
#   }
# }

#  ######API Gateway API Key
# resource "aws_api_gateway_api_key" "amplifier_api_key" {
#   name        = "amplifier-api-key"
#   description = "API Key for amplifier application"
#   enabled     = true
# }

# # Associate the API Key with the Usage Plan
# resource "aws_api_gateway_usage_plan_key" "amplifier_usage_plan_key" {
#   key_id        = aws_api_gateway_api_key.amplifier_api_key.id
#   key_type      = "API_KEY"
#   usage_plan_id = aws_api_gateway_usage_plan.amplifier_usage_plan.id
# }

resource "aws_api_gateway_vpc_link" "amplifier_vpclink" {
  name = "vpc-link-${var.amplifier_vpclinkname}"
  target_arns = [aws_lb.nlb.arn]
}

resource "aws_lb" "nlb" {
  name               = "amplifier-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = ["subnet-04709b8abcff0619c", "subnet-004e20dfb346cc2d1"]

  enable_deletion_protection = false

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "nlb_tg" {
  depends_on  = [
    aws_lb.nlb
  ]
  name        = "nlb-ecs-${var.environment}-tg"
  port        = var.app_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"  # Health check path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }
}

# Redirect all traffic from the NLB to the target group
resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.id
  port              = var.app_port
  protocol    = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb_tg.id
    type             = "forward"
  }
}

resource "aws_ecs_cluster" "amplifier_cluster" {
  name = var.cluster_name

  tags = {
    Name = var.cluster_tag_name
  }
}

resource "aws_ecs_service" "amplifier" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.amplifier_cluster.id
  task_definition = aws_ecs_task_definition.amplifier.family
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
    subnets         = var.public_subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nlb_tg.arn
    container_name   = var.name
    container_port   = var.app_port
  }

  depends_on = [
    aws_ecs_task_definition.amplifier,
  ]
}

resource "aws_ecs_task_definition" "amplifier" {
  family                   = var.name
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.main_ecs_tasks.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory

  container_definitions = jsonencode([
    {
      name        = var.name
      image       = "612958166077.dkr.ecr.us-east-1.amazonaws.com/test:latest"
      #image: "${JFROG_REGISTRY_URL}/test:latest",
      cpu         = var.fargate_cpu
      memory      = var.fargate_memory
      networkMode = "awsvpc"
      readonlyRootFilesystem = false
      essential   = true
      environment = [
        {
          name  = "API_DOMAIN"
          value = "${aws_api_gateway_deployment.dev.invoke_url}"
        },
        {
          name  = "AWS_REGION"
          value = "us-east-1"
        },
        {
          name  = "AWS_BUCKET_NAME"
          value = "${aws_s3_bucket.amplifier_media_bucket.bucket}"
        },
        {
          name      = "TEST_ENV"
          value = "POC"
        }
      ]
      secrets = [
        {
          name      = "AWS_ACCESS_KEY"
          valueFrom = "${aws_secretsmanager_secret.aws_access_key.arn}"
        },
        {
          name      = "AWS_SECRET_KEY"
          valueFrom = "${aws_secretsmanager_secret.aws_secret_key.arn}"
        },
        {
          name      = "DATABASE_USERNAME_LOCAL"
          valueFrom = "${aws_secretsmanager_secret.db_username.arn}"
        },
        {
          name      = "DATABASE_PASS_LOCAL"
          valueFrom = "${aws_secretsmanager_secret.db_password.arn}"
        },
        {
          name      = "DATABASE_HOST_LOCAL"
          valueFrom = "${aws_secretsmanager_secret.db_host.arn}"
        },
        {
          name      = "DATABASE_NAME_LOCAL"
          valueFrom = "${aws_secretsmanager_secret.db_name.arn}"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/amplifier/awslog"
          awslogs-stream-prefix = "ecs"
          awslogs-region        = "us-east-1"
        }
      }

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
          hostPort      = var.app_port
        }
      ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}
resource "aws_ecr_repository" "my_ecr_repo" {
  name                 = "amplifier-bedrock-repo" 
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_secretsmanager_secret" "aws_access_key" {
  name = "aws_access_key"
}

resource "aws_secretsmanager_secret_version" "aws_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_access_key.id
  secret_string = "placeholder_value_for_access_key"
}

resource "aws_secretsmanager_secret" "aws_secret_key" {
  name = "aws_secret_key"
}

resource "aws_secretsmanager_secret_version" "aws_secret_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_secret_key.id
  secret_string = "placeholder_value_for_secret_key"
}

resource "aws_secretsmanager_secret" "db_username" {
  name = "db_username"
}

resource "aws_secretsmanager_secret_version" "db_username_version" {
  secret_id     = aws_secretsmanager_secret.db_username.id
  secret_string = "testuser"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "db_password"
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "test123"
}

resource "aws_secretsmanager_secret" "db_host" {
  name = "db_host"
}

resource "aws_secretsmanager_secret_version" "db_host_version" {
  secret_id     = aws_secretsmanager_secret.db_host.id
  secret_string = "bedrockdb-instance-1.czhu8znim6ye.us-east-1.rds.amazonaws.com"
}

resource "aws_secretsmanager_secret" "db_name" {
  name = "db_name"
}

resource "aws_secretsmanager_secret_version" "db_name_version" {
  secret_id     = aws_secretsmanager_secret.db_name.id
  secret_string = "test-db-name"
}

####
