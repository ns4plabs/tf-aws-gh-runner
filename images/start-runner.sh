#!/bin/bash -e
exec > >(tee /var/log/runner-startup.log | logger -t user-data -s 2>/dev/console) 2>&1

cd /opt/actions-runner

# shellcheck shell=bash

## Retrieve instance metadata

echo "Retrieving TOKEN from AWS API"
token=$(curl -f -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 180")

ami_id=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/ami-id)

region=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
echo "Retrieved REGION from AWS API ($region)"

instance_id=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/instance-id)
echo "Retrieved INSTANCE_ID from AWS API ($instance_id)"

environment=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/tags/instance/ghr:environment)
ssm_config_path=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/tags/instance/ghr:ssm_config_path)
runner_name_prefix=$(curl -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/tags/instance/ghr:runner_name_prefix || echo "")

echo "Retrieved ghr:environment tag - ($environment)"
echo "Retrieved ghr:ssm_config_path tag - ($ssm_config_path)"
echo "Retrieved ghr:runner_name_prefix tag - ($runner_name_prefix)"

parameters=$(aws ssm get-parameters-by-path --path "$ssm_config_path" --region "$region" --query "Parameters[*].{Name:Name,Value:Value}")
echo "Retrieved parameters from AWS SSM ($parameters)"

run_as=$(echo "$parameters" | jq -r '.[] | select(.Name == "'$ssm_config_path'/run_as") | .Value')
echo "Retrieved /$ssm_config_path/run_as parameter - ($run_as)"

enable_cloudwatch_agent=$(echo "$parameters" | jq --arg ssm_config_path "$ssm_config_path" -r '.[] | select(.Name == "'$ssm_config_path'/enable_cloudwatch") | .Value')
echo "Retrieved /$ssm_config_path/enable_cloudwatch parameter - ($enable_cloudwatch_agent)"

agent_mode=$(echo "$parameters" | jq --arg ssm_config_path "$ssm_config_path" -r '.[] | select(.Name == "'$ssm_config_path'/agent_mode") | .Value')
echo "Retrieved /$ssm_config_path/agent_mode parameter - ($agent_mode)"

token_path=$(echo "$parameters" | jq --arg ssm_config_path "$ssm_config_path" -r '.[] | select(.Name == "'$ssm_config_path'/token_path") | .Value')
echo "Retrieved /$ssm_config_path/token_path parameter - ($token_path)"

if [[ "$enable_cloudwatch_agent" == "true" ]]; then
  echo "Cloudwatch is enabled"
  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:$ssm_config_path/cloudwatch_agent_config_runner"
fi

## Configure docker registries

docker_parameters=$(aws ssm get-parameters-by-path --path "/tf-aws-gh-runner/docker" --region "$region" --query "Parameters[*].{Name:Name,Value:Value}")
echo "Retrieved docker parameters from AWS SSM ($docker_parameters)"

### Docker Registry Proxy

docker_proxy=$(echo "$docker_parameters" | jq -r '.[] | select(.Name == "/tf-aws-gh-runner/docker/proxy_aws_lb_dns_name") | .Value')
echo "Retrieved /tf-aws-gh-runner/docker/proxy_aws_lb_dns_name parameter - ($docker_proxy)"

sudo mkdir -p /etc/docker
sudo echo '{' > /etc/docker/daemon.json
sudo echo '  "insecure-registries": [' >> /etc/docker/daemon.json
sudo echo '    "'"$docker_proxy"'"' >> /etc/docker/daemon.json
sudo echo '  ],' >> /etc/docker/daemon.json
sudo echo '  "registry-mirrors": [' >> /etc/docker/daemon.json
sudo echo '    "'"http://$docker_proxy"'"' >> /etc/docker/daemon.json
sudo echo '  ]' >> /etc/docker/daemon.json
sudo echo '}' >> /etc/docker/daemon.json

sudo mkdir -p /etc/buildkit
sudo echo 'insecure-entitlements = [' > /etc/buildkit/buildkitd.toml
sudo echo '  "network.host",' >> /etc/buildkit/buildkitd.toml
sudo echo '  "security.insecure"' >> /etc/buildkit/buildkitd.toml
sudo echo ']' >> /etc/buildkit/buildkitd.toml
sudo echo '[registry."docker.io"]' >> /etc/buildkit/buildkitd.toml
sudo echo '  mirrors = [' >> /etc/buildkit/buildkitd.toml
sudo echo '    "'"$docker_proxy"'"' >> /etc/buildkit/buildkitd.toml
sudo echo '  ]' >> /etc/buildkit/buildkitd.toml
sudo echo '[registry."'"$docker_proxy"'"]' >> /etc/buildkit/buildkitd.toml
sudo echo '  http = true' >> /etc/buildkit/buildkitd.toml
sudo echo '  insecure = true' >> /etc/buildkit/buildkitd.toml

sudo service docker restart

### Go Modules Proxy

goproxy=$(echo "$docker_parameters" | jq -r '.[] | select(.Name == "/tf-aws-gh-runner/docker/goproxy_aws_lb_dns_name") | .Value')
echo "Retrieved /tf-aws-gh-runner/docker/goproxy_aws_lb_dns_name parameter - ($goproxy)"

export GOPROXY="http://$goproxy,direct"

## Configure the runner

echo "Get GH Runner config from AWS SSM"
config=$(aws ssm get-parameter --name "$token_path"/"$instance_id" --with-decryption --region "$region" | jq -r ".Parameter | .Value")
while [[ -z "$config" ]]; do
  echo "Waiting for GH Runner config to become available in AWS SSM"
  sleep 1
  config=$(aws ssm get-parameter --name "$token_path"/"$instance_id" --with-decryption --region "$region" | jq -r ".Parameter | .Value")
done

echo "Delete GH Runner token from AWS SSM"
aws ssm delete-parameter --name "$token_path"/"$instance_id" --region "$region"

echo "Retreving GH Runner owner from config"
runner_owner=$(echo "$config" | grep -oP -- '--url\s+https?://[^/]+/\K[^ ]*')
echo "Retrieved GH Runner owner ($runner_owner) from config"

# echo "Tag GH Runner instance with owner"
# aws ec2 create-tags --resources "$instance_id" --tags Key=ghr:runner_owner,Value="$runner_owner" --region "$region"

if [ -z "$run_as" ]; then
  echo "No user specified, using default ec2-user account"
  run_as="ec2-user"
fi

if [[ "$run_as" == "root" ]]; then
  echo "run_as is set to root - export RUNNER_ALLOW_RUNASROOT=1"
  export RUNNER_ALLOW_RUNASROOT=1
fi

chown -R $run_as .

echo "Configure GH Runner as user $run_as"
sudo --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$run_as" -- ./config.sh --unattended --name "$runner_name_prefix$instance_id" --work "_work" $${config}

info_arch=$(uname -p)
info_os=$(( lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1 | cut -d "=" -f2- | tr -d '"')

tee /opt/actions-runner/.setup_info <<EOL
[
  {
    "group": "Operating System",
    "detail": "Distribution: $info_os\nArchitecture: $info_arch"
  },
  {
    "group": "Runner Image",
    "detail": "AMI id: $ami_id"
  }
]
EOL


## Start the runner
echo "Starting runner after $(awk '{print int($1/3600)":"int(($1%3600)/60)":"int($1%60)}' /proc/uptime)"
echo "Starting the runner as user $run_as"

if [[ $agent_mode = "ephemeral" ]]; then

cat >/opt/start-runner-service.sh <<-EOF
  echo "Starting the runner in ephemeral mode"
  sudo --preserve-env=GOPROXY --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$run_as" -- ./run.sh
  echo "Runner has finished"

  echo "Stopping cloudwatch service"
  systemctl stop amazon-cloudwatch-agent.service
  echo "Terminating instance"
  aws ec2 terminate-instances --instance-ids "$instance_id" --region "$region"
EOF
  chmod 755 /opt/start-runner-service.sh
  # Starting the runner via a own process to ensure this process terminates
  nohup /opt/start-runner-service.sh &

else
  echo "Installing the runner as a service"
  ./svc.sh install "$run_as"
  echo "Starting the runner in persistent mode"
  ./svc.sh start
fi
