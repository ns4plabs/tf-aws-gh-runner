# Ubuntu based AMI with build-essentials preinstalled
# To build, run:
#   packer build -var-file="./default.pkrvars.hcl" .

custom_shell_commands = [
  "sudo apt-get -y install build-essential docker-compose-plugin default-jdk cmake libclang-dev",
  "sudo apt remove unattended-upgrades -y",
  "sudo sed -i 's/^\\(APT::Periodic::Update-Package-Lists\\) \"1\";/\\1 \"0\";/' /etc/apt/apt.conf.d/10periodic",
  "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg",
  "sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg",
  "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null",
  "sudo apt update",
  "sudo apt install gh -y"
]

post_install_custom_shell_commands = []

name_suffix = "default"
