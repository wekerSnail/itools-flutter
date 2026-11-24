#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Proxy = "",
    [string]$GoProxy = "https://goproxy.cn,direct",
    [switch]$Minimized
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
    # A syso left by `mygo build` makes Go builds look packaged and use the
    # production data directory. Remove it so development keeps its own data.
    Get-ChildItem -Path $root -Filter "mygo_windows_*.syso" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force

    if ($Minimized) {
        & $go run . --minimized
    } else {
        & $go run .
    }
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
