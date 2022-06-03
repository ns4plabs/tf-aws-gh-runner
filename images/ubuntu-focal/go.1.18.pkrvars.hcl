custom_shell_commands = [
  "curl -OL https://golang.org/dl/go1.18.3.linux-amd64.tar.gz",
  "sudo tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz",
  "echo 'export PATH=\"$PATH:/usr/local/go/bin\"' | sudo tee -a /etc/profile",
  "sudo apt-get -y install build-essential",
]

post_install_custom_shell_commands = [
]

name_suffix = "go1.18"