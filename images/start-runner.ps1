Start-Transcript -Path "C:\runner-startup.log" -Append

## Create D:\ drive
Write-Host "Creating D:\ for the GH Action installtion"
$disk = Get-Disk -Number 0
$partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
Format-Volume -Partition $partition -FileSystem NTFS
Copy-Item -Path .\* -Destination D:\ -Recurse -Force -Exclude "C:\runner-startup.log"
Set-Location -Path "D:\"

## Retrieve instance metadata

Write-Host  "Retrieving TOKEN from AWS API"
$token=Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "180"}
if ( ! $token ) {
  $retrycount=0
  do {
    echo "Failed to retrieve token. Retrying in 5 seconds."
    Start-Sleep 5
    $token=Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "180"}
    $retrycount=$retrycount + 1
    if ( $retrycount -gt 40 )
    {
        break
    }
  } until ($token)
}

$ami_id=Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/ami-id" -Headers @{"X-aws-ec2-metadata-token" = $token}

$metadata=Invoke-RestMethod -Uri "http://169.254.169.254/latest/dynamic/instance-identity/document" -Headers @{"X-aws-ec2-metadata-token" = $token}

$Region = $metadata.region
Write-Host  "Retrieved REGION from AWS API ($Region)"

$InstanceId = $metadata.instanceId
Write-Host  "Retrieved InstanceId from AWS API ($InstanceId)"

$tags=aws ec2 describe-tags --region "$Region" --filters "Name=resource-id,Values=$InstanceId" | ConvertFrom-Json
Write-Host  "Retrieved tags from AWS API"

$environment=$tags.Tags.where( {$_.Key -eq 'ghr:environment'}).value
Write-Host  "Retrieved ghr:environment tag - ($environment)"

$runner_name_prefix=$tags.Tags.where( {$_.Key -eq 'ghr:runner_name_prefix'}).value
Write-Host  "Retrieved ghr:runner_name_prefix tag - ($runner_name_prefix)"

$ssm_config_path=$tags.Tags.where( {$_.Key -eq 'ghr:ssm_config_path'}).value
Write-Host  "Retrieved ghr:ssm_config_path tag - ($ssm_config_path)"

$parameters=$(aws ssm get-parameters-by-path --path "$ssm_config_path" --region "$Region" --query "Parameters[*].{Name:Name,Value:Value}") | ConvertFrom-Json
Write-Host  "Retrieved parameters from AWS SSM"

$run_as=$parameters.where( {$_.Name -eq "$ssm_config_path/run_as"}).value
Write-Host  "Retrieved $ssm_config_path/run_as parameter - ($run_as)"

$enable_cloudwatch_agent=$parameters.where( {$_.Name -eq "$ssm_config_path/enable_cloudwatch"}).value
Write-Host  "Retrieved $ssm_config_path/enable_cloudwatch parameter - ($enable_cloudwatch_agent)"

$agent_mode=$parameters.where( {$_.Name -eq "$ssm_config_path/agent_mode"}).value
Write-Host  "Retrieved $ssm_config_path/agent_mode parameter - ($agent_mode)"

$token_path=$parameters.where( {$_.Name -eq "$ssm_config_path/token_path"}).value
Write-Host  "Retrieved $ssm_config_path/token_path parameter - ($token_path)"


if ($enable_cloudwatch_agent -eq "true")
{
    Write-Host  "Enabling CloudWatch Agent"
    & 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a fetch-config -m ec2 -s -c "ssm:$ssm_config_path/cloudwatch_agent_config_runner"
}

## Configure docker registries
$docker_parameters=$(aws ssm get-parameters-by-path --path "/tf-aws-gh-runner/docker" --region "$Region" --query "Parameters[*].{Name:Name,Value:Value}") | ConvertFrom-Json
echo "Retrieved docker parameters from AWS SSM"

### Docker Registry Proxy
$docker_proxy=$docker_parameters.where( {$_.Name -eq "/tf-aws-gh-runner/docker/proxy_aws_lb_dns_name"} ).value
echo "Retrieved /tf-aws-gh-runner/docker/proxy_aws_lb_dns_name parameter - ($docker_proxy)"

#### Docker Daemon Configuration
$dockerConfigPath = "C:\ProgramData\Docker\config\daemon.json"
$dockerConfig = @{
    'insecure-registries' = @($docker_proxy)
    'registry-mirrors' = @("http://$docker_proxy")
}
$dockerConfig | ConvertTo-Json | Set-Content -Path $dockerConfigPath

##### BuildKit Configuration - https://github.com/moby/buildkit/issues/616
# $buildkitConfigPath = "C:\ProgramData\BuildKit\config\buildkitd.toml"
# $buildkitConfig = @"
# insecure-entitlements = [
#   "network.host",
#   "security.insecure"
# ]
# [registry."docker.io"]
#   mirrors = [
#     "$docker_proxy"
#   ]
# [registry."$docker_proxy"]
#   http = true
#   insecure = true
# "@
# $buildkitConfig | Set-Content -Path $buildkitConfigPath

Restart-Service -Name "docker"

### Go Modules Proxy

$goproxy=$docker_parameters.where( {$_.Name -eq "/tf-aws-gh-runner/docker/goproxy_aws_lb_dns_name"} ).value
echo "Retrieved /tf-aws-gh-runner/docker/goproxy_aws_lb_dns_name parameter - ($goproxy)"
[Environment]::SetEnvironmentVariable("GOPROXY", "http://$goproxy,direct", "Machine")

## Configure the runner

Write-Host "Get GH Runner config from AWS SSM"
$config = $null
$i = 0
do {
    $config = (aws ssm get-parameters --names "$token_path/$InstanceId" --with-decryption --region $Region  --query "Parameters[*].{Name:Name,Value:Value}" | ConvertFrom-Json)[0].value
    Write-Host "Waiting for GH Runner config to become available in AWS SSM ($i/30)"
    Start-Sleep 1
    $i++
} while (($null -eq $config) -and ($i -lt 30))

Write-Host "Delete GH Runner token from AWS SSM"
aws ssm delete-parameter --name "$token_path/$InstanceId" --region $Region

# Create or update user
if (-not($run_as)) {
  Write-Host "No user specified, using default ec2-user account"
  $run_as="ec2-user"
}
Add-Type -AssemblyName "System.Web"
$password = [System.Web.Security.Membership]::GeneratePassword(24, 4)
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$username = $run_as
if (!(Get-LocalUser -Name $username -ErrorAction Ignore)) {
    New-LocalUser -Name $username -Password $securePassword
    Write-Host "Created new user ($username)"
}
else {
    Set-LocalUser -Name $username -Password $securePassword
    Write-Host "Changed password for user ($username)"
}
# Add user to groups
foreach ($group in @("Administrators", "docker-users")) {
    if ((Get-LocalGroup -Name "$group" -ErrorAction Ignore) -and
        !(Get-LocalGroupMember -Group "$group" -Member $username -ErrorAction Ignore)) {
        Add-LocalGroupMember -Group "$group" -Member $username
        Write-Host "Added $username to $group group"
    }
}

# Disable User Access Control (UAC)
# TODO investigate if this is needed or if its overkill - https://github.com/philips-labs/terraform-aws-github-runner/issues/1505
Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0 -Force
Write-Host "Disabled User Access Control (UAC)"

$configCmd = ".\config.cmd --unattended --name $runner_name_prefix$InstanceId --work `"a`" $config"
Write-Host "Configure GH Runner as user $run_as"
Invoke-Expression $configCmd

Write-Host "Starting the runner as user $run_as"

$jsonBody = @(
    @{
        group='Runner Image'
        detail="AMI id: $ami_id"
    }
)
ConvertTo-Json -InputObject $jsonBody | Set-Content -Path "$pwd\.setup_info"

Write-Host "Starting runner after $(((get-date) - (gcim Win32_OperatingSystem).LastBootUpTime).tostring("hh':'mm':'ss''"))"
Write-Host "Starting the runner as user $run_as"

if ($agent_mode -eq "ephemeral")
{
  Write-Host "Starting the runner in ephemeral mode"

  $startRunnerServicePath = "C:\start-runner-service.ps1"
  $startRunnerService = @"
Start-Transcript -Path "C:\runner-startup.log" -Append

`$process = Start-Process -FilePath "$($pwd.Path)\run.cmd" -WorkingDirectory "$($pwd.Path)" -Wait -NoNewWindow -PassThru
`$exitCode = `$process.ExitCode
Write-Host "Runner has finished with `$exitCode exit code"

# Ideas for further improvements:
# - Check if /var/runner-startup.log contains Listening for Jobs
# - Check exit code of ./run.sh

Write-Host "Wait for 30 seconds to ensure all logs are flushed"
Start-Sleep -Seconds 30

Write-Host "Stopping cloudwatch service"
& 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a stop

Write-Host "Terminating instance"
aws ec2 terminate-instances --instance-ids "$InstanceId" --region "$Region"

Stop-Transcript
"@

  $startRunnerService | Set-Content -Path $startRunnerServicePath

  $action = New-ScheduledTaskAction -WorkingDirectory "$pwd" -Execute "powershell.exe" -Argument "-File $startRunnerServicePath"
  Register-ScheduledTask -TaskName "runnertask" -Action $action -User $username -Password $password -RunLevel Highest -Force
  Start-ScheduledTask -TaskName "runnertask"
}
else {
  Write-Host  "Installing the runner as a service"
  $action = New-ScheduledTaskAction -WorkingDirectory "$pwd" -Execute "run.cmd"
  $trigger = Get-CimClass "MSFT_TaskRegistrationTrigger" -Namespace "Root/Microsoft/Windows/TaskScheduler"
  Register-ScheduledTask -TaskName "runnertask" -Action $action -Trigger $trigger -User $username -Password $password -RunLevel Highest -Force
}

Stop-Transcript
