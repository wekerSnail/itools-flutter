# Windows 11 AutoStart - Final Verification

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Windows 11 AutoStart Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[Check 1] Registry Configuration" -ForegroundColor Green
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$appName = "Windows 工具集"
$regValue = Get-ItemProperty -Path $regPath -Name $appName -ErrorAction SilentlyContinue

if ($regValue) {
    Write-Host "FOUND: $($regValue.$appName)" -ForegroundColor Green
    if ($regValue.$appName -match "launch-elevated.vbs") {
        Write-Host "OK: Using elevated privilege launcher" -ForegroundColor Green
    }
    elseif ($regValue.$appName -match "itools.exe$") {
        Write-Host "WARNING: Using direct exe path (may require UAC fix)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "NOT FOUND: No AutoStart entry" -ForegroundColor Red
}

Write-Host ""

Write-Host "[Check 2] Launcher Script" -ForegroundColor Green
$vbsPath = "C:\Users\rydeen\Desktop\itools\launch-elevated.vbs"
if (Test-Path $vbsPath) {
    Write-Host "FOUND: Elevated privilege launcher" -ForegroundColor Green
}
else {
    Write-Host "NOT FOUND: $vbsPath" -ForegroundColor Red
}

Write-Host ""

Write-Host "[Check 3] Application Executable" -ForegroundColor Green
$exePath = "C:\Users\rydeen\Desktop\itools\itools.exe"
if (Test-Path $exePath) {
    $file = Get-Item $exePath
    Write-Host "FOUND: $exePath" -ForegroundColor Green
    Write-Host "Size: $([Math]::Round($file.Length / 1KB, 2)) KB" -ForegroundColor Gray
}
else {
    Write-Host "NOT FOUND: $exePath" -ForegroundColor Red
}

Write-Host ""

Write-Host "[Check 4] Startup Manager" -ForegroundColor Green
$startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
if (Test-Path $startupPath) {
    $approved = Get-ItemProperty -Path $startupPath -Name $appName -ErrorAction SilentlyContinue
    if ($approved) {
        Write-Host "WARNING: App may be disabled in Startup Manager" -ForegroundColor Yellow
        Write-Host "ACTION: Settings > Apps > Startup - Enable it" -ForegroundColor Cyan
    }
    else {
        Write-Host "OK: No restrictions" -ForegroundColor Green
    }
}
else {
    Write-Host "OK: No restrictions found" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your computer" -ForegroundColor Gray
Write-Host "2. App should launch automatically with elevated privileges" -ForegroundColor Gray
Write-Host "3. If not working, check Settings > Apps > Startup" -ForegroundColor Gray
Write-Host ""

$null = Read-Host "Press Enter to exit"
