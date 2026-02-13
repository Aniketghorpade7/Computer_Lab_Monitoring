# 1. Stop and Remove the Service
Write-Host "--- Stopping and Removing NSClient++ Service ---" -ForegroundColor Yellow
if (Get-Service nscp -ErrorAction SilentlyContinue) {
    Stop-Service nscp -Force
    # This fully unregisters the service from Windows
    sc.exe delete nscp
}

# 2. Uninstall via Chocolatey (if installed that way)
Write-Host "--- Uninstalling NSCP via Chocolatey ---" -ForegroundColor Yellow
if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco uninstall nscp -y
}

# 3. Forcefully Remove the Program Files Directory
$NscPath = "${env:ProgramFiles}\NSClient++"
if (Test-Path $NscPath) {
    Write-Host "--- Removing installation folder: $NscPath ---" -ForegroundColor Yellow
    # This removes the folder and the nsclient.ini you created
    Remove-Item -Path $NscPath -Recurse -Force
}

# 4. Clean up the Firewall Rule
Write-Host "--- Removing Firewall Rule ---" -ForegroundColor Yellow
if (Get-NetFirewallRule -DisplayName "Nagios NRPE" -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName "Nagios NRPE"
}

# 5. Clean up the Temp MSI (from the failed script attempts)
$TempMsi = "$env:TEMP\nscp_installer.msi"
if (Test-Path $TempMsi) {
    Remove-Item $TempMsi -Force
}

Write-Host "--- PURGE COMPLETE: Windows PC is clean ---" -ForegroundColor Green