# 开发环境镜像源配置

用于在网络受限场景下加速 Flutter / Dart 依赖下载。

## 1. 推荐方式

### PowerShell

- 运行 `setup-mirror.ps1`

### Batch

- 运行 `setup-mirror.bat`

## 2. 当前默认镜像

- `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`

使用 Flutter 中国社区 (CFUG) 官方镜像，与 Google 官方同步最及时、最可靠。

> 🔗 镜像说明：https://docs.flutter.cn/community/china

## 3. 手动临时设置（会话级）

PowerShell:

- `$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"`
- `$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"`
- `flutter pub get`

CMD:

- `set PUB_HOSTED_URL=https://pub.flutter-io.cn`
- `set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
- `flutter pub get`

## 4. 永久配置建议

通过 Windows 环境变量面板设置 `PUB_HOSTED_URL` 与 `FLUTTER_STORAGE_BASE_URL`，并重启终端/IDE 生效。

或使用 PowerShell 命令永久设置：

```powershell
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
```

## 5. 其他可用镜像

| 镜像 | PUB_HOSTED_URL | FLUTTER_STORAGE_BASE_URL | 备注 |
|------|----------------|--------------------------|------|
| **CFUG（推荐）** | `https://pub.flutter-io.cn` | `https://storage.flutter-io.cn` | 官方社区镜像，同步最及时 |
| 南京大学 | `https://mirror.nju.edu.cn/dart-pub` | `https://mirror.nju.edu.cn/flutter` | 速度快，社区维护 |
| 清华 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/dart-pub` | `https://mirrors.tuna.tsinghua.edu.cn/flutter` | Storage 偶尔不可用 |
| 上海交大 | `https://mirror.sjtu.edu.cn/dart-pub` | `https://mirror.sjtu.edu.cn/flutter` | Storage 偶尔不可用 |
| 官方（无镜像） | `https://pub.dev` | `https://storage.googleapis.com` | 需要良好网络 |

## 6. 故障排查

- 脚本无法执行：检查 PowerShell 执行策略（`RemoteSigned`）
- 仍然很慢：尝试切换镜像或清理缓存（`flutter pub cache clean`）
- 下载异常：使用 `flutter pub get -v` 查看详细输出
- 如果 CFUG 镜像暂时异常：可切换到南京大学镜像或清空环境变量回退到官方源
