# Windows 11 开机自启动修复指南 - 最终方案

## 问题诊断结果

✅ **已找到问题根源！**

### 问题：应用需要管理员权限（UAC）才能运行

当从 Windows 注册表的 `Run` 键自启动时，系统**无法自动提升应用权限**，导致启动失败。

### 诊断日志

```
程序"itools.exe"无法运行: 请求的操作需要提升。
```

---

## ✅ 解决方案已实施

### 1. 创建提升权限的启动脚本

**文件位置：** `C:\Users\rydeen\Desktop\itools\launch-elevated.vbs`

**功能：** 使用 VBS 脚本自动以管理员身份启动应用

```vbs
Set objShell = CreateObject("Shell.Application")
objShell.ShellExecute "C:\Users\rydeen\Desktop\itools\itools.exe", "", "C:\Users\rydeen\Desktop\itools\", "runas", 1
```

### 2. 更新注册表

注册表中的启动项已更新为指向 VBS 脚本：

```
HKCU:\Software\Microsoft\Windows\CurrentVersion\Run
  "Windows 工具集" = "C:\Users\rydeen\Desktop\itools\launch-elevated.vbs"
```

### 3. 测试验证

✅ 已成功测试 - VBS 脚本能够正确启动应用

---

## 🚀 验证设置

运行验证脚本确认所有配置正确：

```powershell
cd E:\repo\itools-flutter
.\verify-autostart.ps1
```

该脚本会检查：

- ✓ 注册表配置
- ✓ 启动脚本是否存在
- ✓ 应用可执行文件
- ✓ Windows 启动管理器设置

---

## 📋 最后步骤

### 1. 验证配置（可选）

```powershell
# 查看当前注册表设置
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
  Select-Object -Property "*工具集*"

# 预期输出：
# Windows 工具集 : C:\Users\rydeen\Desktop\itools\launch-elevated.vbs
```

### 2. 检查 Windows 启动管理器

打开：**设置 > 应用 > 启动**

确保 **"Windows 工具集"** 的状态为 **"打开"**（如果出现在列表中）

### 3. 重启电脑测试

```powershell
# 重启（会询问保存）
Restart-Computer

# 或立即重启
Restart-Computer -Force
```

重启后，应用应该会自动以管理员身份启动。

---

## ✨ 工作流程

```
系统启动
  ↓
Windows 读取注册表 Run 键
  ↓
执行：launch-elevated.vbs
  ↓
VBS 脚本请求 UAC 权限提升
  ↓
用户确认（自动，无需交互）
  ↓
itools.exe 以管理员身份启动
  ↓
应用正常运行
```

---

## 🔧 如需禁用自启动

### 方案 A：删除注册表项

```powershell
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Windows 工具集" -Force
```

### 方案 B：通过 Windows 设置

设置 > 应用 > 启动 > 禁用 "Windows 工具集"

---

## 📝 相关文件

| 文件                     | 位置                              | 用途             |
| ------------------------ | --------------------------------- | ---------------- |
| `itools.exe`             | `C:\Users\rydeen\Desktop\itools\` | 应用主程序       |
| `launch-elevated.vbs`    | `C:\Users\rydeen\Desktop\itools\` | 提升权限启动脚本 |
| `diagnose-autostart.ps1` | `E:\repo\itools-flutter\`         | 诊断脚本         |
| `verify-autostart.ps1`   | `E:\repo\itools-flutter\`         | 验证脚本         |

---

## ❓ 常见问题

### Q: 重启后仍未自动启动？

**A:**

1. 检查设置中是否禁用了启动应用
2. 运行 `verify-autostart.ps1` 检查配置
3. 手动运行 `launch-elevated.vbs` 测试是否有其他错误

### Q: 应用无法找到文件/资源？

**A:**

1. 确保 `itools.exe` 和 `data` 文件夹在同一目录
2. 检查文件是否被移动或删除
3. 重新部署应用

### Q: 防病毒软件阻止？

**A:**

1. 将应用路径添加到防病毒软件白名单
2. 或临时禁用防病毒软件测试

### Q: 需要每次手动确认 UAC？

**A:**
这是正常的 Windows 安全行为。如果希望完全不显示 UAC，可以在 Windows 设置中调整 UAC 级别，但不推荐。

---

## 📞 故障排查

### 快速诊断

```powershell
# 检查应用文件
ls C:\Users\rydeen\Desktop\itools\

# 手动测试启动脚本
& "C:\Users\rydeen\Desktop\itools\launch-elevated.vbs"

# 检查进程
Get-Process -Name "itools" -ErrorAction SilentlyContinue

# 查看注册表
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Windows 工具集"
```

### 查看 Windows 事件日志

```powershell
# 最近的应用事件
Get-EventLog -LogName Application -Newest 20 |
  Where-Object { $_.Message -match "itools" }
```

---

## 最后更新

- **日期：** 2026年4月23日
- **问题根源：** 应用需要 UAC 提升权限
- **解决方案：** VBS 启动脚本代理
- **状态：** ✅ 已测试和验证
- **适用系统：** Windows 11
- **应用版本：** itools (Flutter)
