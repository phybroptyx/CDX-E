# =============================================================================
# Install Windows Management Framework 3.0 (PowerShell 3.0)
# =============================================================================
# Required for: Windows Server 2008 R2 and Windows 7 SP1
# These ship with PowerShell 2.0 which lacks many modern cmdlets.
#
# The WMF 3.0 MSU is served via Packer's HTTP server from:
#   http/wmf_3.0/Windows6.1-KB2506143-x64.msu
#
# A reboot is required after installation -- use Packer's
# "windows-restart" provisioner AFTER this script.
# =============================================================================

$ErrorActionPreference = "Stop"

# Check if already at PS 3.0+
if ($PSVersionTable.PSVersion.Major -ge 3) {
    Write-Host "PowerShell $($PSVersionTable.PSVersion) already installed -- skipping WMF 3.0."
    exit 0
}

Write-Host "Current PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Installing Windows Management Framework 3.0..."

# Download from Packer HTTP server
$msuUrl = "http://{{.HTTPIP}}:{{.HTTPPort}}/wmf_3.0/Windows6.1-KB2506143-x64.msu"
$msuPath = "C:\Windows\Temp\Windows6.1-KB2506143-x64.msu"

Write-Host "Downloading WMF 3.0 from $msuUrl..."
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($msuUrl, $msuPath)

if (-not (Test-Path $msuPath)) {
    Write-Error "Failed to download WMF 3.0 MSU"
    exit 1
}

Write-Host "Installing WMF 3.0 (this may take several minutes)..."
$proc = Start-Process -FilePath "wusa.exe" `
    -ArgumentList "`"$msuPath`" /quiet /norestart" `
    -Wait -PassThru -NoNewWindow

# wusa exit codes: 0 = success, 3010 = success (reboot required), 2359302 = already installed
if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 2359302) {
    Write-Host "WMF 3.0 installation complete (exit code: $($proc.ExitCode))."
    Write-Host "A reboot is required to complete the installation."
} else {
    Write-Error "WMF 3.0 installation failed with exit code: $($proc.ExitCode)"
    exit 1
}

# Cleanup
Remove-Item -Path $msuPath -Force -ErrorAction SilentlyContinue
