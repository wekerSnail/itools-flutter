# Windows 11 开机自启动排查和修复指南

## 问题描述

在Win11上设置了开机自启动，但重启电脑后应用未能自动启动。

## 🔍 排查流程

### 第一步：运行诊断脚本

1. 进入项目文件夹：`e:\repo\itools-flutter`
2. 右键 `diagnose-autostart.ps1` 文件
3. 选择 **"用 PowerShell 运行(管理员)"**

脚本会自动检查以下内容：

- ✅ 注册表中是否存在自启动项
- ✅ Windows 11 启动管理器中的设置
- ✅ 应用可执行文件是否存在
- ✅ 文件权限是否正确
- ✅ 系统日志中的错误信息

---

## 🛠️ 常见问题和解决方案

### 问题 1: 注册表中找不到自启动项

**症状：** 诊断脚本显示"未找到应用的自启动注册表项"

**解决办法：**

**方案 A: 自动修复（推荐）**

1. 右键 `fix-autostart.ps1`
2. 选择 **"用 PowerShell 运行(管理员)"**
3. 脚本会自动检查、更新注册表
4. 按 Enter 确认完成

**方案 B: 手动修复**

1. 右键 Windows 开始菜单，选择 **PowerShell (管理员)**
2. 运行以下命令：

```powershell
# 设置自启动（将路径替换为实际的应用路径）
$appPath = "E:\repo\itools-flutter\build\windows\x64\Release\itools.exe"
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $regPath -Name "Windows 工具集" -Value "`"$appPath`"" -Force

# 验证
Get-ItemProperty -Path $regPath -Name "Windows 工具集"
```

**方案 C: 通过应用设置**

1. 启动应用，右键托盘图标
2. 点击"开机自启" 按钮
3. 这会调用 `launch_at_startup` 插件设置注册表

---

### 问题 2: Windows 11 启动应用管理器中被禁用

**症状：** 诊断脚本显示"应用在启动管理器中被禁用"

**解决办法：**

1. 打开 **设置** 应用 (Win + I)
2. 导航到 **应用** → **启动**
3. 在列表中找到 **"Windows 工具集"**
4. 将状态从"关闭"改为**"打开"**

![启动应用管理器位置](../../docs/autostart-settings.png)

---

### 问题 3: 应用可执行文件不存在

**症状：** 诊断脚本显示"未找到任何应用可执行文件"

**解决办法：**

**编译项目（推荐）**

```powershell
cd e:\repo\itools-flutter
flutter clean
flutter pub get
flutter build windows --release
```

编译完成后，可执行文件位置为：

```
e:\repo\itools-flutter\build\windows\x64\Release\itools.exe
```

然后再运行 `fix-autostart.ps1` 脚本。

---

### 问题 4: 权限不足

**症状：** 修复脚本提示"需要管理员权限"

**解决办法：**

1. 右键 `.ps1` 文件
2. **不要** 选择"编辑"
3. 选择 **"用 PowerShell 运行(管理员)"**
4. 如果出现安全警告，点击"是"

---

## 🧪 手动验证

修复后，运行以下命令验证设置是否成功：

```powershell
# 查看注册表项
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
  Select-Object -Property "*工具集*", "*itools*"

# 预期输出示例：
# Windows 工具集 : "E:\repo\itools-flutter\build\windows\x64\Release\itools.exe"
```

---

## 🔧 代码级改进

已更新 `lib/core/system/app_tray_service.dart` 中的 `_setupLaunchAtStartup()` 方法：

**改进内容：**

- ✅ 增强了日志输出，显示实际使用的路径
- ✅ 使用绝对路径代替相对路径
- ✅ 添加了注册表验证日志
- ✅ 提供了诊断信息用于故障排查

**查看日志：**
运行应用后，检查 VS Code 的调试输出或应用的日志文件，搜索 `[Tray]` 关键字。

---

## 📋 重启测试

完成修复后：

1. **注销并重新登录**（或重启电脑）
2. 检查应用是否自动启动（通常在托盘显示）
3. 如果应用启动但窗口不可见，检查任务栏或右下角托盘区域

---

## ⚠️ 其他可能的原因

| 原因                | 检查方法              | 解决办法                                                               |
| ------------------- | --------------------- | ---------------------------------------------------------------------- |
| 应用启动太慢        | 查看事件日志          | 优化应用启动性能                                                       |
| 防病毒软件拦截      | 检查防病毒日志        | 将应用添加到白名单                                                     |
| 用户账户控制(UAC)   | 查看通知历史          | 降低UAC级别或使用管理员账户                                            |
| 注册表权限问题      | `icacls` 命令检查     | 重新获取权限                                                           |
| PowerShell 执行策略 | `Get-ExecutionPolicy` | 临时设置: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` |

---

## 🐛 调试技巧

**启用详细日志：**

在 `app_tray_service.dart` 中增加调试打印：

```dart
debugPrint('[Tray] Launch at startup setup...');
```

运行应用时使用：

```bash
flutter run -v
```

查看控制台输出中 `[Tray]` 相关的日志。

---

## 📞 仍未解决？

如果上述方案都不起作用，请收集以下信息：

1. 运行 `diagnose-autostart.ps1` 的完整输出
2. 应用启动时的日志（`flutter run -v` 的输出）
3. Windows 事件查看器中的错误日志
4. 您的 Windows 版本（`winver`）

---

## 相关命令速查表

```powershell
# 查看所有自启动项
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# 添加自启动项
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "应用名称" -Value "C:\路径\app.exe" -Force

# 删除自启动项
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "应用名称" -Force

# 检查执行策略
Get-ExecutionPolicy

# 临时设置执行策略为 Bypass
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 查看最近的应用事件
Get-EventLog -LogName Application -Newest 10 | Format-List
```

---

**最后更新：** 2024年
**适用系统：** Windows 11
**适用应用版本：** itools (flutter)
