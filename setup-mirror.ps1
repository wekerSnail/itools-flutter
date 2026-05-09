# Flutter 国内镜像源配置脚本
# 使用 Flutter 中国社区 (CFUG) 官方镜像，与 Google 官方同步最及时

$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# 如遇到镜像异常，可临时切回官方源
# Remove-Item Env:PUB_HOSTED_URL -ErrorAction SilentlyContinue
# Remove-Item Env:FLUTTER_STORAGE_BASE_URL -ErrorAction SilentlyContinue

# 执行 flutter pub get
Write-Host "正在使用镜像源下载依赖..." -ForegroundColor Green
Write-Host "PUB_HOSTED_URL: $env:PUB_HOSTED_URL" -ForegroundColor Cyan
Write-Host "FLUTTER_STORAGE_BASE_URL: $env:FLUTTER_STORAGE_BASE_URL" -ForegroundColor Cyan

flutter pub get

Write-Host "完成！" -ForegroundColor Green
