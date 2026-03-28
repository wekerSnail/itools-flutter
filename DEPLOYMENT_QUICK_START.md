# 部署快速参考

## 问题

✗ 只复制 `itools.exe` 到其他电脑报错
✗ 缺少 DLL 或资源文件导致闪退

## 解决方案

### ✅ 正确的部署方式

**复制整个 Release 文件夹**，包含所有文件和子文件夹：

```
Release/
├── itools.exe ...................... 主程序
├── flutter_windows.dll ............. Flutter 运行时库（17.7 MB）
├── file_selector_windows_plugin.dll  文件选择插件
├── screen_retriever_windows_plugin.dll 屏幕获取插件
├── tray_manager_plugin.dll ......... 托盘插件
├── window_manager_plugin.dll ....... 窗口管理插件
└── data/ ........................... 重要！资源文件夹
    ├── flutter_assets/
    ├── icudtl.dat
    └── fonts/
```

### 部署步骤

#### 方法1：直接复制文件夹（推荐）

```powershell
# 复制整个 Release 文件夹到目标位置
xcopy "build\windows\x64\runner\Release\*" "D:\itools\" /E /I
```

#### 方法2：使用 ZIP 包

```powershell
# 打包为 ZIP
Compress-Archive -Path build\windows\x64\runner\Release `
  -DestinationPath itools-app.zip

# 在目标电脑上：解压 ZIP，然后双击 itools.exe 运行
```

### 前置要求

| 前置要求               | 状态    | 下载链接                                                 |
| ---------------------- | ------- | -------------------------------------------------------- |
| **Visual C++ Runtime** | ✅ 必需 | [下载](https://support.microsoft.com/en-us/help/2977003) |
| **Windows 10/11**      | ✅ 必需 | -                                                        |
| **Node.js**            | ❌ 可选 | [仅 JS 脚本任务需要](https://nodejs.org/)                |

### 常见错误及解决

| 错误                | 原因             | 解决                    |
| ------------------- | ---------------- | ----------------------- |
| 无法找到 DLL        | 只复制了 exe     | 复制整个 Release 文件夹 |
| VCRUNTIME 错误      | 缺少 Visual C++  | 安装 Redistributable    |
| 界面混乱/字体不显示 | 缺少 data 文件夹 | 确保 data 文件夹完整    |
| "找不到" 错误       | 文件权限问题     | 以管理员身份运行        |

### 包大小

- **总大小**：32.96 MB
- **主要占用**：flutter_windows.dll (17.7 MB)
- **压缩后**：~8-10 MB（ZIP）

---

## 诊断步骤

如果还是报错，按这个顺序检查：

1. **验证文件完整性**

   ```cmd
   dir /B D:\itools\
   :: 应该看到至少 6 个 .dll 和 1 个 data 文件夹
   ```

2. **检查 Visual C++ Runtime**
   - 设置 → 应用 → 应用和功能
   - 搜索 "Visual C++"
   - 如无结果，下载安装

3. **命令行测试**

   ```cmd
   CD D:\itools
   itools.exe
   :: 观察是否有错误输出
   ```

4. **查看详细错误**（仅 Windows）
   - 事件查看器 → Windows 日志 → 应用程序
   - 查找与 itools 相关的红色错误

---

## 获取更多帮助

📖 完整文档：[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
