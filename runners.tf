module "linux" {
  source                          = "philips-labs/github-runner/aws"
  version                         = "1.2.0"
  aws_region                      = data.aws_region.default.name
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets

  prefix = "gh-linux"
  tags = {
    Name = "Terraform AWS GitHub Runner"
    Url  = "https://github.com/pl-strflt/tf-aws-gh-runner"
  }

  github_app = {
    key_base64     = var.github_app_key_base64
    id             = var.github_app_id
    webhook_secret = var.github_webhook_secret
  }

  webhook_lambda_zip                = "bootstrap/webhook.zip"
  runner_binaries_syncer_lambda_zip = "bootstrap/runner-binaries-syncer.zip"
  runners_lambda_zip                = "bootstrap/runners.zip"

  runner_os = "linux"

  enable_organization_runners = true
  runner_extra_labels         = join(",", ["linux"])
  runner_enable_workflow_job_labels_check = true

  enable_ssm_on_runners = true

  instance_types = ["m5.large", "c5.large"]

  delay_webhook_event = 0

  runners_maximum_count = 20

  enable_ephemeral_runners = true

  log_level = "debug"

  repository_white_list = ["pl-strflt/tf-aws-gh-runner"]
}
