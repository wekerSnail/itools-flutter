# 开发环境镜像源配置

用于在网络受限场景下加速 Flutter / Dart 依赖下载。

## 1. 推荐方式

### PowerShell

- 运行 `setup-mirror.ps1`

### Batch

- 运行 `setup-mirror.bat`

## 2. 当前默认镜像

- `PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub`
- `FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter`

如遇镜像异常，可临时切回官方 `pub.dev` / `storage.googleapis.com`。

## 3. 手动临时设置（会话级）

PowerShell:

- `$env:PUB_HOSTED_URL = "https://mirrors.tuna.tsinghua.edu.cn/dart-pub"`
- `$env:FLUTTER_STORAGE_BASE_URL = "https://mirrors.tuna.tsinghua.edu.cn/flutter"`
- `flutter pub get`

CMD:

- `set PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub`
- `set FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter`
- `flutter pub get`

## 4. 永久配置建议

通过 Windows 环境变量面板设置 `PUB_HOSTED_URL` 与 `FLUTTER_STORAGE_BASE_URL`，并重启终端/IDE 生效。

## 5. 故障排查

- 脚本无法执行：检查 PowerShell 执行策略（`RemoteSigned`）
- 仍然很慢：尝试切换镜像或清理缓存（`flutter pub cache clean`）
- 下载异常：使用 `flutter pub get -v` 查看详细输出
- 如果清华镜像暂时异常：清空 `PUB_HOSTED_URL` 与 `FLUTTER_STORAGE_BASE_URL`，直接回退到官方源后重试
