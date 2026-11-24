#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

foreach ($name in @("build", "dist", ".mygo")) {
    $path = Join-Path $root $name
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Removed $name"
    }
}

Get-ChildItem -Path $root -Filter "mygo_windows_*.syso" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force
Write-Host "Removed mygo syso files"
