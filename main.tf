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

provider "aws" {}

variable "github_app_key_base64" {}

variable "github_app_id" {}

variable "github_webhook_secret" {}

data "aws_region" "default" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.2"

  name = "vpc-tf-aws-gh-runner"
  cidr = "10.0.0.0/16"

  azs             = ["${data.aws_region.default.name}a", "${data.aws_region.default.name}b", "${data.aws_region.default.name}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  map_public_ip_on_launch = false
  single_nat_gateway      = true

  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }
}

output "runners" {
  value = {
    lambda_syncer_name = module.linux.binaries_syncer.lambda.function_name
  }
}

output "webhook_endpoint" {
  value = module.linux.webhook.endpoint
}
