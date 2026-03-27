# Flutter 国内镜像源配置脚本
# 这个脚本设置环境变量以使用国内加速镜像

# 阿里云镜像源（推荐）
$env:PUB_HOSTED_URL = "https://pub.aliyuncs.com"
$env:FLUTTER_STORAGE_BASE_URL = "https://mirrors.aliyun.com/flutter"

# 或使用 Tsinghua 镜像源（备选）
# $env:PUB_HOSTED_URL = "https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
# $env:FLUTTER_STORAGE_BASE_URL = "https://mirrors.tuna.tsinghua.edu.cn/flutter"

# 执行 flutter pub get
Write-Host "正在使用镜像源下载依赖..." -ForegroundColor Green
Write-Host "PUB_HOSTED_URL: $env:PUB_HOSTED_URL" -ForegroundColor Cyan
Write-Host "FLUTTER_STORAGE_BASE_URL: $env:FLUTTER_STORAGE_BASE_URL" -ForegroundColor Cyan

flutter pub get

Write-Host "完成！" -ForegroundColor Green
