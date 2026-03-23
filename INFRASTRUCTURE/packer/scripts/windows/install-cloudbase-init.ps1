# =============================================================================
# Install Cloudbase-Init
# =============================================================================
# Installs Cloudbase-Init for Windows cloud-init support in Proxmox.
# The installer MSI must be pre-staged on a local share or web server
# accessible from the build network (air-gapped environments).
# =============================================================================

$ErrorActionPreference = "Stop"

# Cloudbase-Init MSI location -- adjust to match your air-gapped staging
# Option 1: Local path (copied to VM by Packer file provisioner)
# Option 2: Internal HTTP server
$cloudbaseUrl = "http://{{.HTTPIP}}:{{.HTTPPort}}/cloudbase-init/CloudbaseInitSetup_x64.msi"
$downloadPath = "C:\Windows\Temp\CloudbaseInitSetup_x64.msi"

# TODO: Replace with actual staged location for air-gapped deployment
# For now, assume the MSI is available at the Packer HTTP server
Write-Host "Downloading Cloudbase-Init..."
Invoke-WebRequest -Uri $cloudbaseUrl -OutFile $downloadPath -UseBasicParsing

Write-Host "Installing Cloudbase-Init..."
$installArgs = @(
    "/i", $downloadPath,
    "/qn",
    "/norestart",
    "LOGGINGSERIALPORTNAME=COM1"
)
Start-Process msiexec.exe -ArgumentList $installArgs -Wait -NoNewWindow

# Configure Cloudbase-Init to use ConfigDrive (Proxmox default)
$confPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"
if (Test-Path $confPath) {
    $conf = Get-Content $confPath -Raw
    $conf = $conf -replace 'metadata_services=.*', 'metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService'
    Set-Content -Path $confPath -Value $conf
    Write-Host "Cloudbase-Init configured for ConfigDrive metadata."
}

Write-Host "Cloudbase-Init installation complete."
