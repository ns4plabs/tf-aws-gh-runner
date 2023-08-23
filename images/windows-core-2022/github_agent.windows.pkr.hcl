packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "name_suffix" {
  description = "The suffix to append to the name of the runner"
  type        = string
  default     = "basic"
}

variable "global_tags" {
  description = "Tags to apply to everything"
  type        = map(string)
  default     = {}
}

variable "ami_tags" {
  description = "Tags to apply to the AMI"
  type        = map(string)
  default     = {}
}

variable "snapshot_tags" {
  description = "Tags to apply to the snapshot"
  type        = map(string)
  default     = {}
}

variable "custom_shell_commands" {
  description = "Additional commands to run on the EC2 instance, to customize the instance, like installing packages"
  type        = list(string)
  default     = []
}

variable "post_install_custom_shell_commands" {
  description = "Additional commands to run on the EC2 instance, to customize the instance, like installing packages"
  type        = list(string)
  default     = []
}

variable "runner_version" {
  description = "The version (no v prefix) of the runner software to install https://github.com/actions/runner/releases"
  type        = string
  default     = "2.305.0"
}

source "amazon-ebs" "githubrunner" {
  ami_name                                  = join("-", [
    "github-runner",
    "windows-core",
    "2022",
    formatdate("YYYYMMDDhhmm", timestamp()),
    var.name_suffix
  ])
  communicator                              = "winrm"
  instance_type                             = "m4.xlarge"
  region                                    = "us-east-1"

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-ECS_Optimized-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  tags = merge(
    var.global_tags,
    var.ami_tags,
    {
      OS_Version    = "windows-core-2022"
      Release       = "Latest"
      Base_AMI_Name = "{{ .SourceAMIName }}"
    }
  )
  snapshot_tags = merge(
    var.global_tags,
    var.snapshot_tags,
  )
  user_data_file = "./bootstrap.ps1"
  winrm_insecure = true
  winrm_port     = 5986
  winrm_use_ssl  = true
  winrm_username = "Administrator"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = "60"
    volume_type           = "gp3"
    delete_on_termination = "true"
  }
}

build {
  name = "githubactions-runner"
  sources = [
    "source.amazon-ebs.githubrunner"
  ]

  provisioner "file" {
    content = file("../start-runner.ps1")
    destination = "C:\\start-runner.ps1"
  }

  provisioner "powershell" {
    inline = concat([
      templatefile("../install-runner.ps1", {
        action_runner_url = "https://github.com/actions/runner/releases/download/v${var.runner_version}/actions-runner-win-x64-${var.runner_version}.zip"
      })
    ], var.custom_shell_commands)
  }
}
