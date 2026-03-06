# =============================================================================
# Sysprep - Generalize Windows for Template
# =============================================================================
# Runs Sysprep with a custom unattend that bypasses OOBE on clone boot.
# This must be the LAST provisioner in the Packer build.
#
# Post-Sysprep clone behavior:
#   - OOBE is fully automated (no manual interaction)
#   - Built-in Administrator gets a known password
#   - cdxadmin account survives with its original password
#   - WinRM, RDP, ICMP firewall rules persist
#   - VM boots directly to Ctrl+Alt+Del login screen
# =============================================================================

$ErrorActionPreference = "Stop"

# =============================================================================
# Generate Sysprep Unattend (OOBE Bypass)
# =============================================================================
# This unattend handles ONLY the oobeSystem pass -- skipping all interactive
# prompts and setting the built-in Administrator password. Everything else
# (cdxadmin account, WinRM, RDP, ICMP) was configured in configure-base.ps1
# and survives Sysprep intact.
# =============================================================================

$unattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>IyTt+,uDhtR@.303</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
    </component>
  </settings>
</unattend>
'@

$unattendPath = "C:\Windows\Temp\sysprep-unattend.xml"
Write-Host "Writing Sysprep unattend to $unattendPath..."
Set-Content -Path $unattendPath -Value $unattendXml -Encoding UTF8

# =============================================================================
# Pre-Sysprep Cleanup
# =============================================================================

Write-Host "Preparing system for Sysprep..."

# Clear event logs
wevtutil el | ForEach-Object { wevtutil cl $_ } 2>$null

# Remove temporary files (except the unattend we just wrote)
Get-ChildItem -Path "C:\Windows\Temp" -Exclude "sysprep-unattend.xml" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# =============================================================================
# Run Sysprep
# =============================================================================

Write-Host "Running Sysprep (generalize + oobe + shutdown) with unattend..."
$sysprepPath = "C:\Windows\System32\Sysprep\sysprep.exe"
$sysprepArgs = "/generalize /oobe /shutdown /quiet /unattend:`"$unattendPath`""

Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -Wait -NoNewWindow
