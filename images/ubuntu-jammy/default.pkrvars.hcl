# Ubuntu based AMI with build-essentials preinstalled
# To build, run:
#   packer build -var-file="./default.pkrvars.hcl" .

custom_shell_commands = [
  "sudo apt-get -y install build-essential docker-compose-plugin default-jdk cmake",
  "sudo apt remove unattended-upgrades -y",
]

post_install_custom_shell_commands = []

name_suffix = "default"
