module "runners" {
  for_each = {
    "large-linux-runner" = {
      os = "linux"
      architecture = "x64"
      instance_types = ["m5.large", "c5.large"]
      repository_allowlist = ["pl-strflt/tf-aws-gh-runner", "singulargarden/pl-github"]
      max_count = 10
    }
    "large-windows-runner" = {
      os = "windows"
      architecture = "x64"
      instance_types = ["m5.large", "c5.large"]
      repository_allowlist = ["pl-strflt/tf-aws-gh-runner"]
      max_count = 10
    }
  }

  source                          = "philips-labs/github-runner/aws"
  version                         = "1.2.0"
  aws_region                      = data.aws_region.default.name
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets

  prefix = each.key
  tags = local.tags

  github_app = {
    key_base64     = var.github_app_key_base64
    id             = var.github_app_id
    webhook_secret = var.github_webhook_secret
  }

  webhook_lambda_zip                = "bootstrap/webhook.zip"
  runner_binaries_syncer_lambda_zip = "bootstrap/runner-binaries-syncer.zip"
  runners_lambda_zip                = "bootstrap/runners.zip"

  runner_os = each.value.os
  runner_architecture = each.value.architecture

  enable_organization_runners = true
  runner_extra_labels         = join(",", [each.key])
  runner_enable_workflow_job_labels_check = true

  enable_ssm_on_runners = true

  instance_types = each.value.instance_types

  minimum_running_time_in_minutes = each.value.os == "windows" ? 30 : 10
  delay_webhook_event = 0

  runners_maximum_count = each.value.max_count

  enable_ephemeral_runners = true

  log_level = "debug"

  repository_white_list = each.value.repository_allowlist

  logging_retention_in_days = 30

  runner_boot_time_in_minutes = each.value.os == "windows" ? 20 : 5
}
