# Windows 工具集（Flutter）

一个可扩展的 Flutter Windows 端工具应用，当前已内置：

- 定时任务（两种类型）
  - JS 脚本任务（通过 Node.js 执行）
  - 终端命令任务（通过 `cmd` 执行）
  - 变量独立管理（支持 string / number / boolean / object）
  - 周期支持 秒 / 分钟 / 小时 / 天 / 星期 / 月
- 文件夹映射管理（增删改、双击打开目录）
- 系统托盘（打开主界面、开机自启、退出）

---

## 1. 环境要求

### 必需

- Flutter SDK（建议 stable）
- Windows 开发环境（Visual Studio C++ 工具链）

### 可选（仅 JS 脚本任务需要）

- Node.js（加入 PATH）

> 如果未安装 Node.js，JS 脚本任务会在日志中提示“未检测到 Node.js”。

---

## 2. 快速启动

在项目根目录执行：

1. 拉取依赖
   - `flutter pub get`
2. 启动 Windows 应用
   - `flutter run -d windows`

应用启动后首页为工具网格布局（每行 4 个图标），点击进入二级工具页面。

---

## 2.1 构建与部署

### 构建 Release 版本

```bash
flutter build windows --release
```

构建后应用文件位于：`build/windows/x64/runner/Release/`

### 部署到其他电脑

⚠️ **重要**：不要只复制 `itools.exe`，必须复制 **整个 Release 文件夹**（包括 DLL 和 data 文件夹）

**部署方式**：

1. **方式一**：复制整个文件夹

   ```bash
   # 从 build/windows/x64/runner/Release 复制所有文件到 dist 文件夹
   xcopy "build\windows\x64\runner\Release\*" dist\itools\ /E /I
   ```

2. **方式二**：创建可执行的 ZIP 包
   ```powershell
   # 打包为 ZIP
   Compress-Archive -Path build\windows\x64\runner\Release -DestinationPath itools-release.zip
   # 在目标电脑上解压后双击 itools.exe 运行
   ```

### 部署包内容

| 文件/文件夹           | 大小          | 说明                      |
| --------------------- | ------------- | ------------------------- |
| `itools.exe`          | 91 KB         | 主程序                    |
| `flutter_windows.dll` | 17.7 MB       | Flutter 运行时            |
| `*_plugin.dll`        | ~0.5 MB       | 各插件库（5个）           |
| `data/`               | ~14.6 MB      | 字体、资源、Dart 运行时等 |
| **总计**              | **~32.96 MB** | 完整可部署包              |

### 目标电脑要求

- **OS**：Windows 10/11 64-bit
- **必需**：Visual C++ Redistributable 2022/2023
  - 🔗 下载：[Microsoft Visual C++ Redistributable](https://support.microsoft.com/en-us/help/2977003)
  - 或在微软官网搜索 "Visual C++ Redistributable 2023"
- **可选**：Node.js（仅当使用 JS 脚本任务时需要）
  - 🔗 下载：[nodejs.org](https://nodejs.org/)

### 故障排查

遇到部署问题？请参考 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 文档，包含常见问题和解决方案。

---

## 2.2 开发环境配置

### 3.0 页面结构（UI）

- 首页：仅展示任务列表
- 顶部：`添加任务` 按钮（打开新增页面）
- 编辑：点击任务行 `编辑` 图标，打开独立编辑页面
- 日志：点击右上角日志按钮，打开独立日志页面

### 3.1 任务类型

在“定时任务”页面可选择：

1. **终端命令任务**
   - 配置命令，如：`echo hello {{name}}`
   - 到达触发时间后通过 `cmd /c` 执行

2. **JS 脚本任务**
   - 配置 JS 脚本内容
   - 运行时通过 Node.js 执行临时脚本文件
   - 可在脚本中使用 `vars` 对象（来自变量配置）

### 3.2 变量配置

- 变量可单独新增、编辑、删除
- 支持类型：`string`、`number`、`boolean`、`object`

**变量使用方法（差异很重要）：**

1. **终端命令任务**：使用 `{{变量名}}` 进行文本替换

   ```bash
   echo hello {{name}}
   dir {{folderPath}}
   ```

2. **JS 脚本任务**：通过注入的 `vars` 对象访问，**不使用 {{}} 替换**
   ```javascript
   console.log("Hello " + vars.name);
   const count = vars.count + 1;
   const config = vars.settings; // 如果是 object 类型
   console.log(config.key1);
   ```

⚠️ **重要**：JS 脚本中请直接使用 `vars.变量名`，不要使用 `{{变量名}}` —— 那只用于命令行任务。

### 3.3 调度规则

- 每个任务包含：开始时间 + 周期间隔 + 周期单位
- 周期单位支持：秒 / 分钟 / 小时 / 天 / 星期 / 月
- 任务可启用/禁用
- 支持编辑、删除
- 执行日志在独立页面展示，默认保留 5 天（自动清理）

### 3.4 编辑体验

- **JS 脚本编辑器** 支持语法高亮，便于编写较长脚本与调试输出
- **拖动调整编辑框大小**：鼠标 hover 编辑框下方的拖动条（灰色分割线）→ 出现↕️ 光标 → 上下拖动即可调整高度（最小 100px，最大 800px）
- **内置滚动条**：即使编辑框不够高，粘贴长脚本也会自动显示滚动条，不会导致页面溢出
- **空编辑框也可拖动**：即使没有任何代码，也能拖动调整高度为下面的内容预留空间
- **定时配置布局**：采用分行显示，避免屏幕宽度不足时的布局混乱；快捷按钮（秒级、5分钟、按天）帮助快速配置

---

## 4. 文件夹映射功能说明

- 该功能已升级为“文件夹快捷方式管理”（不再需要源目录）
- 数据分为两级：
  - 集合（用于分类管理）
  - 快捷方式（集合下的目录入口，仅保存目标目录）
- 支持新增、编辑、删除集合
- 支持在集合下新增、编辑、删除快捷方式
- 单击或双击快捷方式可直接打开目标目录

---

## 5. 项目结构

```text
lib/
  app.dart
  main.dart
  core/
	 router/
	 tools/
  features/
	 home/
	 scheduler/
		domain/
		data/
		application/
		presentation/
	 folder_mapping/
		domain/
		data/
		application/
		presentation/
```

设计目标：高内聚、低耦合，便于后续新增更多工具模块。

---

## 6. 代码质量检查

建议每次改动后执行：

1. 静态检查
   - `flutter analyze`
2. 测试
   - `flutter test`

---

## 7. Windows 打包发布

### 7.1 生成可分发构建

- `flutter build windows --release`

产物目录：

- `build/windows/x64/runner/Release/`

可执行文件默认在该目录中（含运行所需依赖文件）。

### 7.2 发布建议

你可以选择：

1. 直接分发 `Release` 整个目录（最简单）
2. 使用安装器工具（如 Inno Setup / NSIS）制作安装包

### 7.3 常见问题

- **无法构建 Windows**：检查是否安装 Visual Studio C++ 桌面开发组件
- **JS 任务无法执行**：确认 Node.js 已安装并可在终端执行 `node -v`

---

## 8. 托盘与应用生命周期

- 点击主窗口右上角关闭按钮时，应用不会退出，会最小化到系统托盘
- 托盘菜单支持：
  - 打开主界面
  - 开机自启开关
  - 退出应用

---

## 9. 后续扩展建议

- 增加任务执行历史落库（SQLite）
- 任务失败重试与告警
- JS 引擎内嵌（QuickJS）替代外部 Node 依赖
- 工具插件化加载机制（动态注册）
