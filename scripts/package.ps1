#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Out = "dist",
    [string]$Platform = "windows/amd64",
    [string]$Proxy = "",
    [string]$GoProxy = "https://goproxy.cn,direct",
    [switch]$SkipInstaller,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Resolve-Go {
    $command = Get-Command go -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    $fallback = "C:\Users\rydeen\.local\share\go-sdk\go\bin\go.exe"
    if (Test-Path $fallback) {
        return $fallback
    }
    throw "Go 1.27+ was not found. Install Go or add it to PATH."
}

$go = Resolve-Go
$goBin = Split-Path -Parent $go
$env:PATH = $goBin + ";" + $env:PATH
$env:GOPROXY = $GoProxy
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
}

Push-Location $root
try {
    Write-Host "==> build checks"
    if ($SkipTests) {
        & (Join-Path $PSScriptRoot "build.ps1") -Output "build\itools.exe" -SkipTests
    } else {
        & (Join-Path $PSScriptRoot "build.ps1") -Output "build\itools.exe"
    }
    if ($LASTEXITCODE -ne 0) { throw "build.ps1 failed" }

    Write-Host "==> mygo build"
    $mygoArgs = @("tool", "mygo", "build", "-o", $Out, "-platform", $Platform)
    if ($SkipInstaller) { $mygoArgs += "-skip-installer" }
    & $go @mygoArgs
    if ($LASTEXITCODE -ne 0) { throw "mygo build failed" }

    Write-Host "Packaged: $(Join-Path $root $Out)"
} finally {
    Pop-Location
}
