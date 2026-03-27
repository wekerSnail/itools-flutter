@echo off
REM Flutter 国内镜像源配置脚本 (Batch)

echo 设置镜像源...
set PUB_HOSTED_URL=https://pub.aliyuncs.com
set FLUTTER_STORAGE_BASE_URL=https://mirrors.aliyun.com/flutter

echo PUB_HOSTED_URL=%PUB_HOSTED_URL%
echo FLUTTER_STORAGE_BASE_URL=%FLUTTER_STORAGE_BASE_URL%
echo.
echo 正在下载依赖...

flutter pub get

echo.
echo 完成！
pause
