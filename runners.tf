locals {
  runner_configs = {
    "linux-x64-4xlarge" = {
      runner_extra_labels = "4xlarge"
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["c5.4xlarge"]
      runners_maximum_count = 50
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-ubuntu-jammy-amd64-202307110949-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runner"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "io2"
        volume_size           = 100
        encrypted             = true
        iops                  = 2500
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
    "linux-x64-2xlarge" = {
      runner_extra_labels = "2xlarge"
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["c5.2xlarge"]
      runners_maximum_count = 50
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-ubuntu-jammy-amd64-202307110949-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runner"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "io2"
        volume_size           = 100
        encrypted             = true
        iops                  = 2500
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
    "linux-x64-xlarge" = {
      runner_extra_labels = "xlarge"
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["c5.xlarge", "m5.xlarge"]
      runners_maximum_count = 50
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-ubuntu-jammy-amd64-202307110949-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runner"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "gp3"
        volume_size           = 100
        encrypted             = true
        iops                  = null
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
    "linux-x64-large" = {
      runner_extra_labels = "large"
      runner_os = "linux"
      runner_architecture = "x64"
      instance_types = ["c5.large", "m5.large"]
      runners_maximum_count = 100
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-ubuntu-jammy-amd64-202307110949-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runner"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "gp3"
        volume_size           = 100
        encrypted             = true
        iops                  = null
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
    "playground" = {
      runner_extra_labels = "playground"
      runner_os = "linux"
      runner_architecture = "x64"
      repository_white_list = ["pl-strflt/tf-aws-gh-runner"]
      instance_types = ["c5.4xlarge"]
      runners_maximum_count = 1
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-ubuntu-jammy-amd64-202307110949-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runner"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "io2"
        volume_size           = 100
        encrypted             = true
        iops                  = 2500
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
    "windows-playground" = {
      runner_extra_labels = "playground"
      runner_os = "windows"
      runner_architecture = "x64"
      repository_white_list = ["pl-strflt/tf-aws-gh-runner"]
      instance_types = ["c5.xlarge"]
      runners_maximum_count = 1
      instance_target_capacity_type = "on-demand"
      ami_filter = { name = ["github-runner-windows-core-2022-202310181537-default"], state = ["available"] }
      ami_owners = ["642361402189"]
      enable_userdata = false
      enable_runner_binaries_syncer = false
      enable_runner_detailed_monitoring = true
      runner_run_as = "runneradmin"
      block_device_mappings = [{
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_type           = "io2"
        volume_size           = 100
        encrypted             = true
        iops                  = 2500
        throughput            = null
        kms_key_id            = null
        snapshot_id           = null
      }]
    }
  }
  legacy_runners = {for k, v in module.runners: k => {
    role_runner_id = v.runners.role_runner.id
  }}
  # runners = {for v in module.multi-runner.runners : replace(v.launch_template_name, "-action-runner$", "") => {
  #   role_runner_id = v.role_runner.id
  # }}
}

# module "multi-runner" {
#   source                          = "philips-labs/github-runner/aws//modules/multi-runner"
#   version                         = "3.1.0"
#   aws_region                      = data.aws_region.default.name
#   vpc_id                          = module.vpc.vpc_id
#   subnet_ids                      = module.vpc.private_subnets

#   prefix = "multi"
#   tags = local.tags

#   github_app = {
#     key_base64     = var.github_app_key_base64
#     id             = var.github_app_id
#     webhook_secret = var.github_webhook_secret
#   }

#   webhook_lambda_zip                = "bootstrap/webhook.zip"
#   runner_binaries_syncer_lambda_zip = "bootstrap/runner-binaries-syncer.zip"
#   runners_lambda_zip                = "bootstrap/runners.zip"

#   multi_runner_config = {
#     for k, v in local.runner_configs : k => {
#       matcherConfig = {
#         labelMatchers = [concat(["self-hosted", v.runner_os, v.runner_architecture], split(v.runner_extra_labels, ","))]
#         exactMatch    = true
#       }
#       fifo                = true
#       redrive_build_queue = {
#         enabled         = false
#         maxReceiveCount = null
#       }
#       runner_config = {
#         prefix = k

#         runner_os = v.runner_os
#         runner_architecture = v.runner_architecture

#         ami_filter = lookup(v, "ami_filter", null)
#         ami_owners = lookup(v, "ami_owners", ["amazon"])
#         enable_userdata = lookup(v, "enable_userdata", true)
#         enable_runner_binaries_syncer = lookup(v, "enable_runner_binaries_syncer", true)
#         runner_run_as = lookup(v, "runner_run_as", "ec2-user")
#         block_device_mappings = lookup(v, "block_device_mappings", [{
#           device_name           = "/dev/xvda"
#           delete_on_termination = true
#           volume_type           = "gp3"
#           volume_size           = 30
#           encrypted             = true
#           iops                  = null
#           throughput            = null
#           kms_key_id            = null
#           snapshot_id           = null
#         }])

#         enable_runner_detailed_monitoring = lookup(v, "enable_runner_detailed_monitoring", false)

#         enable_organization_runners = false
#         runner_extra_labels         = v.runner_extra_labels
#         enable_runner_workflow_job_labels_check_all = true

#         enable_ssm_on_runners = true

#         instance_types = v.instance_types
#         instance_target_capacity_type = lookup(v, "instance_target_capacity_type", "spot")

#         minimum_running_time_in_minutes = v.runner_os == "windows" ? 30 : 10
#         delay_webhook_event = 0

#         runners_maximum_count = v.runners_maximum_count

#         enable_ephemeral_runners = true

#         log_level = "debug"

#         repository_white_list = v.repository_white_list

#         logging_retention_in_days = 30

#         runner_boot_time_in_minutes = v.runner_os == "windows" ? 20 : 5
#       }
#     }
#   }
# }

module "runners" {
  for_each = local.runner_configs

  source                          = "philips-labs/github-runner/aws"
  version                         = "3.6.1"
  aws_region                      = data.aws_region.default.name
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = try(each.value.subnet_ids, module.vpc.public_subnets)

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
  enable_userdata = lookup(each.value, "enable_userdata", true)
  enable_runner_binaries_syncer = lookup(each.value, "enable_runner_binaries_syncer", true)
  runner_run_as = lookup(each.value, "runner_run_as", "ec2-user")
  block_device_mappings = lookup(each.value, "block_device_mappings", [{
    device_name           = "/dev/xvda"
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    iops                  = null
    throughput            = null
    kms_key_id            = null
    snapshot_id           = null
  }])

  enable_runner_detailed_monitoring = lookup(each.value, "enable_runner_detailed_monitoring", false)

  enable_organization_runners = true # false
  runner_extra_labels         = each.value.runner_extra_labels
  enable_runner_workflow_job_labels_check_all = true

  enable_ssm_on_runners = true

  instance_types = each.value.instance_types
  instance_target_capacity_type = lookup(each.value, "instance_target_capacity_type", "spot")

  minimum_running_time_in_minutes = each.value.runner_os == "windows" ? 30 : 10
  delay_webhook_event = 0

  runners_maximum_count = each.value.runners_maximum_count

  enable_ephemeral_runners = true

  log_level = "debug"

  repository_white_list = try(each.value.repository_white_list, [
    "filecoin-project/builtin-actors",
    "ipfs/boxo",
    "ipfs/distributions",
    "ipfs/kubo",
    "ipni/storetheindex",
    "libp2p/go-libp2p",
    "libp2p/js-libp2p",
    "libp2p/rust-libp2p",
    "libp2p/test-plans",
    "pl-strflt/tf-aws-gh-runner",
    "quic-go/quic-go"
  ])

  logging_retention_in_days = 30

  runner_boot_time_in_minutes = each.value.runner_os == "windows" ? 20 : 5

  runner_log_files = [
    {
      "log_group_name" : "syslog",
      "prefix_log_group" : true,
      "file_path" : "/var/log/syslog",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "user_data",
      "prefix_log_group" : true,
      "file_path" : each.value.runner_os == "windows" ? "C:/UserData.log" : "/var/log/user-data.log",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "runner",
      "prefix_log_group" : true,
      "file_path" : each.value.runner_os == "windows" ? "D:/_diag/Runner_*.log" : "/home/runner/_diag/Runner_**.log",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "runner-startup",
      "prefix_log_group" : true,
      "file_path" : each.value.runner_os == "windows" ? "C:/runner-startup.log" : "/var/log/runner-startup.log",
      "log_stream_name" : "{instance_id}"
    },
    {
      "log_group_name" : "worker",
      "prefix_log_group" : true,
      "file_path" : each.value.runner_os == "windows" ? "D:/_diag/Worker_*.log" : "/home/runner/_diag/Worker_**.log",
      "log_stream_name" : "{instance_id}"
    }
  ]

  scale_up_reserved_concurrent_executions = -1
}
