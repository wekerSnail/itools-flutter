# Windows 11 AutoStart Diagnostic Script
# Usage: .\diagnose-autostart.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Windows 11 AutoStart Diagnostic Tool" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Registry
Write-Host "[Step 1] Checking Registry for AutoStart Entry" -ForegroundColor Green
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Write-Host "Path: $regPath" -ForegroundColor Yellow
Write-Host ""

try {
    $runItems = Get-ItemProperty -Path $regPath
    $found = $false
    
    foreach ($item in $runItems.PSObject.Properties) {
        if ($item.Name -match "itools" -or $item.Value -match "itools") {
            Write-Host "FOUND: $($item.Name)" -ForegroundColor Green
            Write-Host "Value: $($item.Value)" -ForegroundColor Cyan
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "NOT FOUND: No AutoStart entry for itools" -ForegroundColor Red
        Write-Host "Action: Run fix-autostart.ps1" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# 2. Check Startup Manager
Write-Host "[Step 2] Checking Windows Startup Manager" -ForegroundColor Green
$startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

if (Test-Path $startupPath) {
    try {
        $approved = Get-ItemProperty -Path $startupPath
        $disabled = $false
        foreach ($item in $approved.PSObject.Properties) {
            if ($item.Name -match "itools") {
                Write-Host "WARNING: App may be disabled in Startup Manager" -ForegroundColor Yellow
                Write-Host "Action: Settings > Apps > Startup" -ForegroundColor Yellow
                $disabled = $true
            }
        }
        if (-not $disabled) {
            Write-Host "OK: No restrictions found" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "INFO: Could not check startup manager" -ForegroundColor Gray
    }
}
else {
    Write-Host "OK: Startup manager not configured" -ForegroundColor Green
}

Write-Host ""

# 3. Check Executable
Write-Host "[Step 3] Checking Application Executable" -ForegroundColor Green
$exePath = "E:\repo\itools-flutter\build\windows\x64\Release\itools.exe"

if (Test-Path $exePath) {
    Write-Host "FOUND: $exePath" -ForegroundColor Green
    $file = Get-Item $exePath
    Write-Host "Size: $([Math]::Round($file.Length / 1MB, 2)) MB" -ForegroundColor Gray
}
else {
    Write-Host "NOT FOUND: $exePath" -ForegroundColor Red
    Write-Host "Action: flutter build windows --release" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Diagnosis Complete" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$null = Read-Host "Press Enter to exit"
