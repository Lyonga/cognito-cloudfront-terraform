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
  uri = "http://${aws_lb.app_nlb.dns_name}"

  connection_type = "VPC_LINK"
  connection_id = aws_api_gateway_vpc_link.amplifier_vpclink.id
}

resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  stage_name  = "dev"

  # depends_on = [
  #   "aws_api_gateway_integration.hello_world",
  # ]
}

# Method Request for the {proxy+} Resource
resource "aws_api_gateway_method_response" "proxy_method_response" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

# Integration Response for the {proxy+} Resource
resource "aws_api_gateway_integration_response" "proxy_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.amplifier.id
  resource_id = aws_api_gateway_resource.amplifier_resource.id
  http_method = aws_api_gateway_method.amplifier_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'*'"
  }
}

resource "aws_api_gateway_vpc_link" "amplifier_vpclink" {
  name = "vpc-link-${var.amplifier_vpclinkname}"
  target_arns = [aws_lb_target_group.nlb_tg.arn]
}

resource "aws_lb" "nlb" {
  name               = "amplifier-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

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