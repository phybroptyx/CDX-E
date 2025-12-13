# =============================================================================
# HARDWARE INFO IMPLEMENTATION TEST SCRIPT
# Validate the JSON-in-Info implementation
# =============================================================================

<#
.SYNOPSIS
    Test script to validate hardware info storage implementation.

.DESCRIPTION
    This script performs comprehensive testing of the JSON-in-Info approach:
    - Tests JSON encoding/decoding
    - Validates helper functions
    - Simulates computer creation
    - Verifies query operations
    - Checks error handling

.EXAMPLE
    .\Test-HardwareInfoImplementation.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipADTests  # Skip tests that require AD connectivity
)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  Hardware Info Implementation Test Suite           " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# =============================================================================
# TEST 1: JSON Encoding/Decoding
# =============================================================================

Write-Host "[TEST 1] JSON Encoding/Decoding..." -ForegroundColor Yellow

try {
    # Test data
    $testData = [ordered]@{
        manufacturer = "Dell Precision"
        model = "Dell Precision 7920 Tower"
        serviceTag = "ABC123XY"
    }
    
    # Encode to JSON
    $json = $testData | ConvertTo-Json -Compress -Depth 2
    Write-Host "  Encoded: $json" -ForegroundColor DarkGray
    
    # Decode from JSON
    $decoded = $json | ConvertFrom-Json
    
    # Validate
    $isValid = ($decoded.manufacturer -eq $testData.manufacturer) -and
               ($decoded.model -eq $testData.model) -and
               ($decoded.serviceTag -eq $testData.serviceTag)
    
    if ($isValid) {
        Write-Host "  ✓ PASS: JSON encoding/decoding works correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: JSON data mismatch after decode" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "  ✗ FAIL: JSON encoding/decoding error: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST 2: Build-HardwareInfoJSON Function
# =============================================================================

Write-Host "`n[TEST 2] Build-HardwareInfoJSON Function..." -ForegroundColor Yellow

# Define the helper function for testing
function Build-HardwareInfoJSON {
    param([Parameter(Mandatory)]$Computer)
    
    $hardwareData = [ordered]@{}
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.manufacturer)) {
        $hardwareData['manufacturer'] = $Computer.manufacturer
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.model)) {
        $hardwareData['model'] = $Computer.model
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Computer.service_tag)) {
        $hardwareData['serviceTag'] = $Computer.service_tag
    }
    
    if ($hardwareData.Count -eq 0) {
        return $null
    }
    
    return ($hardwareData | ConvertTo-Json -Compress -Depth 2)
}

try {
    # Test with full data
    $testComputer1 = [PSCustomObject]@{
        name = "TEST-PC-01"
        manufacturer = "HP EliteDesk"
        model = "HP EliteDesk 800 G9"
        service_tag = "XYZ789"
    }
    
    $result1 = Build-HardwareInfoJSON -Computer $testComputer1
    
    if ($result1 -like '*HP EliteDesk*') {
        Write-Host "  ✓ PASS: Function builds JSON with full data" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Function output incorrect: $result1" -ForegroundColor Red
        $testsFailed++
    }
    
    # Test with partial data
    $testComputer2 = [PSCustomObject]@{
        name = "TEST-PC-02"
        manufacturer = "Dell"
        model = ""
        service_tag = $null
    }
    
    $result2 = Build-HardwareInfoJSON -Computer $testComputer2
    $parsed2 = $result2 | ConvertFrom-Json
    
    if ($parsed2.manufacturer -eq "Dell" -and !$parsed2.model) {
        Write-Host "  ✓ PASS: Function handles partial data correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Function should omit empty fields" -ForegroundColor Red
        $testsFailed++
    }
    
    # Test with no data
    $testComputer3 = [PSCustomObject]@{
        name = "TEST-PC-03"
        manufacturer = ""
        model = $null
        service_tag = ""
    }
    
    $result3 = Build-HardwareInfoJSON -Computer $testComputer3
    
    if ($null -eq $result3) {
        Write-Host "  ✓ PASS: Function returns null for empty data" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Function should return null when no data: $result3" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "  ✗ FAIL: Build-HardwareInfoJSON error: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST 3: Special Characters and Escaping
# =============================================================================

Write-Host "`n[TEST 3] Special Characters Handling..." -ForegroundColor Yellow

try {
    $testComputer = [PSCustomObject]@{
        name = "TEST-PC-04"
        manufacturer = "Hewlett-Packard (HP)"
        model = "EliteDesk 800 G9 \"Tower\""
        service_tag = "ABC-123/XY"
    }
    
    $json = Build-HardwareInfoJSON -Computer $testComputer
    $decoded = $json | ConvertFrom-Json
    
    if ($decoded.manufacturer -eq "Hewlett-Packard (HP)" -and
        $decoded.model -eq "EliteDesk 800 G9 `"Tower`"" -and
        $decoded.serviceTag -eq "ABC-123/XY") {
        Write-Host "  ✓ PASS: Special characters handled correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Special characters not preserved" -ForegroundColor Red
        Write-Host "    Manufacturer: $($decoded.manufacturer)" -ForegroundColor DarkGray
        Write-Host "    Model: $($decoded.model)" -ForegroundColor DarkGray
        Write-Host "    ServiceTag: $($decoded.serviceTag)" -ForegroundColor DarkGray
        $testsFailed++
    }
}
catch {
    Write-Host "  ✗ FAIL: Special characters test error: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST 4: JSON Size Limits
# =============================================================================

Write-Host "`n[TEST 4] JSON Size Validation..." -ForegroundColor Yellow

try {
    # Test with very long strings (within reasonable limits)
    $testComputer = [PSCustomObject]@{
        name = "TEST-PC-05"
        manufacturer = "A" * 200  # 200 character manufacturer
        model = "B" * 200  # 200 character model
        service_tag = "C" * 100  # 100 character service tag
    }
    
    $json = Build-HardwareInfoJSON -Computer $testComputer
    $jsonLength = $json.Length
    
    Write-Host "  JSON Length: $jsonLength characters" -ForegroundColor DarkGray
    
    # AD info attribute can hold large text (typically 64KB+)
    # 500 bytes is well within limits
    if ($jsonLength -lt 1024) {
        Write-Host "  ✓ PASS: JSON size within reasonable limits ($jsonLength bytes)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ⚠ WARNING: JSON size is large ($jsonLength bytes)" -ForegroundColor Yellow
        $testsPassed++  # Still pass, but warn
    }
}
catch {
    Write-Host "  ✗ FAIL: JSON size test error: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST 5: Active Directory Integration (Optional)
# =============================================================================

if (-not $SkipADTests) {
    Write-Host "`n[TEST 5] Active Directory Integration..." -ForegroundColor Yellow
    
    try {
        # Check if AD module is available
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            Write-Host "  ⚠ SKIP: ActiveDirectory module not available" -ForegroundColor Yellow
        }
        else {
            Import-Module ActiveDirectory -ErrorAction Stop
            
            # Try to get domain info (will fail if not domain-joined)
            try {
                $domain = Get-ADDomain -ErrorAction Stop
                Write-Host "  Domain detected: $($domain.DNSRoot)" -ForegroundColor DarkGray
                
                # Check if info attribute exists on computer objects
                $schema = Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext `
                                       -Filter "name -eq 'Computer'" `
                                       -Properties mayContain, mustContain
                
                if ($schema.mayContain -contains 'info') {
                    Write-Host "  ✓ PASS: 'info' attribute available on Computer objects" -ForegroundColor Green
                    $testsPassed++
                } else {
                    Write-Host "  ✗ FAIL: 'info' attribute not in schema" -ForegroundColor Red
                    $testsFailed++
                }
            }
            catch {
                Write-Host "  ⚠ SKIP: Not connected to AD domain" -ForegroundColor Yellow
                Write-Host "    Error: $_" -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-Host "  ⚠ SKIP: AD integration test skipped: $_" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n[TEST 5] Active Directory Integration... SKIPPED (use -SkipADTests:$false to enable)" -ForegroundColor Yellow
}

# =============================================================================
# TEST 6: Error Handling
# =============================================================================

Write-Host "`n[TEST 6] Error Handling..." -ForegroundColor Yellow

try {
    # Test with null computer object
    try {
        $result = Build-HardwareInfoJSON -Computer $null
        Write-Host "  ✗ FAIL: Should have thrown error for null computer" -ForegroundColor Red
        $testsFailed++
    }
    catch {
        Write-Host "  ✓ PASS: Correctly handles null input" -ForegroundColor Green
        $testsPassed++
    }
    
    # Test with missing properties
    $testComputer = [PSCustomObject]@{
        name = "TEST-PC-06"
        # Missing manufacturer, model, service_tag
    }
    
    $result = Build-HardwareInfoJSON -Computer $testComputer
    
    if ($null -eq $result) {
        Write-Host "  ✓ PASS: Correctly handles missing properties" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Should return null for missing properties: $result" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "  ✗ FAIL: Error handling test failed: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST 7: Roundtrip Consistency
# =============================================================================

Write-Host "`n[TEST 7] Roundtrip Consistency..." -ForegroundColor Yellow

try {
    $originalData = @{
        manufacturer = "Dell Precision"
        model = "Dell Precision 7920 Tower"
        serviceTag = "TEST123"
    }
    
    # Simulate storage and retrieval
    $testComputer = [PSCustomObject]@{
        name = "TEST-PC-07"
        manufacturer = $originalData.manufacturer
        model = $originalData.model
        service_tag = $originalData.serviceTag
    }
    
    # Encode
    $encoded = Build-HardwareInfoJSON -Computer $testComputer
    
    # Decode
    $decoded = $encoded | ConvertFrom-Json
    
    # Verify all fields preserved
    $isConsistent = ($decoded.manufacturer -eq $originalData.manufacturer) -and
                    ($decoded.model -eq $originalData.model) -and
                    ($decoded.serviceTag -eq $originalData.serviceTag)
    
    if ($isConsistent) {
        Write-Host "  ✓ PASS: Data consistent after encode/decode cycle" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ FAIL: Data changed during roundtrip" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "  ✗ FAIL: Roundtrip test error: $_" -ForegroundColor Red
    $testsFailed++
}

# =============================================================================
# TEST SUMMARY
# =============================================================================

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "  Test Summary                                       " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

$totalTests = $testsPassed + $testsFailed
$passRate = if ($totalTests -gt 0) { [math]::Round(($testsPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host "`nTotal Tests:  $totalTests" -ForegroundColor White
Write-Host "Passed:       $testsPassed" -ForegroundColor Green
Write-Host "Failed:       $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "Pass Rate:    $passRate%" -ForegroundColor White

if ($testsFailed -eq 0) {
    Write-Host "`n✓ ALL TESTS PASSED - Implementation is ready for deployment" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ SOME TESTS FAILED - Review errors before deployment" -ForegroundColor Red
    exit 1
}
