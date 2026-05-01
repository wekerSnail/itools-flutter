# 开机自启动故障排查指南

## 问题描述

应用配置了开机自启动，但Windows重启后应用没有自动启动。

## 可能原因

### 1. Windows启动管理器禁用了应用

**检查方法：**
1. 打开 Windows 设置 (Win + I)
2. 进入 应用 > 启动
3. 查找"Windows 工具集"
4. 确保状态为"打开"

### 2. 注册表配置不正确

**检查方法：**
```powershell
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
  Select-Object -Property "*工具集*"
```

**预期输出：**
```
Windows 工具集 : C:\path\to\launch-elevated.vbs
```

### 3. 应用路径变更

如果应用被移动或重命名，注册表中的路径将失效。

**解决方法：**
1. 重新运行应用
2. 在托盘菜单中禁用再启用开机自启

### 4. UAC权限问题

应用需要管理员权限才能正常运行，但Windows注册表Run键无法自动提升权限。

**解决方法：**
应用使用VBS脚本代理启动以自动请求UAC提升。确认 `launch-elevated.vbs` 文件存在于应用目录中。

### 5. 防病毒软件拦截

某些防病毒软件可能阻止应用自启动。

**解决方法：**
将应用路径添加到防病毒软件白名单。

## 手动修复步骤

### 方法1：通过应用设置（推荐）

1. 启动应用
2. 右键点击系统托盘图标
3. 选择"开机自启"（如果已启用，先禁用再启用）

### 方法2：通过PowerShell

```powershell
# 查看当前配置
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
  Select-Object -Property "*工具集*"

# 删除旧配置
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Windows 工具集" -Force

# 重新启动应用，会自动重新配置
```

### 方法3：通过任务计划程序（备选方案）

1. 打开"任务计划程序"（taskschd.msc）
2. 创建基本任务
3. 设置触发器为"计算机启动时"
4. 设置操作为启动程序
5. 选择itools.exe
6. 勾选"使用最高权限运行"

## 诊断脚本

运行诊断脚本检查配置：

```powershell
.\diagnose-autostart.ps1
```

运行验证脚本确认修复：

```powershell
.\verify-autostart.ps1
```

## 常见问题

### Q: 重启后仍未自动启动？

A:
1. 检查 设置 > 应用 > 启动 中是否禁用了应用
2. 运行 `verify-autostart.ps1` 检查配置
3. 手动运行 `launch-elevated.vbs` 测试是否有其他错误

### Q: 应用无法找到文件/资源？

A:
1. 确保 `itools.exe` 和 `data` 文件夹在同一目录
2. 检查文件是否被移动或删除
3. 重新部署应用

### Q: 防病毒软件阻止？

A:
1. 将应用路径添加到防病毒软件白名单
2. 或临时禁用防病毒软件测试

### Q: 需要每次手动确认UAC？

A: 这是正常的 Windows 安全行为。如果希望完全不显示 UAC，可以在 Windows 设置中调整 UAC 级别，但不推荐。

### Q: 应用更新后需要重新配置吗？

A: 通常不需要，但如果应用路径发生变化，可能需要重新配置。

## 相关文档

- [开机自启最终解决方案](AUTOSTART_FINAL_SOLUTION.md)
- [开机自启修复指南](AUTOSTART_FIX_GUIDE.md)
- [系统托盘实现说明](tray/README.md)
