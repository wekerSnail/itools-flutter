# Windows 11 AutoStart Fix Script
# Usage: Right-click > Run with PowerShell (Admin)

# Check Admin Rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Administrator rights required!" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run with PowerShell (Admin)'" -ForegroundColor Yellow
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Windows 11 AutoStart Fix Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Find executable
Write-Host "[Step 1] Finding application..." -ForegroundColor Green

$appPath = "E:\repo\itools-flutter\build\windows\x64\Release\itools.exe"

if (-not (Test-Path $appPath)) {
    Write-Host "ERROR: Application not found at: $appPath" -ForegroundColor Red
    Write-Host "Please compile the project first:" -ForegroundColor Yellow
    Write-Host "  flutter build windows --release" -ForegroundColor Gray
    exit 1
}

Write-Host "FOUND: $appPath" -ForegroundColor Green
Write-Host ""

# Step 2: Update registry
Write-Host "[Step 2] Updating registry..." -ForegroundColor Green

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$appName = "itools"
$absolutePath = (Resolve-Path $appPath).Path
$regValue = "`"$absolutePath`""

try {
    Set-ItemProperty -Path $regPath -Name $appName -Value $regValue -Force
    Write-Host "OK: Registry updated" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to update registry: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Verify
Write-Host "[Step 3] Verifying..." -ForegroundColor Green

$verify = Get-ItemProperty -Path $regPath -Name $appName -ErrorAction SilentlyContinue
if ($verify) {
    Write-Host "OK: Registry entry verified" -ForegroundColor Green
    Write-Host "Value: $($verify.$appName)" -ForegroundColor Gray
}
else {
    Write-Host "ERROR: Verification failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SUCCESS: AutoStart configured!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Settings > Apps > Startup - Enable the app if needed" -ForegroundColor Gray
Write-Host "2. Restart your computer" -ForegroundColor Gray
Write-Host "3. App should launch automatically after login" -ForegroundColor Gray
Write-Host ""

$null = Read-Host "Press Enter to exit"
