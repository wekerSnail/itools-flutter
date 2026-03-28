# Flutter Windows 应用部署脚本
# 用途：将 Release 构建打包成可部署的文件夹

param(
    [string]$OutputDir = "D:\repos\itools-flutter\dist\itools",
    [switch]$CreateZip
)

$ReleaseDir = "D:\repos\itools-flutter\build\windows\x64\runner\Release"

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "Release 文件夹不存在，请先运行: flutter build windows --release"
    exit 1
}

# 清理并创建输出目录
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# 复制所有必要文件
Write-Host "正在复制 Release 文件..." -ForegroundColor Green
Copy-Item -Path "$ReleaseDir\*" -Destination $OutputDir -Recurse -Force

Write-Host "✓ 应用已打包到: $OutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "部署说明:" -ForegroundColor Cyan
Write-Host "1. 将 $OutputDir 文件夹复制到需要运行的电脑"
Write-Host "2. 在目标电脑上双击 itools.exe 运行"
Write-Host ""
Write-Host "必需检查（如果应用无法运行）:" -ForegroundColor Yellow
Write-Host "- 确保目标电脑已安装 Visual C++ Runtime"
Write-Host "  下载: https://support.microsoft.com/en-us/help/2977003"
Write-Host "- 不要单独复制 itools.exe，必须复制整个文件夹"
Write-Host ""

# 创建 ZIP 文件（可选）
if ($CreateZip) {
    $ZipPath = "$OutputDir.zip"
    Write-Host "正在创建 ZIP 文件..." -ForegroundColor Green
    Compress-Archive -Path $OutputDir -DestinationPath $ZipPath -Force
    Write-Host "✓ ZIP 文件已创建: $ZipPath" -ForegroundColor Green
}

