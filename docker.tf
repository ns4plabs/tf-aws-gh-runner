locals {
  registries = {
    cache = {
      environment = [
        {
          name = "REGISTRY_STORAGE"
          value = <<-EOT
            s3:
              region: us-east-1
              # TODO: consider using dedicated bucket
              bucket: tf-aws-gh-runner
              rootdirectory: /docker/cache/v0
            delete:
              enabled: false
            redirect:
              disable: false
            maintenance:
              uploadpurging:
                enabled: false
              readonly:
                enabled: false
          EOT
        },
        {
          name = "REGISTRY_HTTP"
          value = <<-EOT
            addr: :5000
            secret: tf-aws-gh-runner-docker-cache-v0
          EOT
        },
        {
          name = "REGISTRY_HEALTH"
          value = <<-EOT
            storagedriver:
              enabled: false
          EOT
        },
        {
          name = "REGISTRY_LOG"
          value = <<-EOT
            level: info
            formatter: json
          EOT
        },
        {
          name = "REGISTRY_REDIS"
          value = <<-EOT
          EOT
        },
        {
          name = "REGISTRY_NOTIFICATIONS"
          value = <<-EOT
          EOT
        }
      ]
    }
    proxy = {
      environment = [
        {
          name = "REGISTRY_STORAGE"
          value = <<-EOT
            s3:
              region: us-east-1
              # TODO: consider using dedicated bucket
              bucket: tf-aws-gh-runner
              rootdirectory: /docker/proxy/v0
            delete:
              enabled: false
            redirect:
              disable: false
            maintenance:
              uploadpurging:
                enabled: false
              readonly:
                enabled: true
          EOT
        },
        {
          name = "REGISTRY_HTTP"
          value = <<-EOT
            addr: :5000
            secret: tf-aws-gh-runner-docker-proxy-v0
          EOT
        },
        {
          name = "REGISTRY_HEALTH"
          value = <<-EOT
            storagedriver:
              enabled: false
          EOT
        },
        {
          name = "REGISTRY_LOG"
          value = <<-EOT
            level: info
            formatter: json
          EOT
        },
        {
          name = "REGISTRY_REDIS"
          value = <<-EOT
          EOT
        },
        {
          name = "REGISTRY_NOTIFICATIONS"
          value = <<-EOT
          EOT
        },
        {
          name = "REGISTRY_PROXY"
          value = <<-EOT
            remoteurl: https://registry-1.docker.io
          EOT
        }
      ]
    }
  }
}

# SG

resource "aws_security_group" "docker_lb" {
  name        = "tf-aws-gh-runner-docker-lb"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    # TODO: consider allowing traffic from runners SGs only
    cidr_blocks      = [module.vpc.vpc_cidr_block]
    ipv6_cidr_blocks = [module.vpc.vpc_ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "docker" {
  for_each     = local.registries

  name        = "tf-aws-gh-runner-docker-${each.key}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    security_groups = [aws_security_group.docker_lb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

# ALB

resource "aws_lb" "docker" {
  for_each = local.registries

  name               = "tf-aws-gh-runner-docker-${each.key}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.docker_lb.id]
  subnets            = module.vpc.private_subnets

  tags = local.tags
}

resource "aws_lb_listener" "docker" {
  for_each = local.registries

  load_balancer_arn = aws_lb.docker[each.key].id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.docker[each.key].arn
  }

  tags = local.tags
}

resource "aws_lb_target_group" "docker" {
  for_each = local.registries

  name        = "docker-${each.key}"
  target_type = "ip"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  tags = local.tags
}

# ECS

resource "aws_ecs_task_definition" "docker" {
  for_each = local.registries

  family                   = "docker-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.docker_exec[each.key].arn
  task_role_arn            = aws_iam_role.docker[each.key].arn

  container_definitions = jsonencode([
    {
      name      = "docker-${each.key}"
      # TODO: change to public ECR image; it'll require access to ECR on the exec role
      # WARN: Why edge instead of registry:2.8.1? https://github.com/distribution/distribution/issues/3645#issuecomment-1347430516
      image     = "distribution/distribution:edge"
      cpu       = 1024
      memory    = 2048
      essential = true
      networkMode = "awsvpc"
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      environment = each.value.environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.docker[each.key].name
          "awslogs-region"        = data.aws_region.default.name
          "awslogs-stream-prefix" = "docker-${each.key}"
        }
      }
    }
  ])
}

resource "aws_ecs_cluster" "docker" {
  for_each = local.registries

  name = "docker-${each.key}"
}

resource "aws_ecs_service" "docker" {
  for_each = local.registries

  name            = "docker-${each.key}"
  cluster         = aws_ecs_cluster.docker[each.key].id
  task_definition = aws_ecs_task_definition.docker[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.docker[each.key].id]
    subnets         = module.vpc.private_subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.docker[each.key].id
    container_name   = "docker-${each.key}"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.docker]
}

# LOGGING

resource "aws_cloudwatch_log_group" "docker" {
  for_each = local.registries

  name              = "/aws/ecs/docker-${each.key}"
  retention_in_days = 7
  tags              = local.tags
}

# ACCESS

resource "aws_iam_role" "docker_exec" {
  for_each = local.registries

  name                 = "role-tf-aws-gh-runner-docker-exec-${each.key}"
  assume_role_policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags                 = local.tags
}

resource "aws_iam_role" "docker" {
  for_each = local.registries

  name                 = "role-tf-aws-gh-runner-docker-${each.key}"
  assume_role_policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags                 = local.tags
}

resource "aws_iam_role_policy" "docker_logging" {
  for_each = local.registries

  name = "logging-tf-aws-gh-runner-docker-${each.key}"
  role = aws_iam_role.docker_exec[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.docker[each.key].arn}*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "docker_s3" {
  for_each = local.registries

  name = "s3-policy-tf-aws-gh-runner-docker-${each.key}"
  role = aws_iam_role.docker[each.key].name

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
          "s3:DeleteObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Sid = "AllowLimitedList"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
    ]
  })
}

# SSM

resource "aws_ssm_parameter" "docker" {
  for_each = local.registries

  name  = "/tf-aws-gh-runner/docker/${each.key}_aws_lb_dns_name"
  type  = "String"
  value = aws_lb.docker[each.key].dns_name
}

resource "aws_iam_role_policy" "shared_ssm" {
  for_each = module.runners

  name = "tf-aws-gh-runner-shared-${each.key}"
  role = each.value.runners.role_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.default.name}:${data.aws_caller_identity.current.account_id}:parameter/tf-aws-gh-runner/*"
        ]
      }
    ]
  })
}
