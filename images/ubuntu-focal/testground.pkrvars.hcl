custom_shell_commands = [
  "curl -OL https://golang.org/dl/go1.18.3.linux-amd64.tar.gz",
  "sudo tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz",
  "echo 'export PATH=\"$PATH:/usr/local/go/bin\"' | sudo tee -a /etc/profile",
  "sudo apt-get -y install build-essential",
]

post_install_custom_shell_commands = [
  # We have to re-export the PATH overwrite,
  # See https://github.com/hashicorp/packer/issues/5728
  "export PATH=\"$PATH:/usr/local/go/bin\"",
  "TMPFOLDER=`mktemp -d`",
  "git clone https://github.com/testground/testground.git $TMPFOLDER",
  "cd $TMPFOLDER",
  "make install",
]

name_suffix = "testground"
