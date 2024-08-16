resource "aws_api_gateway_rest_api" "amplifier" {
  name = "amplifier-api"
  description = "API Gateway for amplifier application"
}

resource "aws_api_gateway_authorizer" "cognito_auth" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  type  = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  name             = "cognito-amplifier-authorizer"
  provider_arns    = [aws_cognito_user_pool.amplifier_cognito_user_pool.arn]
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
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

# Integration with NLB via VPC Link
resource "aws_api_gateway_integration" "app_integration" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method.http_method
  integration_http_method = "POST"
  type = "HTTP_PROXY"
  uri = "http://${aws_lb.nlb.dns_name}"

  connection_type = "VPC_LINK"
  connection_id = aws_api_gateway_vpc_link.amplifier_vpclink.id
}

resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  stage_name  = "dev"
  depends_on = [
    aws_api_gateway_integration.app_integration,
    aws_api_gateway_method.amplifier_method
  ]
}

resource "aws_api_gateway_vpc_link" "amplifier_vpclink" {
  name = "vpc-link-${var.amplifier_vpclinkname}"
  target_arns = [aws_lb.nlb.arn]
}

resource "aws_lb" "nlb" {
  name               = "amplifier-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = ["subnet-836b2f8d", "subnet-fef97b98"]

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
  #desired_count   = var.app_count
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
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
      cpu         = var.fargate_cpu
      memory      = var.fargate_memory
      networkMode = "awsvpc"
      readonlyRootFilesystem = false
      essential   = true

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