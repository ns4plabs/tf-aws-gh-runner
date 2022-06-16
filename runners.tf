module "runners" {
  for_each = {
    "linux-x64-default" = {
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["m5.large"]
      repository_white_list = ["pl-strflt/tf-aws-gh-runner", "singulargarden/pl-github"]
      runners_maximum_count = 10
    }
    "windows-x64-default" = {
      runner_os = "windows"
      runner_architecture = "x64"
      instance_types = ["m5.large"]
      repository_white_list = ["pl-strflt/tf-aws-gh-runner"]
      runners_maximum_count = 10
    }
    "linux-arm64-default" = {
      runner_os = "linux"
      runner_architecture = "arm64"
      instance_types = ["m6g.large"]
      repository_white_list = ["pl-strflt/tf-aws-gh-runner", "galargh/ref-fvm"]
      runners_maximum_count = 10
    }
    "testground" = {
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["m5.2xlarge"]
      repository_white_list = ["pl-strflt/tf-aws-gh-runner", "singulargarden/pl-github"]
      ami_filter = { name = ["github-runner-ubuntu-focal-amd64-202206031118-testground"] }
      ami_owners  = ["642361402189"]
      enabled_userdata = false
      runner_run_as = "ubuntu"
      runners_maximum_count = 10
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "io2"
        volume_size           = 100
        encrypted             = true
        iops                  = 16000
      }]
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

  runner_os = each.value.runner_os
  runner_architecture = each.value.runner_architecture

  ami_filter = lookup(each.value, "ami_filter", null)
  ami_owners = lookup(each.value, "ami_owners", ["amazon"])
  enabled_userdata = lookup(each.value, "enabled_userdata", true)
  runner_run_as = lookup(each.value, "runner_run_as", "ec2-user")
  block_device_mappings = lookup(each.value, "block_device_mappings", [{
    device_name           = "/dev/xvda"
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    iops                  = null
  }])

  enable_organization_runners = true
  runner_extra_labels         = join(",", [each.key])
  runner_enable_workflow_job_labels_check = true

  enable_ssm_on_runners = true

  instance_types = each.value.instance_types

  minimum_running_time_in_minutes = each.value.runner_os == "windows" ? 30 : 10
  delay_webhook_event = 0

  runners_maximum_count = each.value.runners_maximum_count

  enable_ephemeral_runners = true

  log_level = "debug"

  repository_white_list = each.value.repository_white_list

  logging_retention_in_days = 30

  runner_boot_time_in_minutes = each.value.runner_os == "windows" ? 20 : 5
}
