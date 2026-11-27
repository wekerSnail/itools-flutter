# itools / Windows 工具集

用 Go + [MyGo](https://mygo.egoist.dev) 重写的 Windows 桌面工具集。原生 UI、单进程多窗口、托盘常驻，不依赖 WebView2、VC++ 运行库或 Visual Studio C++ 工具链。

## 功能

| 模块 | 状态 | 说明 |
|---|---|---|
| 主窗口 | 完成 | 工具网格、设置入口、托盘唤起、二次启动唤起 |
| 定时任务 | 完成 | 终端命令 / JS 脚本、变量替换、超时杀进程树、运行日志 |
| 文件夹映射 | 完成 | 集合与快捷方式管理、文件夹选择、双击打开 |
| JSON 格式化 | 完成 | 格式化、压缩、转义、反转义、智能修复、并排编辑 |
| 主题设置 | 完成 | 10 种色调（含跟随系统）、亮色 / 深色 / 纯黑 / 跟随系统、内嵌 Inter 字体 |
| 热键设置 | 完成 | 全局热键录制、冲突覆盖、清除、持久化 |
| 备份还原 | 完成 | 导出 / 导入 5 个受管 JSON 文件 |
| 开机自启 | 完成 | Windows 当前用户启动项，隐藏启动 |

## 环境要求

- Windows 10 / 11（x64）
- Go 1.27 或更高
- Node.js：仅当定时任务使用「JS 脚本」时需要，运行时从 `PATH` 查找 `node`

构建不需要 Bun、Node 构建链、Visual Studio C++ 工作负载。

## 开发

```powershell
# 使用脚本（推荐）
.\scripts\dev.ps1

# 或直接运行
go run .
```

以 `--minimized` 启动时只在托盘驻留：

```powershell
go run . --minimized
```

> `go tool mygo build` 会在仓库根目录留下 `mygo_windows_*.syso`，它会让普通 `go build` 被识别为打包版并使用 `%APPDATA%\itools`。`scripts\dev.ps1` 会自动清理它，保证开发版使用 `%APPDATA%\itools-dev`。

## 编译与打包

```powershell
# 格式检查 + go vet + go test + 编译到 build\itools.exe
.\scripts\build.ps1

# 运行测试并生成 Windows 安装包 / 可执行文件到 dist
.\scripts\package.ps1

# 不生成 NSIS 安装包，只生成可执行文件
.\scripts\package.ps1 -SkipInstaller

# 清理构建产物
.\scripts\clean.ps1
```

直接使用 Go 命令：

```powershell
go tool mygo build -o dist -platform windows/amd64
```

`mygo` CLI 通过 `go.mod` 的 tool 指令固定版本，不需要全局安装。打包产物在 `dist/`，包含可执行文件与安装包（NSIS 由 MyGo 自动下载）。

## 数据目录

| 版本 | 目录 |
|---|---|
| 打包版 | `%APPDATA%\itools` |
| 开发版（`go run` / `go tool mygo dev`） | `%APPDATA%\itools-dev` |

受管文件：

```
settings/theme.json
settings/hotkeys.json
scheduler/tasks.json
scheduler/logs.json
folder_mapping/collections.json
```

备份文件格式与原 Flutter 版本兼容：`schemaVersion: 2`、`app: "itools-flutter"`，导入时只接受上述 5 个文件。

## 项目结构

```
main.go                     入口：单实例、生命周期
mygo.json                   MyGo 应用配置
assets/                     托盘 PNG、打包图标
resources/                  应用资源（图标）
internal/
  app/                      服务装配、窗口管理、托盘、开机自启
  core/
    id/                     随机 ID
    jsontime/               与原版兼容的时间格式
    logging/                文件日志
    store/                  原子写 JSON 存储
    tools/                  工具元数据
  features/
    home/                   主窗口工具网格
    scheduler/              定时任务：模型、存储、调度、执行、UI
    folder_mapping/         文件夹映射
    json_formatter/         JSON 工具与编辑器 UI
    backup/                 备份导入导出
    settings/               设置与四个子页
  services/
    hotkeys/                全局热键与配置
  ui/
    icons/                  内置 Lucide SVG 图标
    theme/                  两套配色与 MyGo 主题映射
    widgets/                页头、卡片、空状态等共享组件
docs/
  mygo-rewrite-plan.md      重写方案与进度
  features/json-formatter.md JSON 功能行为说明
scripts/
  dev.ps1
  build.ps1
  package.ps1
  clean.ps1
```

## 开发说明

- UI 用 MyGo `ui` 包即时构建；阻塞操作（对话框、进程、文件）放在 goroutine，完成后通过 `Window.Invalidate` / `Window.Update` 回到主线程。
- 全局热键由 `mygo.GlobalShortcut` 注册；配置兼容旧版 `settings/hotkeys.json`。
- 定时任务引擎是单进程内的常驻服务，所有窗口关闭后仍在托盘后台运行。
- 终端命令通过临时 `.cmd` 执行，变量按原版规则转义；超时使用 `taskkill /T /F` 终止进程树。
- JSON 格式化保留键顺序与大整数精度，不使用 `map[string]any` 中转。
- MyGo 固定为 `v0.10.0`；升级需单独评审并跑完整回归。

## 许可证

见 [LICENSE](LICENSE)。
