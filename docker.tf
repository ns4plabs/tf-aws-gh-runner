locals {
  registries = toset(["cache", "proxy"])
}

# ALB

resource "aws_lb" "docker" {
  for_each = local.registries

  name               = "tf-aws-gh-runner-docker-${each.value}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.vpc.default_security_group_id]
  subnets            = module.vpc.private_subnets
  idle_timeout       = 900

  tags = local.tags
}

resource "aws_lb_listener" "docker" {
  for_each = local.registries

  load_balancer_arn = aws_lb.docker[each.value].id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.docker[each.value].arn
  }

  tags = local.tags
}

resource "aws_lb_target_group" "docker" {
  for_each = local.registries

  name        = "docker-${each.value}"
  target_type = "lambda"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  tags = local.tags
}

# LAMBDA

resource "aws_lambda_function" "docker" {
  for_each = local.registries

  filename          = "${path.module}/lambdas/registry/dist.zip"
  source_code_hash  = filebase64sha256("${path.module}/lambdas/registry/dist.zip")
  function_name     = "tf-aws-gh-runner-docker-${each.value}"
  role              = aws_iam_role.docker_lambda[each.value].arn
  handler           = "dist"
  runtime           = "provided.al2"
  timeout           = 15
  architectures     = ["x86_64"]

  environment {
    variables = {
      REGISTRY = file("${path.module}/lambdas/registry/configs/${each.value}.yml")
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "docker" {
  for_each = local.registries

  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.docker[each.value].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.docker[each.value].arn
}

resource "aws_lb_target_group_attachment" "docker" {
  for_each = local.registries

  target_group_arn = aws_lb_target_group.docker[each.value].arn
  target_id        = aws_lambda_function.docker[each.value].arn
  depends_on       = [aws_lambda_permission.docker]
}

# LOGGING

resource "aws_cloudwatch_log_group" "docker" {
  for_each = local.registries

  name              = "/aws/lambda/${aws_lambda_function.docker[each.value].function_name}"
  retention_in_days = 7
  tags              = local.tags
}

# ACCESS

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "docker_lambda" {
  for_each = local.registries

  name                 = "role-tf-aws-gh-runner-docker-${each.value}"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role_policy.json
  path                 = "/tf-aws-gh-runner-docker/"
  tags                 = local.tags
}

resource "aws_iam_role_policy" "docker_logging" {
  for_each = local.registries

  name = "logging-policy-tf-aws-gh-runner-docker-${each.value}"
  role = aws_iam_role.docker_lambda[each.value].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.docker[each.value].arn}*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "docker_s3" {
  for_each = local.registries

  name = "s3-policy-tf-aws-gh-runner-docker-${each.value}"
  role = aws_iam_role.docker_lambda[each.value].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowLimitedGetPut"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}/docker/${each.value}/*"]
      },
      {
        Sid = "AllowLimitedList"
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}"]
        Condition = {
          StringLike: {
            "s3:prefix" = [
              "docker/${each.value}/*",
            ]
          }
        }
      },
    ]
  })
}
