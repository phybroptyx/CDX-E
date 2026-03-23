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
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
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

# Write to C:\Windows\Panther\ — the standard Windows search path for unattend
# on post-Sysprep clone first boot. Writing to Temp is insufficient: Sysprep
# cleans Temp during generalize, so clones boot without an unattend → OOBE.
$unattendPath = "C:\Windows\Panther\unattend.xml"
New-Item -ItemType Directory -Path "C:\Windows\Panther" -Force | Out-Null
Write-Host "Writing Sysprep unattend to $unattendPath..."
Set-Content -Path $unattendPath -Value $unattendXml -Encoding UTF8

# =============================================================================
# Pre-Sysprep Cleanup
# =============================================================================

Write-Host "Preparing system for Sysprep..."

# Clear event logs
$ErrorActionPreference = "SilentlyContinue"
wevtutil el | ForEach-Object { wevtutil cl $_ 2>&1 | Out-Null }
$ErrorActionPreference = "Stop"

# Remove temporary files (except the unattend we just wrote)
Get-ChildItem -Path "C:\Windows\Temp" -Exclude "sysprep-unattend.xml" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# =============================================================================
# Run Sysprep
# =============================================================================

Write-Host "Running Sysprep (generalize + oobe + shutdown) asynchronously..."
# Launched without -Wait so this script exits and returns control to Packer via
# WinRM before sysprep shuts the VM down. Packer shell-local provisioners
# (strip-nics, migrate-template-disk) run on the build host immediately after;
# migrate-template-disk polls for VM stopped state before initiating disk move.
$sysprepPath = "C:\Windows\System32\Sysprep\sysprep.exe"
$sysprepArgs = "/generalize /oobe /shutdown /quiet /unattend:`"$unattendPath`""

Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -NoNewWindow
Write-Host "Sysprep launched. VM will shut down when generalisation completes."
Start-Sleep -Seconds 5   # give sysprep time to lock its files before WinRM exits
