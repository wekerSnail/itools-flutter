# Windows 工具集（Flutter）

一个可扩展的 Flutter Windows 桌面工具箱应用，支持多窗口、系统托盘、全局快捷键。

## 内置工具

- **定时任务** — JS 脚本 / 终端命令，支持秒/分/时/天/周/月周期调度
- **文件夹映射** — 集合管理常用目录，双击快速打开
- **JSON 格式化** — 格式化、压缩、转义、智能修复，代码编辑器支持语法高亮
- **备份还原** — 导出/导入所有工具数据

## 环境要求

- Flutter SDK（stable）
- Visual Studio C++ 桌面开发组件（Windows 构建必需）
- Node.js（可选，仅 JS 脚本任务需要）

## 快速开始

```bash
flutter pub get
flutter run -d windows
```

## 构建与部署

```bash
flutter build windows --release
```

产物目录：`build/windows/x64/runner/Release/`

**必须复制整个 Release 文件夹**，不能只复制 exe。可用 `deploy.ps1` 打包。

目标机器需要安装 [VC++ Redistributable 2022+](https://support.microsoft.com/en-us/help/2977003)。

## 文档

- [文档总览](docs/README.md)
- [部署指南](docs/deployment/README.md)
- [托盘诊断](docs/tray/README.md)
- [自启动排查](docs/AUTOSTART_TROUBLESHOOTING.md)
- [JSON 格式化](docs/features/json-formatter.md)
- [国内镜像配置](docs/development/mirror-setup.md)
