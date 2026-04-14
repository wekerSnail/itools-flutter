# Windows 部署指南（统一版）

本文件整合原“快速部署”和“常见问题”内容，作为唯一部署入口。

## 1. 发布构建

在项目根目录执行：

- `flutter build windows --release`

产物目录：`build/windows/x64/runner/Release/`

## 2. 正确分发方式

> 不要只复制 `itools.exe`，必须复制 **整个 `Release` 目录**。

关键文件通常包括：

- `itools.exe`
- `flutter_windows.dll`
- `*_plugin.dll`
- `data/`（含 `flutter_assets/`、`icudtl.dat` 等）

可使用 `deploy.ps1` 进行打包拷贝。

## 3. 目标机器前置要求

- Windows 10/11 x64
- Visual C++ Redistributable（建议 2022/2023 最新）
- Node.js（仅 JS 脚本任务需要）

## 4. 快速排障

### 启动报缺少 DLL / 模块

- 原因：仅复制了可执行文件
- 处理：重新复制整个 `Release` 目录

### 启动即崩溃（VCRUNTIME / api-ms-win-crt）

- 原因：缺少 VC++ 运行时
- 处理：安装 Visual C++ Redistributable 后重试

### 资源缺失（字体/界面异常）

- 原因：`data/` 不完整
- 处理：重新分发完整目录

### JS 任务无法运行

- 原因：Node.js 未安装或未加入 PATH
- 处理：安装 Node.js 并验证 `node --version`

## 5. 验收建议

- [ ] 目标机可正常启动应用
- [ ] 托盘功能正常
- [ ] 定时任务可触发
- [ ] 日志页面可读且无严重错误
- [ ] 若使用 JS 任务，Node.js 依赖已验证

## 6. 维护约定

- 部署说明仅维护本文件。
- 如部署脚本变化，请同步更新“发布构建”和“正确分发方式”章节。
