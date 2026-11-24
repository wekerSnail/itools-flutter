#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Output = "build\itools.exe",
    [string]$Proxy = "",
    [string]$GoProxy = "https://goproxy.cn,direct",
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
    Write-Host "==> gofmt"
    $unformatted = & gofmt -l .
    if ($unformatted) {
        throw "These files are not formatted:`n$unformatted"
    }

    Write-Host "==> go vet"
    & $go vet ./...
    if ($LASTEXITCODE -ne 0) { throw "go vet failed" }

    if (-not $SkipTests) {
        Write-Host "==> go test"
        & $go test ./...
        if ($LASTEXITCODE -ne 0) { throw "go test failed" }
    }

    Write-Host "==> go build"
    $target = Join-Path $root $Output
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    # -H=windowsgui builds a GUI app: no console window on launch.
    & $go build -trimpath -ldflags "-s -w -H=windowsgui" -o $target .
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }

    Write-Host "Built: $target"
} finally {
    Pop-Location
}
