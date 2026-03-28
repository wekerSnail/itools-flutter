# 部署常见问题排查指南

## 问题1：运行 exe 时出现"无法找到模块"或"缺少 DLL"错误

### 症状

- 双击 `itools.exe` 无反应或立即关闭
- 命令行运行显示类似错误：
  - `缺少 flutter_windows.dll`
  - `缺少 file_selector_windows_plugin.dll`
  - `缺少 screen_retriever_windows_plugin.dll`

### 解决方案

✅ **确保复制了整个文件夹**，包括所有 DLL 和 `data/` 文件夹

目录结构应该是这样的：

```
itools/
├── itools.exe (91 KB)
├── flutter_windows.dll (18 MB)
├── file_selector_windows_plugin.dll
├── screen_retriever_windows_plugin.dll
├── tray_manager_plugin.dll
├── window_manager_plugin.dll
└── data/
    ├── flutter_assets/
    ├── icudtl.dat
    └── ...
```

---

## 问题2：Visual C++ Runtime 缺失

### 症状

- 错误信息包含：`api-ms-win-crt-...` 或 `VCRUNTIME`
- 运行后立即崩溃无日志

### 解决方案

1. **下载运行时**
   - Visual C++ Redistributable 2022/2023（建议最新版本）
   - 链接：https://support.microsoft.com/en-us/help/2977003
   - 或搜索 `Microsoft Visual C++ Redistributable` 官方网站

2. **安装步骤**
   - 下载后双击安装文件
   - 选择"安装"或"Repair"
   - 完成后重启电脑
   - 再次运行 `itools.exe`

3. **判断是否已安装**
   - Windows 设置 → 应用 → 应用和功能
   - 搜索 `Visual C++`
   - 或在命令行运行：
     ```cmd
     wmic product list | find "Visual C++"
     ```

---

## 问题3：资源文件缺失（字体、图片无显示）

### 症状

- 应用能运行但界面混乱，字体不显示或图片无法加载
- 日志中可能出现资源相关错误

### 解决方案

1. 检查 `data/` 文件夹是否完整存在
2. 确保文件夹内包含：
   - `flutter_assets/` - 应用资源
   - `icudtl.dat` - 国际化数据
   - 各种 `.ttf` / `.otf` 字体文件

3. 如果缺失，重新复制整个 `Release` 文件夹

---

## 问题4：Node.js 相关错误

### 症状

- 运行 JS 脚本任务时出错
- 日志显示："未检测到 Node.js" 或 "无法执行脚本"

### 解决方案

**如果不需要 JS 脚本功能**：

- 只使用"终端命令任务"，这不需要 Node.js

**如果需要 JS 脚本功能**：

1. 从官方网站安装 Node.js：https://nodejs.org/
2. 安装时勾选 "Add to PATH"
3. 验证安装：在命令行运行
   ```cmd
   node --version
   npm --version
   ```
4. 重启应用

---

## 问题5：权限问题（开机自启失败）

### 症状

- 勾选"开机自启"但下次启动后没有运行
- UAC 权限提示

### 解决方案

1. **以管理员身份运行应用**
   - 右键 `itools.exe` → 属性
   - 兼容性 → 勾选"以管理员身份运行此程序"
   - 应用 → 确定
   - 重启应用并重新设置开机自启

2. **检查启动项**
   - Windows 任务管理器 → 启动选项卡
   - 查找 `itools` 是否在列表中
   - 如果在，状态应为"启用"

---

## 问题6：定时任务不执行

### 症状

- 任务已启用且到达执行时间但没有运行
- 日志区域无任何输出

### 检查清单

1. ✅ 任务是否处于"启用"状态？
2. ✅ 开始时间是否已过？
3. ✅ 时区是否正确？
4. ✅ 应用是否在运行中（不在系统托盘中最小化）？
5. ✅ 对于 JS 脚本：Node.js 是否已安装？
6. ✅ 检查日志页面是否有错误提示

### 解决方案

- 打开日志页面查看详细错误信息
- 如果无日志，尝试：
  1. 修改任务（任意改动）
  2. 保存
  3. 查看日志是否更新

---

## 问题7：应用启动缓慢

### 原因

- 首次启动时初始化资源（正常现象）
- 任务数量过多导致启动时加载变慢

### 解决方案

- 正常启动时间为 2-5 秒
- 后续启动会快速提升
- 考虑清理过期日志数据

---

## 快速诊断步骤

如果应用无法正常运行，按以下顺序检查：

1. **检查文件完整性**

   ```cmd
   dir d:\itools\
   :: 应该看到 .exe、多个 .dll、data 文件夹
   ```

2. **检查 Visual C++ Runtime**
   - 打开 Windows 设置 → 应用 → 应用和功能
   - 搜索"Visual C++"
   - 如无结果，安装 Redistributable

3. **尝试命令行运行获取错误信息**

   ```cmd
   D:\itools\itools.exe
   :: 注意是否有错误输出
   ```

4. **查看 Windows 事件查看器**
   - Windows 日志 → 应用程序
   - 查找与 itools 相关的错误事件

5. **在原开发机上验证构建**
   ```bash
   flutter build windows --release
   cd build/windows/x64/runner/Release
   itools.exe  # 确保在原机能运行
   ```

---

## 获取更多帮助

- 检查应用日志页面的详细错误信息
- 记录完整的错误信息和步骤截图
- 检查 Windows 事件查看器的应用程序日志
