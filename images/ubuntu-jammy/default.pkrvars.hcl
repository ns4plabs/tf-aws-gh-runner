# Ubuntu based AMI with build-essentials preinstalled
# To build, run:
#   packer build -var-file="./default.pkrvars.hcl" .

custom_shell_commands = [
  "sudo apt-get -y install build-essential docker-compose-plugin default-jdk cmake libclang-dev",
  "sudo apt remove unattended-upgrades -y",
  "sudo sed -i 's/^\\(APT::Periodic::Update-Package-Lists\\) \"1\";/\\1 \"0\";/' /etc/apt/apt.conf.d/10periodic",
]

post_install_custom_shell_commands = []

name_suffix = "default"
