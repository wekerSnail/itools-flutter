# itools MyGo 重写方案（Agent 执行手册）

> 版本：2026-11-24  
> 状态：待 POC 验证  
> 适用对象：执行重写的 AI Agent / 开发者  
> 行为规范：当前 Flutter 代码（`lib/`）是唯一功能基准，本方案不替代源码细节  
> 技术栈：Go 1.27+ / MyGo v0.10.0 / MyGo Native UI（非 WebView）  
> 落地状态（2026-11-24）：Flutter 代码已移除，工程已迁移到仓库根目录；下文中的 `mygo/` 均指仓库根。P1–P5 已实现，P6 已完成本机构建/打包验证。

---

## 0. 使用方式

1. 先读 §1–§4，确认目标、约束与架构约定。
2. 按 §6 的阶段顺序执行；**阶段门禁未通过，不得进入下一阶段**。
3. 每个功能动手前，先读对应 Dart 源码（见 §9 映射表），再写 Go。
4. 所有新代码放在 `mygo/` 目录，不修改 `lib/`、`windows/`。
5. 发现 MyGo API 与文档不符时，停止猜测，记录到 `docs/mygo-api-notes.md`，并以 POC 实测结果为准。
6. 除非用户明确要求，不要执行 `git commit` / `git push`。

---

## 1. 目标

- 用 Go + MyGo 重写当前 Windows 桌面工具集，功能与现有版本 1:1。
- 单进程、多窗口、托盘常驻、全局热键、开机自启、后台定时任务。
- 数据目录与 JSON 文件格式保持兼容：`%APPDATA%\itools\...`。
- 交付物：`mygo build` 生成的安装包/可执行文件；原生 UI 不依赖 WebView2，不依赖 VC++ 运行库。
- 视觉保持现有设计语言（现代/轻奢两套主题、中文界面、卡片式布局）。

## 2. 非目标

- 不做 macOS / Linux / 移动端（代码保持可移植，但不在验收范围）。
- 不做 Web 前端窗口，不混用 WebView2 页面。
- 不新增功能、不改交互流程、不改中文文案（平台差异导致的必要调整除外）。
- 不追求动画 1:1；功能与布局优先，动效可作为 P2 可选。
- 不与 Flutter 版本同进程混跑；新旧版本只能作为两个独立可执行文件并存。

## 3. 已定技术决策

| 决策 | 选择 | 说明 |
|---|---|---|
| UI 形态 | MyGo Native UI | 工具类应用更适合自绘 UI；启动快、内存低、无 WebView2 依赖 |
| MyGo 版本 | 固定 `v0.10.0` | 重写期间不升级；升级必须单独评审并全量回归 |
| 工程配置 | `mygo.json` | 原生 UI 不需要 Bun/TS 工具链 |
| 应用名 | `itools` | 打包版 `PathUserData` 为 `%APPDATA%\itools`；dev 构建实测为 `%APPDATA%\itools-dev`，与生产数据隔离 |
| 进程模型 | 单进程多窗口 | 去掉 desktop_multi_window 的跨引擎转发、超时、死窗口清理 |
| 数据存储 | JSON 文件 + 原子写 | 与现有文件完全兼容，不引入数据库 |
| 状态管理 | 应用级 service + 每窗口 controller | 不引入 Riverpod 等价框架；状态只在主线程读写，后台通过 `Window.Update` 回投 |
| 窗口位置 | 不启用 `StateKey` | 现有行为是每次居中；`StateKey` 会改变行为 |
| 依赖策略 | 最小依赖 | 允许：`github.com/tidwall/pretty`、`golang.org/x/sys/windows`；其他依赖需说明理由 |

环境准备：

```powershell
go version                                  # 需要 1.27+
go install github.com/egoist/mygo/cmd/mygo@v0.10.0
mygo doctor                                 # 检查开发机
```

- 原生 UI 项目不需要 Bun、Node 构建链、Visual Studio C++ 工作负载。
- 若 `mygo doctor` 报错，先解决环境问题，不要开始编码。
- 在 `mygo/` 下执行 `go mod init itools`，并 `go get github.com/egoist/mygo@v0.10.0`。

本机已配置（2026-11-24）：

```powershell
# Go 1.27.4（便携 SDK）
C:\Users\rydeen\.local\share\go-sdk\go\bin\go.exe

# MyGo CLI 0.10.0
C:\Users\rydeen\go\bin\mygo.exe

# 依赖下载（本地代理 127.0.0.1:7890）
$env:GOPROXY = "https://goproxy.cn,direct"
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
```

工程最初用 `mygo init -template native` 初始化在 `mygo/`，落地后已迁移到仓库根目录。dev 运行的数据目录为 `%APPDATA%\itools-dev`，打包版为 `%APPDATA%\itools`。

---

## 4. 目标工程结构

```
mygo/
  go.mod
  go.sum
  mygo.json                     # 应用名、版本、图标、打包配置
  cmd/itools/main.go            # 入口：单实例、启动服务、创建主窗口
  assets/
    tray.png                    # 32x32 PNG（由 tray_icon.ico 转换）
    app.ico                     # 打包图标（首选 ICO）
    icons/*.svg                 # Lucide 图标子集
  internal/
    app/
      app.go                    # 服务容器、启动顺序、退出清理
      lifecycle.go              # 单实例、开机自启、--minimized、OnSecondInstance
      windows.go                # 主窗口 + 工具窗口注册表、显隐、销毁、标题
      tray.go                   # 托盘图标、菜单、左键/右键行为
      hotkeys.go                # 全局热键注册、冲突处理、配置加载
    core/
      store/store.go            # FileStore：路径解析、原子写、按路径串行化
      logging/logging.go        # slog 文件日志（简单滚动）
      eventbus/eventbus.go      # 应用内数据变更通知
      id/id.go                  # UUID 生成
      jsonutil/                 # JSON 校验、格式化辅助
    ui/
      theme/palette.go          # modern / luxury 两套色板 + 亮暗
      theme/tokens.go           # 间距、字号、圆角、阴影
      theme/manager.go          # 主题加载、系统亮暗跟随、广播重绘
      widgets/page_header.go    # PageHeader（标题/副标题/返回/操作区）
      widgets/section.go        # PageSectionHeader
      widgets/surface_card.go   # SurfaceCard / InteractiveSurfaceCard
      widgets/icon_container.go # 44x44 图标容器
      widgets/toast.go          # Toast 封装
      widgets/empty_state.go    # 空状态
      widgets/confirm_dialog.go # 确认对话框
      navigation/stack.go       # 窗口内页面栈（push/pop）
    features/
      home/                     # 主窗口工具网格
      settings/                 # 设置入口 + 四个子页
      folder_mapping/           # 集合/快捷方式
      json_formatter/           # JSON 工具
      scheduler/                # 定时任务
      backup/                   # 备份还原
    domain/                     # 跨 feature 的模型（如需）
  docs/
    mygo-api-notes.md           # 执行期记录 API 实测差异（由 Agent 创建）
```

分层约定：

- `features/*` 内按 `model.go` / `store.go` / `service.go` / `view.go` / `*_test.go` 拆分。
- `features/*` 不得直接互相引用；共享能力放 `internal/core` 或 `internal/app`。
- `app` 负责装配，不承载业务规则。
- UI 只在主线程执行；后台服务不得直接改 UI 结构。

---

## 5. 核心架构约定

### 5.1 启动与生命周期

启动顺序（`cmd/itools/main.go`）：

1. 确认 `mygo.json` 的 name 为 `itools`；不要在 dev 构建调用 `SetName` 把 dev 数据目录绑定到生产目录，保留 `itools-dev` 隔离。
2. `mygo.App.RequestSingleInstanceLock()`；失败直接返回。
3. `mygo.App.OnSecondInstance(...)`：显示并聚焦主窗口。
4. 初始化 `store`、`logging`、`theme manager`、`scheduler engine`、`hotkey manager`。
5. `mygo.App.SetOpenAtLogin` 状态读取；不主动改写，除非用户操作。
6. `mygo.App.WhenReady`：
   - 创建主窗口（`--minimized` 或 `WasOpenedAtLogin()` 时 `Hidden: true`）。
   - 创建托盘。
   - 加载并注册热键。
   - 启动调度器（与窗口无关，托盘驻留期间持续运行）。
7. `mygo.App.Run()`。

退出：

- 托盘菜单「退出」→ 停止调度器 → 落盘日志 → `mygo.App.Quit()`。
- `OnBeforeQuit` 中做最后一次日志 flush；不要在这里弹确认框。
- 主窗口关闭 = 隐藏，不退出；工具窗口按 §5.3 处理。

### 5.2 线程与状态

- MyGo 的 view 函数在主线程逐帧执行；**禁止**在 view 内做文件、进程、网络等阻塞操作。
- 后台 goroutine 修改 UI 相关状态时，统一通过 `win.Update(func(){ ... })` 回投主线程。
- 跨 goroutine 共享的数据（任务列表、日志、热键配置）用 `sync.RWMutex` 保护；UI 读取时取快照。
- 不用全局可变单例；所有 service 挂在 `app.App` 容器上，便于测试注入。
- 每个窗口一个 controller：
  - `HomeController`：页面栈、主题、工具网格。
  - `ToolController`：工具 ID、实例号、页面栈、局部状态。
- 数据变更通过 `eventbus` 广播；订阅者在主线程回调中调用 `win.Update`。

### 5.3 窗口模型

| 窗口 | 尺寸 | 最小尺寸 | 标题 | 关闭行为 |
|---|---|---|---|---|
| 主窗口 | 680×520 | 580×450 | `工具集` | 隐藏，托盘常驻 |
| 定时任务 | 950×700 | 800×550 | `定时任务` / `定时任务 N` | 主页打开：隐藏；临时实例：销毁 |
| 文件夹映射 | 900×650 | 700×500 | `文件夹映射` / `文件夹映射 N` | 同上 |
| JSON 格式化 | 1000×700 | 800×550 | `JSON 格式化` / `JSON 格式化 N` | 同上 |

规则：

- 所有窗口创建后居中；不使用 `StateKey`。
- 主页点击工具：
  - 若该工具已有窗口（含隐藏）→ 优先唤起常驻窗口；只有临时实例时唤起临时实例；不新建。
  - 都没有 → 创建常驻窗口，实例号 = 当前占用最大值 + 1。
- 工具窗口内「新窗口」仅 JSON 格式化提供：创建临时实例，标题带实例号，关闭即销毁。
- 常驻窗口关闭时隐藏；隐藏期间保留状态与实例号；重新打开时恢复。
- 不实现「隐藏 3 分钟后自动销毁」与「打开某工具时销毁其他隐藏窗口」：单进程下内存收益很小，且会丢失窗口状态。此为有意的行为简化，需在阶段总结中记录。
- 应用退出时销毁全部窗口。
- 主窗口永不销毁（隐藏即可），保证 `OnSecondInstance` 与托盘始终可唤起。

### 5.4 数据存储

- 根目录：`mygo.App.Path(mygo.PathUserData)`，应用名 `itools`，即 `%APPDATA%\itools`。
- 测试可注入临时目录；**测试禁止写真实 APPDATA**。
- 写入规则：
  - 先写 `<file>.tmp`，`Sync` 后 `os.Rename` 覆盖目标。
  - 同一路径的写入串行化（`map[string]*sync.Mutex`）。
  - 目录不存在时 `MkdirAll`。
- 读取规则：
  - 文件不存在 → 返回空。
  - 整个文件非法 JSON → 返回空并记录日志（不崩溃）。
  - 数组中的单条脏数据 → 跳过该条，保留其余。
- 文件格式见 §8。

### 5.5 主题与设计 Token

界面按 ApiGo（MyGo Native UI 开源工具）的设计语言绘制；旧的 modern / luxury 两套风格已移除。

配置文件 `settings/theme.json`：

```json
{ "themeAccent": "system", "themeMode": "system" }
```

- `themeAccent`：`system` | `blue` | `teal` | `green` | `indigo` | `purple` | `pink` | `orange` | `red` | `gray`；`system` 读取桌面强调色，取不到时回落 `#0078D4`。
- `themeMode`：`light` | `dark` | `black` | `system`。
- 旧文件里的 `themeStyle` 会被忽略，按默认（跟随系统强调色 + 跟随系统外观）加载。

中性色：

| Token | Light | Dark | Black |
|---|---|---|---|
| background | `#FFFFFF` | `#181818` | `#0F0F0F` |
| surface | `#FAFAFA` | `#1C1C1E` | `#171717` |
| surfaceHover | `#F3F4F6` | `#262626` | `#1F1F1F` |
| divider | `#F3F4F6` | `#1F1F1F` | `#1F1F1F` |
| border | `#E5E7EB` | `#2F2F33` | `#2A2A2E` |
| text | `#111827` | `#FAFAFA` | `#FAFAFA` |
| textSecondary | `#6B7280` | `#A3A3A3` | `#A1A1AA` |
| textMuted | `#9CA3AF` | `#737373` | `#71717A` |

强调色由 `themeAccent` 基色派生：hover 混白 18%，pressed 混黑 18%，图标底 12% alpha，selection 22% / 32%，focus 55% / 65%；主色上的文字按亮度阈值 150 在白色与 `#111827` 之间选择。

设计 token：

- 字号：tiny 11 / body 13 / title 15 / heading 18 / display 22；字重 400 / 500 / 600 / 700。
- 圆角：卡片 6、控件 4、图标底 6、对话框 8。
- 度量：顶栏 48、工具条 40、列表行 52、控件高 28–32；页面内边距 20，4pt 栅格。
- 字体：内嵌 Inter Variable（`assets/fonts/InterVariable.ttf`，OFL），中文回落系统字体。
- 卡片默认无阴影；只有对话框使用 `Shadow(0, 10, 30, 0, rgba(0, 0, 0, 0.3))`。
- 主题切换：更新全局 palette 后对所有窗口调用 `Invalidate` 触发重绘；`system` 模式同时订阅 `mygo.Theme.OnUpdated`，`Apply` 时读取 `c.Preferences().Accent`。

### 5.6 页面导航

- 主窗口与工具窗口都使用「窗口内页面栈」，等价于 Flutter `Navigator.push/pop`：
  - `Stack []Page`；`Push(page)`、`Pop()`、`Top()`。
  - `PageHeader` 的返回按钮调用 `Pop`。
- 主窗口页面：`Home` → `Settings` → `ThemeSettings` / `HotkeySettings` / `BackupSettings` / `AutostartSettings`。
- 定时任务窗口页面：`SchedulerList` → `TaskEditor` / `TaskLogs`。
- 其他工具窗口只有根页面，弹窗使用对话框。
- 页面切换动效可选；先用直接切换，避免在 POC 前投入动画。

### 5.7 错误处理与日志

- service 返回 `error`；UI 层捕获后显示中文 Toast 或错误卡片。
- 用户可见错误文案尽量与现有实现一致。
- 日志：
  - `log/slog` 输出到 `%APPDATA%\itools\logs\app.log`。
  - 单文件超过 5MB 时轮转为 `app.log.1`，最多保留 2 个。
  - 调度器任务输出仍写入 `scheduler/logs.json`（用户可见），不要写入 app.log。
- 后台 goroutine 必须 `recover`，避免单个任务 panic 导致整个应用退出。

---

## 6. 分阶段执行计划

### 阶段进度表

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 | POC / 技术验证 | 部分完成：本机 Go 1.27.4 + MyGo 0.10.0 已装；窗口、托盘、单实例、主题渲染已验证；中文 IME 与托盘交互待人工验证 |
| P1 | 工程骨架 + Shell | 完成：主窗口、托盘、主题、工具网格、设置入口 |
| P2 | 文件夹映射 | 完成：集合/快捷方式 CRUD、目录选择、双击打开、持久化与容错 |
| P3 | JSON 格式化 | 完成：保序格式化、压缩、转义/反转义、智能修复、并排编辑器、新窗口 |
| P4 | 定时任务 | 完成：命令/JS、变量转义、超时杀进程树、日志、列表/编辑/日志页 |
| P5 | 设置 / 热键 / 备份 | 完成：主题、热键录制与冲突、备份导入导出、开机自启 |
| P6 | 打包与全量回归 | 基本完成：构建/测试/打包脚本通过，产物 13.1 MB；安装包与干净机回归待人工 |

---

### P0：POC / 技术验证（硬门禁）

目的：在投入功能重写前，验证 MyGo 在 Windows 上的关键能力。POC 代码可以放在 `mygo/poc/`，验证完成后删除或合并。

必须验证的 8 项：

1. **中文输入法**
   - 在 `ui.TextInput`、`ui.TextArea`、`ui/editor` 中输入微软拼音。
   - 候选窗位置正确；组合文本不丢失；Enter/Escape 不误触快捷键。
   - 中文注释、中文路径、粘贴多行文本正常。
2. **多窗口**
   - 主窗口 + 2 个工具窗口；尺寸/最小尺寸/居中生效。
   - 关闭主窗口 → 隐藏，应用继续运行；关闭工具窗口 → 隐藏或销毁。
   - 所有窗口隐藏后进程仍存活，托盘可用。
3. **托盘**
   - PNG 图标显示；左键显示主窗口；右键弹出菜单。
   - 菜单项可点击；动态修改菜单文本（开机自启开/关）生效。
4. **全局热键**
   - 注册 `Ctrl+Shift+1`，应用在后台时触发。
   - 修改配置后重新注册；旧热键失效；冲突时不崩溃。
5. **开机自启**
   - `SetOpenAtLogin(true/false)` 生效；`WasOpenedAtLogin()` 能区分登录启动。
   - 登录启动时主窗口隐藏、托盘存在、调度器运行。
6. **单实例**
   - 第二次启动不创建新进程窗口，而是唤起已运行实例的主窗口。
7. **后台调度**
   - 所有窗口隐藏时执行 `cmd /c` 与 `node` 脚本。
   - 超时后能杀掉整个进程树（`taskkill /T /F` 或 Job Object）。
   - 日志写入 `scheduler/logs.json` 正常。
8. **编辑器与打包**
   - `ui/editor` 打开 1MB JSON，滚动/高亮/输入不卡顿。
   - `mygo build` 产出可运行安装包；在干净的 Win10/Win11（无 VC++ 运行库、无 WebView2）上可启动。

退出标准：

- 8 项全部通过，或存在明确可接受的 workaround。
- 出现以下任一情况 → **停止重写**，向用户报告并建议保留 Flutter：
  - 中文 IME 在输入框或编辑器中不可用/候选窗错位严重。
  - 多窗口、托盘、全局热键在 Windows 上存在硬阻塞。
  - 所有窗口隐藏后应用无法存活。
  - 打包产物在干净机器上无法启动，且无法通过配置解决。

交付：

- `docs/mygo-api-notes.md`：逐项记录实测 API、可用性、限制、workaround。
- POC 结论表：通过 / 有条件通过 / 不通过。

---

### P1：工程骨架 + Shell

任务：

1. 创建 `mygo/` Go module、`mygo.json`、`cmd/itools/main.go`。
2. 实现 `internal/core/store`（原子写、按路径串行、测试注入目录）。
3. 实现 `internal/core/logging`。
4. 实现 `internal/ui/theme`（两套 palette、亮暗、系统跟随）。
5. 实现 `internal/ui/widgets`：PageHeader、SectionHeader、SurfaceCard、InteractiveSurfaceCard、IconContainer、EmptyState、Toast、ConfirmDialog。
6. 实现 `internal/app`：
   - 单实例、`--minimized`、`OnSecondInstance`。
   - 主窗口创建/隐藏/显示。
   - 托盘（图标、菜单、左键/右键）。
   - 开机自启读写。
   - 热键管理器（先只注册 `open_main_window`）。
7. 实现主窗口 `Home`：
   - 3 个工具卡片（定时任务、文件夹映射、JSON 格式化），4 列网格，最大宽度 1200。
   - 右上角「设置」按钮进入设置页。
   - 点击工具卡片打开对应占位窗口。
8. 图标资源：
   - 将 `assets/tray_icon.ico` 转为 32×32 的 `mygo/assets/tray.png`（可用下面的 PowerShell 片段）。
   - 在 `lib/` 中搜索 `LucideIcons.` 得到完整图标清单，从 Lucide 复制对应 SVG 到 `mygo/assets/icons/`（只放实际用到的）。
   - `windows/runner/resources/app_icon.ico` 复制为 `mygo/assets/app.ico` 用于打包。

```powershell
Add-Type -AssemblyName System.Drawing
$ico = New-Object System.Drawing.Icon("assets/tray_icon.ico", 32, 32)
$ico.ToBitmap().Save("mygo/assets/tray.png", [System.Drawing.Imaging.ImageFormat]::Png)
```

验收：

- `go vet ./...`、`go test ./...`、`go build ./...` 通过。
- 双击启动 → 主窗口居中显示；托盘存在；关闭主窗口后应用仍在托盘。
- 再次启动 → 唤起已有主窗口。
- `--minimized` 启动 → 不显示主窗口，托盘存在。
- 热键「打开主窗口」在后台可触发。
- 主题切换（modern/luxury、light/dark/system）在主窗口即时生效。
- 工具窗口可按规格打开、显示占位内容、关闭后隐藏/销毁。

---

### P2：文件夹映射

先读：

- `lib/features/folder_mapping/domain/folder_mapping.dart`
- `lib/features/folder_mapping/data/folder_mapping_store.dart`
- `lib/features/folder_mapping/presentation/folder_mapping_page.dart`
- `lib/features/folder_mapping/presentation/widgets/*`
- `lib/features/folder_mapping/application/*`

任务：

1. 模型：`FolderCollection`、`FolderShortcut`，字段与 JSON 完全一致。
2. Store：`folder_mapping/collections.json`，单条脏数据跳过。
3. 页面：
   - 左栏集合列表：新建、重命名、删除（删除需确认）。
   - 右栏快捷方式卡片：新建、编辑、删除（确认）、双击打开。
   - 未选择集合时，新建快捷方式提示「请先创建并选择一个集合」。
4. 文件夹选择：`mygo.Dialog.Open` + `Directory: true`。
5. 打开目录：`mygo.Shell.OpenPath(path)`；失败 Toast。
6. 持久化：每次 CRUD 后立即保存；失败 Toast 并回滚内存状态（或重新加载）。
7. 空状态、搜索/过滤（若现有页面有，则保留；无则不加）。

验收：

- 新建集合/快捷方式后重启应用，数据仍在。
- 删除集合后，其快捷方式一并消失。
- 双击卡片能用资源管理器打开目录。
- 路径包含 `&`、`|`、中文、空格时不出现命令注入或打开失败。
- 损坏的 `collections.json` 不导致应用崩溃。
- 单元测试：序列化/反序列化、脏数据跳过、CRUD 持久化。

---

### P3：JSON 格式化

先读：

- `lib/features/json_formatter/domain/json_formatter_service.dart`
- `lib/features/json_formatter/presentation/json_formatter_page.dart`
- `lib/features/json_formatter/presentation/widgets/*`
- `docs/features/json-formatter.md`

任务：

1. 实现 `JsonService`：
   - `Format(input, indent)`：保留键顺序；默认 2 空格缩进。
   - `Minify(input)`：保留键顺序。
   - `Escape(input)` / `Unescape(input)`：逐字符移植现有实现。
   - `IsValid(input)` / `ErrorMessage(input)`。
   - `SmartRepair(input)`：严格按现有 6 步策略移植。
2. **键顺序是硬要求**：不要使用 `map[string]any` + `json.Marshal`，否则键会按字母排序。使用 `github.com/tidwall/pretty` 的 `PrettyOptions` / `Ugly`，或等价的流式保留原始顺序方案。
3. 数字精度：不要经过 `float64` 中转；`pretty` 直接处理原始字节。
4. 页面：
   - 左右分栏，可拖拽，比例限制 20%–80%。
   - 输入/输出编辑器：JSON 高亮、行号、滚动条；输出是否只读按现有实现。
   - 工具栏：格式化、压缩、转义、反转义、智能修复、交换、复制、清空、新窗口。
   - 输入变化 300ms 防抖校验；状态栏显示「有效 / 无效 + 错误信息」。
   - 复制输出到剪贴板并 Toast。
5. 「新窗口」：创建临时 JSON 格式化窗口，关闭即销毁。
6. 空输入与非法输入的按钮行为与现有实现一致。

验收：

- `{"b":1,"a":2}` 格式化后仍是 `b` 在前、`a` 在后。
- 大整数（超过 2^53）格式化后不丢精度。
- 现有 Dart 版本的所有修复策略样例在 Go 版本中得到相同结果。
- 1MB JSON 格式化在可接受时间内完成，UI 不冻结。
- 分栏拖拽、复制、交换、清空、新窗口行为正确。
- 单元测试覆盖：format/minify/escape/unescape/repair/valid/error，至少 30 个表驱动用例。

---

### P4：定时任务

先读：

- `lib/features/scheduler/domain/scheduled_task.dart`
- `lib/features/scheduler/data/scheduler_store.dart`
- `lib/features/scheduler/data/task_log_buffer.dart`
- `lib/features/scheduler/application/scheduler_service.dart`
- `lib/features/scheduler/application/task_runner.dart`
- `lib/features/scheduler/application/cmd_escape.dart`
- `lib/features/scheduler/presentation/*`

任务：

1. 模型：`ScheduledTask`、`TaskVariable`、枚举与 JSON 字段完全一致。
2. Store：`scheduler/tasks.json`；整个文件损坏返回空；单条脏数据跳过；`intervalValue < 1` 时钳制为 1。
3. 调度引擎：
   - 1 秒 ticker；按 `startAt + intervalValue × intervalUnit` 计算 occurrence index。
   - 同一任务跨周期重入时跳过，并写日志「仍在执行中，跳过本次触发」。
   - `month` 单位按现有 `addMonths` 算法逐行移植，包含月末钳制。
   - 引擎随应用启动，不依赖窗口。
4. 执行器：
   - 终端命令：变量替换 `{{key}}`，使用现有 `escapeCmdLiteral` 规则；写入临时 `.cmd`；`cmd /c` 执行。
   - JS 脚本：检测 `node`（`exec.LookPath` 并缓存）；临时 `.js` 前缀 `const vars = <json>;`；`node` 执行。
   - stdout/stderr 逐行写入日志，前缀与现有实现一致。
   - 默认超时 600 秒；任务可配置 `timeoutSeconds`。
   - 超时杀进程树：优先 Windows Job Object，若实现成本高则用 `taskkill /T /F /PID`。
   - 临时文件与目录在 finally 中清理。
5. 日志缓冲：
   - 最多 2000 条，保留 5 天，最新在 UI 顶部。
   - 通知节流 120ms，落盘防抖 300ms。
   - 文件 `scheduler/logs.json`，条目 `{createdAt, message}`。
6. 页面：
   - 任务列表：名称、类型、启用开关、执行频率描述、开始时间、变量数、编辑/删除/立即运行。
   - 空状态与「添加任务」按钮。
   - 运行日志页：倒序展示，自动滚动到底部（若现有实现如此）。
   - 任务编辑器：名称、类型（终端命令 / JS 脚本）、命令或脚本、开始时间、间隔值、间隔单位、变量列表（名称/类型/值）、超时秒数。
   - 立即运行：提交后显示「任务已提交执行」，执行完成后刷新日志；不要阻塞 UI。
7. 单进程后删除所有跨窗口转发与文件监听同步逻辑。

验收：

- 创建 1 分钟后执行的命令任务，关闭所有窗口，任务仍按时执行并写日志。
- JS 任务输出带 `[JS]` 前缀；Node 不存在时提示明确。
- 超时任务被终止，且子进程树不残留（用 `cmd /c ping -t` 或 `node` 长任务验证）。
- 同任务重叠触发被跳过。
- 月末/跨年/闰年调度计算正确（表驱动测试）。
- `{{var}}` 替换后的命令无法注入 `& | > %`（转义测试）。
- 重启应用后任务与日志仍在；`tasks.json` 损坏不崩溃。
- 编辑任务后立即生效，无需重启。

---

### P5：设置 / 热键 / 备份

先读：

- `lib/features/settings/presentation/settings_page.dart`
- `lib/features/settings/presentation/theme_settings_page.dart`
- `lib/features/settings/presentation/autostart_settings_page.dart`
- `lib/features/settings/presentation/backup_settings_page.dart`
- `lib/features/settings/data/theme_service.dart`
- `lib/features/hotkey_settings/**`
- `lib/features/backup_restore/**`

任务：

1. 设置入口页：四个菜单卡片（主题设置、热键设置、备份还原、开机自启），样式与现有卡片一致。
2. 主题页：两套风格卡片 + 亮/暗/跟随系统选择；切换即时生效并持久化。
3. 热键页：
   - 动作列表：打开主窗口 + 3 个工具打开动作，ID 与现有 `open_main_window` / `open_<toolId>` 一致。
   - 录制对话框：捕获下一组按键；显示 `Ctrl + Shift + A` 形式。
   - 冲突检测：同组合只允许一个动作；保存前提示覆盖。
   - 清除热键、保存后立即重新注册。
   - 配置 `settings/hotkeys.json` 字段兼容：`actionId`、`enabled`、`modifiers`、`key`、`keyId`；可新增 `accelerator` 但不得删除旧字段。
4. 开机自启页：读取状态、开关、失败提示；不需要再通过 PowerShell 查注册表，直接用 `OpenAtLogin()`。
5. 备份页：
   - 显示当前将备份的文件数量与列表。
   - 导出：保存对话框，文件名 `itools_backup_YYYYMMDD_HHmmss.json`，2 空格缩进。
   - 导入：打开对话框 → 校验 → 写入 → 刷新主题/热键/任务列表。
   - 备份格式：`schemaVersion: 2`、`app: "itools-flutter"`、`exportedAt`、`files: { 相对路径: JSON 字符串 }`。
   - 导入白名单：仅允许 5 个受管文件；拒绝 `../`、未知 key、非字符串 value。
6. 导入后广播数据变更，让已打开的工具窗口刷新。

验收：

- 主题切换即时生效，重启后保持。
- 热键录制、冲突覆盖、清除、重启后保持；与现有配置兼容。
- 开机自启开关在系统「启动应用」中可见（或注册表 Run 项存在）。
- 备份导出后再导入，5 个文件内容一致；应用状态刷新。
- 导入包含路径穿越/未知 key 的文件时，拒绝并提示，不写入任何文件。
- 备份文件版本高于 2 时拒绝导入。

---

### P6：打包与全量回归

任务：

1. `mygo build` 配置：应用名、版本 `1.0.0`、图标、安装包/便携版。
2. 清理 POC 代码与调试开关。
3. 全量手动回归（见 §7.3）。
4. 性能对比：启动时间、常驻内存、安装包体积、JSON 1MB 格式化耗时。
5. 数据迁移：用**打包版**（dev 版数据目录是 `itools-dev`）在干净用户环境启动，读取现有 `%APPDATA%\itools`，验证任务、日志、集合、主题、热键全部可用；再反向用旧版读取新版写入的文件。
6. 编写发布说明（用户要求时才创建发布文档）。

验收：

- 干净 Win10/Win11 上安装/运行成功，无 VC++/WebView2 依赖。
- 托盘、热键、自启、单实例、后台任务全部通过。
- 数据文件与旧版本双向兼容（旧版写入的文件新版可读，新版写入的文件旧版可读）。
- 性能不低于现有 Flutter 版本，且启动/内存/体积有明确改善。

---

## 7. 测试策略

### 7.1 单元测试（必须）

| 模块 | 测试点 |
|---|---|
| store | 原子写、并发写、损坏文件、目录创建、测试注入 |
| json_formatter | format/minify/escape/unescape/repair/valid、键顺序、大整数 |
| scheduler | occurrence index（秒/分/时/天/周/月）、月末、闰年、跨年、interval 钳制 |
| cmd_escape | `%`、`"`、`!`、换行、`&`、`|`、中文、空值 |
| hotkey | signature、冲突、accelerator 映射、旧配置迁移 |
| backup | 白名单、路径穿越、版本、非字符串 value、往返 |
| folder_mapping | 序列化、脏数据跳过、CRUD |

### 7.2 UI 测试（尽量）

- 使用 `ui.Tester` 对关键视图做冒烟测试：主窗口渲染、工具卡片点击、设置页导航、表单校验。
- 不要求像素级截图对比；优先验证交互与状态。

### 7.3 手动回归矩阵

- Windows 10 22H2、Windows 11 23H2+。
- 缩放 100% / 125% / 150%，混合 DPI 双屏。
- 微软拼音输入法：输入框、代码编辑器、搜索框。
- 主窗口关闭/托盘唤起/二次启动。
- 3 个工具窗口多开、隐藏、重开、退出时全部关闭。
- 热键在应用后台/前台触发。
- 开机自启 + 隐藏启动 + 定时任务执行。
- 备份导出/导入/损坏文件/路径穿越。
- 长时间运行 8 小时：内存不持续增长，日志不无限增长。

---

## 8. 数据兼容

根目录：`%APPDATA%\itools`。

### 8.1 `scheduler/tasks.json`

数组，元素字段：

```json
{
  "id": "uuid",
  "name": "任务名",
  "type": "terminalCommand | jsScript",
  "command": "echo hello",
  "startAt": "2026-01-01T09:00:00.000",
  "intervalValue": 5,
  "intervalUnit": "second | minute | hour | day | week | month",
  "variables": [
    { "name": "foo", "type": "string | number | boolean | object", "value": "bar" }
  ],
  "enabled": true,
  "script": "console.log(vars.foo)",
  "timeoutSeconds": 600
}
```

兼容要求：

- 读取时兼容旧字段 `intervalMinutes`（映射为 `intervalValue` + `minute`）。
- 读取时 `variables` 兼容对象形式（旧格式），转换为数组。
- `intervalValue < 1` 钳制为 1。
- 写入时保持上述字段与类型。

### 8.2 `scheduler/logs.json`

```json
[
  { "createdAt": "2026-01-01T09:00:00.000", "message": "[任务名] 输出" }
]
```

### 8.3 `folder_mapping/collections.json`

```json
[
  {
    "id": "uuid",
    "name": "集合名",
    "createdAt": "2026-01-01T09:00:00.000",
    "items": [
      {
        "id": "uuid",
        "name": "快捷方式名",
        "targetPath": "D:\\Projects",
        "createdAt": "2026-01-01T09:00:00.000"
      }
    ]
  }
]
```

### 8.4 `settings/theme.json`

```json
{ "themeAccent": "system", "themeMode": "system" }
```

### 8.5 `settings/hotkeys.json`

```json
[
  {
    "actionId": "open_json_formatter",
    "enabled": true,
    "modifiers": ["ctrl", "shift"],
    "key": "J",
    "keyId": 461,
    "accelerator": "Ctrl+Shift+J"
  }
]
```

- `keyId` 为旧版 USB HID usage；新版本可继续写入，也可只写 `accelerator`。
- 读取优先级：`accelerator` > `keyId` > `key`。
- 动作 ID 固定：`open_main_window`、`open_scheduler`、`open_folder_mapping`、`open_json_formatter`。

### 8.6 备份文件

```json
{
  "schemaVersion": 2,
  "app": "itools-flutter",
  "exportedAt": "2026-01-01T09:00:00.000",
  "files": {
    "scheduler/tasks.json": "[...]",
    "scheduler/logs.json": "[...]",
    "folder_mapping/collections.json": "[...]",
    "settings/theme.json": "{...}",
    "settings/hotkeys.json": "[...]"
  }
}
```

受管文件固定为以上 5 个；导入时只允许这些 key。

---

## 9. Dart → Go 映射表

| Dart 文件/目录 | Go 目标 | 说明 |
|---|---|---|
| `lib/main.dart` | `cmd/itools/main.go` + `internal/app/lifecycle.go` | 单实例、启动参数、托盘、热键注册 |
| `lib/app.dart` | `internal/app/app.go` + `internal/app/windows.go` | 应用装配、窗口创建 |
| `lib/core/data/file_store.dart` | `internal/core/store/store.go` | 原子写、路径注入 |
| `lib/core/system/window_manager_service.dart` | `internal/app/windows.go` | 窗口注册表、实例号、显隐 |
| `lib/core/system/app_tray_service.dart` | `internal/app/tray.go` | 托盘、自启、退出 |
| `lib/core/system/window_reveal_controller.dart` | 可选，P2 | 窗口开启动效 |
| `lib/core/tools/tool_registry.dart` | `internal/features/home/tools.go` | 3 个工具元数据 |
| `lib/core/providers/*` | 各 feature 的 service/controller | Riverpod → 显式 service |
| `lib/core/design_tokens/*` | `internal/ui/theme/tokens.go` | 间距/字号/圆角 |
| `lib/core/themes/*` | `internal/ui/theme/palette.go` | 两套色板 |
| `lib/core/widgets/*` | `internal/ui/widgets/*` | PageHeader、卡片、Toast 等 |
| `lib/features/home/**` | `internal/features/home/**` | 主窗口 |
| `lib/features/settings/**` | `internal/features/settings/**` | 设置四页 |
| `lib/features/hotkey_settings/**` | `internal/features/settings/hotkeys/**` | 热键配置与录制 |
| `lib/features/backup_restore/**` | `internal/features/backup/**` | 备份还原 |
| `lib/features/folder_mapping/**` | `internal/features/folder_mapping/**` | 文件夹映射 |
| `lib/features/json_formatter/**` | `internal/features/json_formatter/**` | JSON 工具 |
| `lib/features/scheduler/**` | `internal/features/scheduler/**` | 定时任务 |
| `assets/tray_icon.ico` | `assets/tray.png` | 托盘必须 PNG |
| `windows/runner/resources/app_icon.ico` | `assets/app.ico` | 打包图标 |

---

## 10. Agent 行为规范

1. **先读后写**：每个任务先读对应 Dart 源码与本文档相关章节；不确定的行为以源码为准。
2. **不扩写需求**：不新增按钮、不改文案、不加设置项；平台差异导致的必要调整需在阶段总结中说明。
3. **先测试后 UI**：纯逻辑（JSON、调度、转义、热键、备份）必须先写表驱动测试。
4. **小步推进**：每个可运行的小步骤后执行 `gofmt -w .`、`go vet ./...`、`go test ./...`。
5. **不猜 API**：MyGo API 以官方文档与 POC 实测为准；不确定时写最小示例验证，不要凭记忆写调用。
6. **不改 Flutter 代码**：`lib/`、`windows/` 只读；所有新代码在 `mygo/`。
7. **保持数据兼容**：任何字段变更必须提供读取兼容与迁移测试。
8. **错误可见**：用户操作失败必须 Toast/错误提示，不允许静默失败。
9. **日志克制**：正常路径不打大量日志；任务输出只进 `scheduler/logs.json`。
10. **阻塞即停**：同一问题连续两次尝试失败，停止并报告，不要暴力试错。
11. **提交纪律**：除非用户明确要求，不执行 `git commit` / `git push`。
12. **阶段总结**：每阶段结束输出：完成项、未完成项、API 差异、行为偏差、下一步。

---

## 11. 风险与回退

| 风险 | 影响 | 应对 |
|---|---|---|
| MyGo 0.x API 变动 | 编译失败/行为变化 | 固定 v0.10.0；升级单独评审；MyGo 调用集中在 `internal/app` 与 `internal/ui`，便于替换 |
| 中文 IME 在自绘 UI 中异常 | 核心可用性问题 | P0 硬门禁；不通过则停止重写 |
| 混合 DPI/多屏定位异常 | 窗口错位 | P0 验证 100/125/150%；必要时按显示器工作区手动修正 |
| 托盘左键行为与现有不一致 | 交互差异 | 用无菜单托盘 + 右键 `Popup` 复刻；若不可行，接受「左键出菜单」并记录 |
| 全局热键字符串映射不全 | 部分键无法注册 | 维护映射表；未识别键显示「不支持」而不是静默回退 |
| 原生 UI 无热重载 | 迭代变慢 | 小步修改；用 `ui.Tester` 覆盖视图逻辑；必要时先做原型页 |
| 进程树杀不干净 | 后台残留进程 | Job Object 优先；`taskkill /T /F` 兜底；P0 验证 |
| 单进程崩溃影响所有窗口 | 稳定性下降 | goroutine recover；view 内不做易 panic 操作；关键路径加边界检查 |
| JSON 键顺序被排序 | 功能回归 | 禁止 `map[string]any` 中转；使用 `tidwall/pretty`；测试固定键顺序 |
| 打包仍需 WebView2/VC++ | 分发门槛未降低 | 使用 Native UI；P0 在干净机器验证 |
| 数据迁移损坏 | 用户数据丢失 | 导入前备份；原子写；兼容测试；不自动删除旧文件 |

回退方案：

- P0 不通过：保留 Flutter，停止重写；把本方案作为技术预研存档。
- P0 通过但某模块 UI 受阻：该模块可临时使用 MyGo WebView 窗口（HTML/TS + IPC），其余保持 Native UI；这是局部回退，不是默认方案。
- 发布前发现阻塞缺陷：优先修复；无法在合理范围内修复时，回退到 Flutter 版本发布，MyGo 版本延期。

---

## 12. 附录

### 12.1 P0 API 验证清单

逐项记录到 `docs/mygo-api-notes.md`：

- [ ] `mygo.App.SetName` / `PathUserData` 是否等于 `%APPDATA%\itools`
- [ ] `RequestSingleInstanceLock` / `OnSecondInstance` 在 Windows 的行为
- [ ] `SetOpenAtLogin` / `OpenAtLogin` / `WasOpenedAtLogin` 在 Windows 的行为
- [ ] `NewWindow` 的 `Hidden`、`OnReadyToShow`、`OnClose`、`OnClosed`、`OnFocus` 实际签名
- [ ] 关闭拦截与 `e.PreventDefault()` 的正确用法
- [ ] 所有窗口隐藏后应用是否继续运行
- [ ] 托盘：无菜单 + `OnClick` + `OnRightClick` + `Menu.Popup` 是否可用
- [ ] `GlobalShortcut.Register` 的修饰键名称、取消注册、重复注册行为
- [ ] `ui` 主题覆盖方式（全局/窗口级）
- [ ] `ui.Split`、`ui.Grid`、`ui.Scroll`、`ui.Toast`、`ui.AlertDialog` 的实际 API
- [ ] `ui.TextInput` / `ui.TextArea` 的 IME、选中、剪贴板、只读
- [ ] `ui/editor` 的只读、语言设置、行号、查找、性能
- [ ] `Dialog.Open` 选择目录、`Dialog.Save` 的过滤器
- [ ] `Shell.OpenPath` 打开文件夹
- [ ] `Window.Update` 的线程语义
- [ ] `mygo build` 的图标、安装包、便携版配置

### 12.2 参考文档

- 总览：https://mygo.egoist.dev/docs
- 窗口：https://mygo.egoist.dev/docs/windows
- 菜单与托盘：https://mygo.egoist.dev/docs/menus
- 桌面 API（含全局快捷键）：https://mygo.egoist.dev/docs/native
- 应用生命周期/单实例/开机自启：https://mygo.egoist.dev/docs/app
- Native UI 总览：https://mygo.egoist.dev/docs/ui
- 文本输入（IME）：https://mygo.egoist.dev/docs/ui/text-input
- 代码编辑器：https://mygo.egoist.dev/docs/ui/code-editor
- 布局：https://mygo.egoist.dev/docs/ui/layout
- 主题与样式：https://mygo.egoist.dev/docs/ui/styling
- 输入与快捷键：https://mygo.egoist.dev/docs/ui/input
- 打包分发：https://mygo.egoist.dev/docs/distribution
- 架构说明：https://mygo.egoist.dev/docs/architecture
- 源码：https://github.com/egoist/mygo
- Go API：https://pkg.go.dev/github.com/egoist/mygo

### 12.3 现有代码索引（行为基准）

- 主入口/多窗口：`lib/main.dart`
- 应用根/路由：`lib/app.dart`、`lib/core/router/**`
- 窗口管理：`lib/core/system/window_manager_service.dart`
- 托盘/自启：`lib/core/system/app_tray_service.dart`
- 文件存储：`lib/core/data/file_store.dart`
- 工具元数据：`lib/core/tools/tool_registry.dart`
- 设计 token：`lib/core/design_tokens/**`
- 主题：`lib/core/themes/**`、`lib/features/settings/data/theme_service.dart`
- 主窗口：`lib/features/home/**`
- 设置：`lib/features/settings/**`
- 热键：`lib/features/hotkey_settings/**`
- 备份：`lib/features/backup_restore/**`
- 文件夹映射：`lib/features/folder_mapping/**`
- JSON 格式化：`lib/features/json_formatter/**`、`docs/features/json-formatter.md`
- 定时任务：`lib/features/scheduler/**`

---

## 13. 完成定义（DoD）

- P0–P6 全部阶段门禁通过。
- 功能对齐清单全部勾选（主窗口、设置、三工具、热键、托盘、自启、备份）。
- 5 个数据文件读写兼容，往返测试通过。
- 手动回归矩阵通过（Win10/Win11、DPI、IME、多窗口、长时间运行）。
- `go vet ./...`、`go test ./...`、`go build ./...`、`mygo build` 全部通过。
- 干净机器安装运行成功，无 VC++/WebView2 依赖。
- 启动时间、常驻内存、安装包体积优于现有 Flutter 版本，并记录对比数据。
- 阶段总结与 API 差异记录完整，无未解释的行为偏差。
