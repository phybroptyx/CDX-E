# =============================================================================
# Install VirtIO Guest Tools
# =============================================================================
# Installs from the VirtIO-Win ISO mounted as secondary CD-ROM (D: or E:).
# Includes: VirtIO drivers, QEMU Guest Agent, SPICE agent, balloon driver.
#
# Compatibility: Windows Server 2008 R2+ / Windows 7+
# Uses Get-WmiObject fallback when Get-Volume is unavailable (legacy OS).
# =============================================================================

$ErrorActionPreference = "Stop"

# Find the VirtIO ISO drive letter
$virtioDrive = $null

# Try Get-Volume first (Server 2012+ / Windows 8+)
try {
    $vol = Get-Volume -ErrorAction Stop | Where-Object { $_.FileSystemLabel -like "*virtio*" }
    if ($vol) {
        $virtioDrive = "$($vol.DriveLetter):"
    }
} catch {
    # Get-Volume not available on legacy OS -- fall through to alternatives
}

# Fallback: WMI query for volume label (works on all Windows versions)
if (-not $virtioDrive) {
    $wmiVol = Get-WmiObject -Class Win32_Volume | Where-Object { $_.Label -like "*virtio*" }
    if ($wmiVol) {
        $virtioDrive = $wmiVol.DriveLetter
    }
}

# Final fallback: scan for guest-agent directory on available drives
if (-not $virtioDrive) {
    $virtioDrive = (Get-PSDrive -PSProvider FileSystem |
        Where-Object { Test-Path "$($_.Root)guest-agent" } |
        Select-Object -First 1).Root.TrimEnd('\')
    if (-not $virtioDrive) {
        Write-Error "VirtIO ISO drive not found"
        exit 1
    }
}

Write-Host "VirtIO drive detected at: $virtioDrive"

# Install QEMU Guest Agent
$gaMsi = Get-ChildItem -Path "$virtioDrive\guest-agent" -Filter "qemu-ga-x86_64.msi" -Recurse |
    Select-Object -First 1
if ($gaMsi) {
    Write-Host "Installing QEMU Guest Agent..."
    Start-Process msiexec.exe -ArgumentList "/i `"$($gaMsi.FullName)`" /qn /norestart" -Wait -NoNewWindow
} else {
    Write-Warning "QEMU Guest Agent MSI not found"
}

# Install SPICE Guest Tools (includes QXL driver and SPICE agent)
$spiceInstaller = Get-ChildItem -Path "$virtioDrive" -Filter "spice-guest-tools*.exe" -Recurse |
    Select-Object -First 1
if ($spiceInstaller) {
    Write-Host "Installing SPICE Guest Tools..."
    Start-Process $spiceInstaller.FullName -ArgumentList "/S" -Wait -NoNewWindow
} else {
    # Fallback: install virtio-win-guest-tools which bundles SPICE
    $virtioGt = Get-ChildItem -Path "$virtioDrive" -Filter "virtio-win-gt-x64.msi" -Recurse |
        Select-Object -First 1
    if ($virtioGt) {
        Write-Host "Installing VirtIO Guest Tools (includes SPICE)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$($virtioGt.FullName)`" /qn /norestart" -Wait -NoNewWindow
    } else {
        Write-Warning "No SPICE/VirtIO guest tools installer found"
    }
}

Write-Host "VirtIO guest tools installation complete."
