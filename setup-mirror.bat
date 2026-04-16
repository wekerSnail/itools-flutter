@echo off
REM Flutter 国内镜像源配置脚本 (Batch)

echo 设置镜像源...
set PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
set FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter

echo PUB_HOSTED_URL=%PUB_HOSTED_URL%
echo FLUTTER_STORAGE_BASE_URL=%FLUTTER_STORAGE_BASE_URL%
echo.
echo 默认使用清华镜像下载 Dart 包和 Flutter 资源...

flutter pub get

echo.
echo 完成！
pause
