# terraform init
# export AWS_ACCESS_KEY_ID=
# export AWS_SECRET_ACCESS_KEY=
# terraform apply

terraform {
  required_providers {
    aws = {
      version = "5.9.0"
    }
  }

  required_version = "~> 1.3.7"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}

resource "aws_s3_bucket" "this" {
  bucket = "tf-aws-gh-runner"

  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }
}

resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

resource "aws_dynamodb_table" "this" {
  name         = "tf-aws-gh-runner"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }
}

resource "aws_iam_user" "this" {
  name = "tf-aws-gh-runner"

  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = [
      "iam:*",
      "s3:*",
      "ec2:*",
      "events:*",
      "lambda:*",
      "sqs:*",
      "ssm:*",
      "logs:*",
      "apigateway:*",
      "resource-groups:*",
      "kms:*",
      "dynamodb:*",
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
    effect = "Allow"
  }
}

resource "aws_iam_user_policy" "this" {
  name = "tf-aws-gh-runner"
  user = "${aws_iam_user.this.name}"

  policy = "${data.aws_iam_policy_document.this.json}"
}

module "github-runner_download-lambda" {
  source  = "philips-labs/github-runner/aws//modules/download-lambda"
  version = "3.6.1"
  lambdas = [
    {
      name = "webhook"
      tag  = "v3.6.1"
    },
    {
      name = "runners"
      tag  = "v3.6.1"
    },
    {
      name = "runner-binaries-syncer"
      tag  = "v3.6.1"
    }
  ]
}
