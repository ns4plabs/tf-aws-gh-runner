resource "aws_apigatewayv2_api" "webhook_router" {
  name          = "github-action-webhook-router"
  protocol_type = "HTTP"

  tags = local.tags
}

resource "aws_apigatewayv2_route" "webhook_router" {
  api_id    = aws_apigatewayv2_api.webhook_router.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_router.id}"
}

resource "aws_apigatewayv2_stage" "webhook_router" {
  lifecycle {
    ignore_changes = [
      // see bug https://github.com/terraform-providers/terraform-provider-aws/issues/12893
      default_route_settings,
      // not terraform managed
      deployment_id
    ]
  }

  api_id      = aws_apigatewayv2_api.webhook_router.id
  name        = "$default"
  auto_deploy = true

  tags = local.tags
}

resource "aws_apigatewayv2_vpc_link" "webhook_router" {
  name               = "github-action-webhook-router"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets

  tags = local.tags
}


resource "aws_apigatewayv2_integration" "webhook_router" {
  lifecycle {
    ignore_changes = [
      // not terraform managed
      passthrough_behavior
    ]
  }

  api_id           = aws_apigatewayv2_api.webhook_router.id
  integration_type = "HTTP_PROXY"

  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.webhook_router.id
  description        = "GitHub App webhook for receiving build events."
  integration_method = "POST"

  integration_uri    =  aws_lb_listener.webhook_router.arn

  request_parameters = {
    "overwrite:header.x-github-workflow_job-labels" = "$request.body.workflow_job.labels"
  }
}

resource "aws_lb" "webhook_router" {
  name               = "github-action-webhook-router"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.vpc.default_security_group_id]
  subnets            = module.vpc.private_subnets

  tags = local.tags
}

resource "aws_lambda_permission" "webhook_router" {
  for_each = toset(keys(module.runners))

  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = module.runners[each.value].webhook.lambda.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.webhook_router[each.value].arn
}

resource "aws_lb_listener" "webhook_router" {
  load_balancer_arn = aws_lb.webhook_router.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "😵"
      status_code  = "404"
    }
  }

  tags = local.tags
}

resource "aws_lb_target_group" "webhook_router" {
  for_each = toset(keys(module.runners))

  name        = each.value
  target_type = "lambda"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_lb_target_group_attachment" "webhook_router" {
  for_each = toset(keys(module.runners))

  target_group_arn = aws_lb_target_group.webhook_router[each.value].arn
  target_id        = module.runners[each.value].webhook.lambda.arn
  depends_on       = [aws_lambda_permission.webhook_router]
}

resource "aws_lb_listener_rule" "webhook_router" {
  for_each = toset(keys(module.runners))

  listener_arn = aws_lb_listener.webhook_router.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webhook_router[each.value].arn
  }

  condition {
    http_header {
      http_header_name = "x-github-workflow_job-labels"
      values           = [module.runners[each.value].webhook.lambda.environment[0].variables.RUNNER_LABELS]
    }
  }

  tags = local.tags
}
