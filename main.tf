terraform {
  backend "s3" {
    # account_id = "642361402189"
    region               = "us-east-1"
    bucket               = "tf-aws-gh-runner"
    key                  = "terraform.tfstate"
    dynamodb_table       = "tf-aws-gh-runner"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    local = {
      source = "hashicorp/local"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  required_version = "~> 1.3.7"
}

locals {
  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }
}

provider "aws" {}

variable "github_app_key_base64" {}

variable "github_app_id" {}

variable "github_webhook_secret" {}

variable "email" {}

data "aws_region" "default" {}

data "aws_s3_bucket" "tf-aws-gh-runner" {
  bucket = "tf-aws-gh-runner"
}

data "aws_caller_identity" "current" {}

# RETENTION

# resource "aws_s3_bucket_lifecycle_configuration" "tf-aws-gh-runner_v2" {
#   bucket = data.aws_s3_bucket.tf-aws-gh-runner.id

#   # artifacts.tf
#   dynamic "rule" {
#     for_each = local.runners

#     content {
#       id = rule.key
#       filter {
#         prefix = "${rule.key}/"
#       }
#       expiration {
#         days = 90
#       }
#       status = "Enabled"
#     }
#   }
# }

resource "aws_s3_bucket_lifecycle_configuration" "tf-aws-gh-runner" {
  bucket = data.aws_s3_bucket.tf-aws-gh-runner.id

  # artifacts.tf
  dynamic "rule" {
    for_each = local.legacy_runners

    content {
      id = rule.key
      filter {
        prefix = "${rule.key}/"
      }
      expiration {
        days = 90
      }
      status = "Enabled"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "github-timeout" {
  for_each = local.legacy_runners
  depends_on = [ module.runners ]

  name           = "github-timeout-${each.key}"
  pattern        = "\"The HTTP request timed out after 00:01:40.\""
  log_group_name = "/github-self-hosted-runners/${each.key}/runner-startup"

  metric_transformation {
    name          = "Timeout"
    namespace     = "GitHub"
    value         = "1"
    default_value = null
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "github-timeout-2" {
  for_each = local.legacy_runners
  depends_on = [ module.runners ]

  name           = "github-timeout-${each.key}"
  pattern        = "\"The request was canceled due to the configured HttpClient.Timeout of 100 seconds elapsing.\""
  log_group_name = "/github-self-hosted-runners/${each.key}/runner"

  metric_transformation {
    name          = "Timeout2"
    namespace     = "GitHub"
    value         = "1"
    default_value = null
    unit          = "Count"
  }
}

resource "aws_sns_topic" "github-timeout" {
  name = "github-timeout"
}

resource "aws_sns_topic_subscription" "github-timeout" {
  count = var.email != "" ? 1 : 0

  topic_arn = aws_sns_topic.github-timeout.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_cloudwatch_metric_alarm" "github-timeout" {
  for_each = aws_cloudwatch_log_metric_filter.github-timeout

  alarm_name        = "github-timeout-${each.key}"
  alarm_description = "GitHub Runner Timeout"
  actions_enabled   = true

  alarm_actions             = [aws_sns_topic.github-timeout.arn]
  ok_actions                = []
  insufficient_data_actions = []

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "0"
  unit                = "Count"

  datapoints_to_alarm                   = "1"
  treat_missing_data                    = "notBreaching"

  # conflicts with metric_query
  metric_name        = each.value.metric_transformation[0].name
  namespace          = each.value.metric_transformation[0].namespace
  period             = "600"
  statistic          = "Sum"

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "github-timeout-2" {
  for_each = aws_cloudwatch_log_metric_filter.github-timeout-2

  alarm_name        = "github-timeout-2-${each.key}"
  alarm_description = "GitHub Runner Timeout 2"
  actions_enabled   = true

  alarm_actions             = [aws_sns_topic.github-timeout.arn]
  ok_actions                = []
  insufficient_data_actions = []

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "1"
  unit                = "Count"

  datapoints_to_alarm                   = "1"
  treat_missing_data                    = "notBreaching"

  # conflicts with metric_query
  metric_name        = each.value.metric_transformation[0].name
  namespace          = each.value.metric_transformation[0].namespace
  period             = "600"
  statistic          = "Sum"

  tags = local.tags
}
