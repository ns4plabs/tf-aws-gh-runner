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

  required_version = "~> 1.1.4"
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
