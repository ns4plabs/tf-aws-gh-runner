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

data "aws_region" "default" {}

data "aws_s3_bucket" "tf-aws-gh-runner" {
  bucket = "tf-aws-gh-runner"
}

data "aws_caller_identity" "current" {}

# RETENTION

resource "aws_s3_bucket_lifecycle_configuration" "tf-aws-gh-runner" {
  bucket = data.aws_s3_bucket.tf-aws-gh-runner.id

  # artifacts.tf
  dynamic "rule" {
    for_each = module.runners

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
