$ErrorActionPreference = "Continue"
$VerbosePreference = "Continue"

# Install Chocolatey
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$env:chocolateyUseWindowsCompression = 'true'
Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression

refreshenv

Write-Host "Installing cloudwatch agent..."
Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi -OutFile C:\amazon-cloudwatch-agent.msi
$cloudwatchParams = '/i', 'C:\amazon-cloudwatch-agent.msi', '/qn', '/L*v', 'C:\CloudwatchInstall.log'
Start-Process "msiexec.exe" $cloudwatchParams -Wait -NoNewWindow
Remove-Item C:\amazon-cloudwatch-agent.msi

# Install dependent tools
Write-Host "Installing additional development tools"
choco install git awscli powershell-core -y
choco install msys2 --params "/InstallDir:C:\msys64" -y

# Add Git bash to path
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "C:\Program Files\PowerShell\7;C:\Program Files\Git\bin;$currentPath"
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

refreshenv

## Create D:\ drive
Write-Host "Creating D:\ for the GH Action installtion"
Resize-Partition -DriveLetter C -Size 30GB
$disk = Get-Disk -Number 0
$partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
Format-Volume -Partition $partition -FileSystem NTFS
# Copy-Item -Path .\* -Destination D:\ -Recurse -Force -Exclude "C:\runner-startup.log"
Set-Location -Path "D:\"

Write-Host "Downloading the GH Action runner from ${action_runner_url}"
Invoke-WebRequest -Uri ${action_runner_url} -OutFile actions-runner.zip

Write-Host "Un-zip action runner"
Expand-Archive -Path actions-runner.zip -DestinationPath .

Write-Host "Delete zip file"
Remove-Item actions-runner.zip

$action = New-ScheduledTaskAction -WorkingDirectory "D:\" -Execute "PowerShell.exe" -Argument "-File C:\start-runner.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "runnerinit" -Action $action -Trigger $trigger -User System -RunLevel Highest -Force

& "C:/Program Files/Amazon/EC2Launch/EC2Launch.exe" reset --clean
