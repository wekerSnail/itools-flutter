# Flutter 镜像源配置指南

## 使用方案

### 方案 1：PowerShell 脚本（推荐）

```powershell
# 允许执行本地脚本（如果没执行过的话）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行脚本
.\setup-mirror.ps1
```

### 方案 2：批处理脚本

双击运行：

```
setup-mirror.bat
```

### 方案 3：手动设置环境变量（PowerShell）

```powershell
$env:PUB_HOSTED_URL = "https://pub.aliyuncs.com"
$env:FLUTTER_STORAGE_BASE_URL = "https://mirrors.aliyun.com/flutter"
flutter pub get
```

### 方案 4：手动设置环境变量（CMD）

```cmd
set PUB_HOSTED_URL=https://pub.aliyuncs.com
set FLUTTER_STORAGE_BASE_URL=https://mirrors.aliyun.com/flutter
flutter pub get
```

## 可用镜像源

### 1. **阿里云**（推荐）

```
PUB_HOSTED_URL=https://pub.aliyuncs.com
FLUTTER_STORAGE_BASE_URL=https://mirrors.aliyun.com/flutter
```

### 2. **清华大学**（可选）

```
PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
```

### 3. **官方源**（不使用镜像）

```
# 不设置上述环境变量，使用默认官方源
```

## 永久配置（Windows）

### 设置系统环境变量：

1. 按 `Win + X`，选择 "系统"
2. 点击 "高级系统设置" → "环境变量"
3. 点击 "新建"，添加：
   - 变量名：`PUB_HOSTED_URL`
   - 变量值：`https://pub.aliyuncs.com`
4. 再新建一个：
   - 变量名：`FLUTTER_STORAGE_BASE_URL`
   - 变量值：`https://mirrors.aliyun.com/flutter`
5. 点击确定，重启 IDE 或终端

## 清除缓存后重新下载

```powershell
flutter pub cache clean
.\setup-mirror.ps1
```

## 验证配置

```powershell
flutter pub get -v
```

使用 `-v` 参数查看详细输出，确认是否使用了正确的镜像源。

## 遇到问题

- 如果脚本不执行，查看 PowerShell 执行策略：

  ```powershell
  Get-ExecutionPolicy
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

- 如果仍然很慢，尝试切换镜像源或清除缓存

- 检查网络连接是否正常
