# client/windows/install_windows.ps1
# Purpose: Install and configure NSClient++ for Nagios NRPE monitoring

# 1. Configuration Variables
$NAGIOS_SERVER_IP = "192.168.1.100"  # <--- Change this to your Server IP
$NSC_VERSION      = "0.5.2.35"
$DOWNLOAD_URL     = "https://github.com/mickem/nscp/releases/download/v$NSC_VERSION/NSCP-$NSC_VERSION-x64.msi"
$TEMP_MSI         = "$env:TEMP\nscp_installer.msi"

Write-Host "--- Initiating Windows Monitoring Agent Installation ---" -ForegroundColor Cyan

# 2. Download the MSI Installer
Write-Host "Downloading NSClient++ v$NSC_VERSION..."
Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $TEMP_MSI

# 3. Silent Installation
# ADDLOCAL=ALL installs all modules; /quiet ensures no UI pops up
Write-Host "Installing NSClient++ silently..."
$installArgs = "/i `"$TEMP_MSI`" /quiet /norestart ADDLOCAL=ALL"
Start-Process msiexec.exe -ArgumentList $installArgs -Wait

# 4. Configure nsclient.ini (Idempotent Configuration)
# This defines who can talk to the agent and what modules are active
$CONFIG_PATH = "${env:ProgramFiles}\NSClient++\nsclient.ini"

$CONFIG_BLOCK = @"
[/modules]
CheckSystem = 1
CheckDisk = 1
CheckExternalScripts = 1
CheckHelpers = 1
NRPEServer = 1

[/settings/default]
allowed hosts = $NAGIOS_SERVER_IP

[/settings/NRPE/server]
ssl options = no-ssl
port = 5666
allow chunky messages = true
"@

Write-Host "Applying NRPE configuration..."
Set-Content -Path $CONFIG_PATH -Value $CONFIG_BLOCK

# 5. Firewall Rule
# Opening Port 5666 specifically for the Nagios Server
Write-Host "Configuring Windows Firewall for Port 5666..."
if (!(Get-NetFirewallRule -DisplayName "Nagios NRPE" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Nagios NRPE" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5666
}

# 6. Service Restart
Write-Host "Restarting NSClient++ service..."
Restart-Service nscp -Force

Write-Host "--- Installation Complete! Agent is listening for Nagios on Port 5666 ---" -ForegroundColor Green

# Cleanup
Remove-Item $TEMP_MSI