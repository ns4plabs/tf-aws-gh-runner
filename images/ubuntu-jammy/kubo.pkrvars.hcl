# Ubuntu based AMI with build-essentials preinstalled
# To build, run:
#   packer build -var-file="./kubo.pkrvars.hcl" .

custom_shell_commands = [
  "sudo apt-get -y install build-essential",
  "sudo apt-get install docker-compose-plugin",
]

post_install_custom_shell_commands = []

name_suffix = "kubo"
