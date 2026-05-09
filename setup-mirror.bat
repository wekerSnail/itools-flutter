@echo off
REM Flutter 国内镜像源配置脚本 (Batch)
REM 使用 Flutter 中国社区 (CFUG) 官方镜像

echo 设置镜像源...
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

echo PUB_HOSTED_URL=%PUB_HOSTED_URL%
echo FLUTTER_STORAGE_BASE_URL=%FLUTTER_STORAGE_BASE_URL%
echo.
echo 使用 CFUG 官方镜像下载 Dart 包和 Flutter 资源...

flutter pub get

echo.
echo 完成！
pause
