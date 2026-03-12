# =============================================================================
# CDX Base Configuration - All Windows Templates
# =============================================================================
# Provisions the cdxadmin account and enables WinRM, RDP, and ICMP.
# Runs during Packer build BEFORE Sysprep. All settings persist through
# Sysprep /generalize (local accounts, services, firewall rules, registry).
#
# Compatibility: Windows Server 2008 R2+ / Windows 7+
# Uses ADSI (universal) for account creation.
# Detects NetSecurity module; falls back to netsh advfirewall on legacy OS.
# =============================================================================

$ErrorActionPreference = "Stop"

# Detect legacy OS (Server 2008 R2 / Windows 7) -- no NetSecurity module
$hasNetSecurity = $null -ne (Get-Module -ListAvailable -Name NetSecurity -ErrorAction SilentlyContinue)
if ($hasNetSecurity) {
    Write-Host "NetSecurity module available -- using *-NetFirewallRule cmdlets."
} else {
    Write-Host "NetSecurity module not available (legacy OS) -- using netsh advfirewall."
}

# =============================================================================
# CDX Administrator Account
# =============================================================================
# Uses ADSI for universal compatibility (PS 2.0+, no module dependencies).
# The cdxadmin account survives Sysprep with its password intact.
# Only the built-in Administrator password is cleared by Sysprep.
# =============================================================================

$username = "cdxadmin"
$password = 'IyTt+,uDhtR@.303'

$computer = [ADSI]"WinNT://."
$existingUser = $computer.Children | Where-Object { $_.SchemaClassName -eq 'User' -and $_.Name -eq $username }

if ($existingUser) {
    Write-Host "CDX Administrator account ($username) already exists - updating password and flags."
    $user = [ADSI]"WinNT://./$username,User"
    $user.SetPassword($password)
} else {
    Write-Host "Creating CDX Administrator account ($username)..."
    $user = $computer.Create("User", $username)
    $user.SetPassword($password)
    $user.Put("FullName", "CDX Administrator")
    $user.Put("Description", "CDX Range Administrator - exercise admin and Ansible service account")
    $user.SetInfo()
}

# Set password to never expire (ADS_UF_DONT_EXPIRE_PASSWD = 0x10000)
$user.RefreshCache()
$flags = [int]$user.UserFlags.Value
$user.Put("UserFlags", ($flags -bor 0x10000))
$user.SetInfo()

# Ensure membership in local Administrators group
$admins   = [ADSI]"WinNT://./Administrators,Group"
$isMember = $admins.Invoke("Members") | ForEach-Object { ([ADSI]$_).InvokeGet("Name") } | Where-Object { $_ -eq $username }
if (-not $isMember) {
    $admins.Add($user.Path)
}

Write-Host "CDX Administrator account created and added to Administrators."

# =============================================================================
# WinRM Configuration
# =============================================================================
# Configures WinRM for HTTP Basic auth (unencrypted) on all network profiles.
# This is a lab/range environment -- production would use HTTPS + Kerberos.
# =============================================================================

Write-Host "Configuring WinRM..."

Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM

# Enable PSRemoting -- use -SkipNetworkProfileCheck on supported OS
$psVersion = $PSVersionTable.PSVersion.Major
if ($psVersion -ge 3) {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
} else {
    Enable-PSRemoting -Force
}

# Allow unencrypted traffic and basic auth (lab environment)
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Ensure HTTP listener exists — delete and recreate to guarantee clean state.
# Enable-PSRemoting above may have already created one; this is idempotent.
winrm delete winrm/config/Listener?Address=*+Transport=HTTP 2>&1 | Out-Null
winrm create winrm/config/Listener?Address=*+Transport=HTTP | Out-Null
Write-Host "WinRM HTTP listener configured."

# Firewall rule -- apply to ALL profiles (Domain, Private, Public)
if ($hasNetSecurity) {
    $rule = Get-NetFirewallRule -DisplayName "WinRM HTTP (CDX)" -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -DisplayName "WinRM HTTP (CDX)" `
            -Direction Inbound -Protocol TCP -LocalPort 5985 `
            -Action Allow -Profile Any -Enabled True | Out-Null
    }
    # Also ensure the built-in WinRM rules cover all profiles
    Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*" -ErrorAction SilentlyContinue |
        Set-NetFirewallRule -Profile Any -ErrorAction SilentlyContinue
} else {
    netsh advfirewall firewall add rule name="WinRM HTTP (CDX)" dir=in action=allow protocol=TCP localport=5985 profile=any
}

Write-Host "WinRM configured (HTTP/5985, Basic auth, all profiles)."

# =============================================================================
# ICMP Echo (Ping)
# =============================================================================

Write-Host "Enabling ICMP echo requests..."

if ($hasNetSecurity) {
    $icmpRule = Get-NetFirewallRule -DisplayName "ICMPv4 Echo Request (CDX)" -ErrorAction SilentlyContinue
    if (-not $icmpRule) {
        New-NetFirewallRule -DisplayName "ICMPv4 Echo Request (CDX)" `
            -Protocol ICMPv4 -IcmpType 8 `
            -Direction Inbound -Action Allow -Profile Any -Enabled True | Out-Null
    }
} else {
    netsh advfirewall firewall add rule name="ICMPv4 Echo Request (CDX)" dir=in action=allow protocol=ICMPv4:8,any profile=any
}

Write-Host "ICMP echo enabled (all profiles)."

# =============================================================================
# Remote Desktop (RDP)
# =============================================================================

Write-Host "Enabling Remote Desktop..."

# Enable RDP via registry
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" -Value 0

# Enable Network Level Authentication
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
    -Name "UserAuthentication" -Value 1

# Enable and broaden RDP firewall rules to all profiles
if ($hasNetSecurity) {
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue |
        Set-NetFirewallRule -Profile Any -ErrorAction SilentlyContinue
} else {
    netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes profile=any
}

Write-Host "Remote Desktop enabled (NLA, all profiles)."

# =============================================================================
Write-Host "CDX base configuration complete."
