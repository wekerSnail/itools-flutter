# JSON格式化功能 + 开机自启修复 实现计划

> **状态：已完成（2026-05-07）**

**Goal:**

1. ✅ 为itools工具添加JSON格式化功能模块
2. ✅ 修复开机自启动bug
3. ✅ 维护项目文档

**Architecture:**

- JSON格式化功能采用 Clean Architecture 架构，与现有功能模块保持一致
- 使用shadcn_ui组件库保持UI风格统一
- 开机自启问题通过 VBS 脚本代理启动解决 UAC 权限问题

**Tech Stack:** Flutter, shadcn_ui, launch_at_startup, re_editor, re_highlight

---

## 任务概览

| 任务   | 描述                   | 优先级 | 状态      |
| ------ | ---------------------- | ------ | --------- |
| Task 1 | 创建JSON格式化功能模块 | 高     | ✅ 已完成 |
| Task 2 | 实现JSON格式化核心逻辑 | 高     | ✅ 已完成 |
| Task 3 | 实现JSON格式化UI界面   | 高     | ✅ 已完成 |
| Task 4 | 注册路由和工具         | 高     | ✅ 已完成 |
| Task 5 | 排查修复开机自启bug    | 高     | ✅ 已完成 |
| Task 6 | 更新项目文档           | 中     | ✅ 已完成 |

---

## Task 1: 创建JSON格式化功能模块目录结构

**Files:**

- Create: `lib/features/json_formatter/presentation/json_formatter_page.dart`
- Create: `lib/features/json_formatter/domain/json_formatter_service.dart`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p lib/features/json_formatter/presentation
mkdir -p lib/features/json_formatter/domain
```

- [ ] **Step 2: 创建JSON格式化服务**

创建 `lib/features/json_formatter/domain/json_formatter_service.dart`:

```dart
import 'dart:convert';

class JsonFormatterService {
  /// 格式化JSON字符串
  String format(String input, {int indent = 2}) {
    try {
      final dynamic parsed = json.decode(input);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (e) {
      throw FormatException('无效的JSON格式: $e');
    }
  }

  /// 压缩JSON字符串
  String minify(String input) {
    try {
      final dynamic parsed = json.decode(input);
      return json.encode(parsed);
    } catch (e) {
      throw FormatException('无效的JSON格式: $e');
    }
  }

  /// 验证JSON是否有效
  bool isValid(String input) {
    try {
      json.decode(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 转义JSON字符串
  String escape(String input) {
    return json.encode(input);
  }

  /// 反转义JSON字符串
  String unescape(String input) {
    try {
      final String unescaped = json.decode(input);
      return unescaped;
    } catch (e) {
      throw FormatException('无效的转义字符串: $e');
    }
  }

  /// JSON转Dart Map
  String toDartMap(String input) {
    try {
      final dynamic parsed = json.decode(input);
      return _convertToDartMap(parsed, 0);
    } catch (e) {
      throw FormatException('无效的JSON格式: $e');
    }
  }

  String _convertToDartMap(dynamic value, int depth) {
    final indent = '  ' * depth;
    final nextIndent = '  ' * (depth + 1);

    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries.map((e) {
        return '$nextIndent\'${e.key}\': ${_convertToDartMap(e.value, depth + 1)},';
      }).join('\n');
      return '{\n$entries\n$indent}';
    } else if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((e) {
        return '$nextIndent${_convertToDartMap(e, depth + 1)},';
      }).join('\n');
      return '[\n$items\n$indent]';
    } else if (value is String) {
      return '\'$value\'';
    } else {
      return value.toString();
    }
  }

  /// JSON转TypeScript接口
  String toTypeScriptInterface(String input, {String interfaceName = 'RootObject'}) {
    try {
      final dynamic parsed = json.decode(input);
      final buffer = StringBuffer();
      _generateTypeScriptInterface(parsed, interfaceName, buffer, 0);
      return buffer.toString();
    } catch (e) {
      throw FormatException('无效的JSON格式: $e');
    }
  }

  void _generateTypeScriptInterface(
    dynamic value,
    String name,
    StringBuffer buffer,
    int depth,
  ) {
    final indent = '  ' * depth;

    if (value is Map) {
      buffer.writeln('$indent interface $name {');
      value.forEach((key, val) {
        final type = _getTypeScriptType(val, key);
        buffer.writeln('$indent  $key: $type;');
      });
      buffer.writeln('$indent }');
    }
  }

  String _getTypeScriptType(dynamic value, String key) {
    if (value == null) return 'any';
    if (value is String) return 'string';
    if (value is int) return 'number';
    if (value is double) return 'number';
    if (value is bool) return 'boolean';
    if (value is List) {
      if (value.isEmpty) return 'any[]';
      return '${_getTypeScriptType(value.first, key)}[]';
    }
    if (value is Map) return 'object';
    return 'any';
  }
}
```

- [ ] **Step 3: 验证文件创建**

```bash
ls -la lib/features/json_formatter/
```

Expected: 看到domain和presentation目录

- [ ] **Step 4: Commit**

```bash
git add lib/features/json_formatter/
git commit -m "feat: create json formatter module structure"
```

---

## Task 2: 实现JSON格式化UI界面

**Files:**

- Modify: `lib/features/json_formatter/presentation/json_formatter_page.dart`

- [ ] **Step 1: 创建JSON格式化页面**

创建 `lib/features/json_formatter/presentation/json_formatter_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../domain/json_formatter_service.dart';

class JsonFormatterPage extends StatefulWidget {
  const JsonFormatterPage({super.key});

  @override
  State<JsonFormatterPage> createState() => _JsonFormatterPageState();
}

class _JsonFormatterPageState extends State<JsonFormatterPage> {
  final JsonFormatterService _service = JsonFormatterService();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  String _selectedOperation = 'format';
  bool _isValidJson = true;
  String? _errorMessage;
  int _inputLineCount = 0;
  int _outputLineCount = 0;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final input = _inputController.text;
    setState(() {
      _isValidJson = _service.isValid(input);
      _inputLineCount = input.split('\n').length;
    });
  }

  void _processJson() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showToast('请输入JSON内容');
      return;
    }

    try {
      String result;
      switch (_selectedOperation) {
        case 'format':
          result = _service.format(input);
          break;
        case 'minify':
          result = _service.minify(input);
          break;
        case 'escape':
          result = _service.escape(input);
          break;
        case 'unescape':
          result = _service.unescape(input);
          break;
        case 'toDart':
          result = _service.toDartMap(input);
          break;
        case 'toTypeScript':
          result = _service.toTypeScriptInterface(input);
          break;
        default:
          result = _service.format(input);
      }

      setState(() {
        _outputController.text = result;
        _outputLineCount = result.split('\n').length;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showToast('处理失败: $e');
    }
  }

  void _copyToClipboard() {
    final text = _outputController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      _showToast('已复制到剪贴板');
    }
  }

  void _clearAll() {
    _inputController.clear();
    _outputController.clear();
    setState(() {
      _errorMessage = null;
      _inputLineCount = 0;
      _outputLineCount = 0;
    });
  }

  void _swapInputOutput() {
    final temp = _inputController.text;
    _inputController.text = _outputController.text;
    _outputController.text = temp;
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: 'JSON 格式化',
        subtitle: '格式化、压缩、转义JSON数据',
        showBack: true,
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: _clearAll,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.eraser, size: 15),
                SizedBox(width: 6),
                Text('清空'),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(shad),
          Expanded(
            child: _buildEditorArea(shad),
          ),
          _buildStatusBar(shad),
        ],
      ),
    );
  }

  Widget _buildToolbar(ShadThemeData shad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: shad.colorScheme.background,
        border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
      ),
      child: Row(
        children: [
          _buildOperationButton('格式化', 'format', LucideIcons.alignLeft),
          const SizedBox(width: 8),
          _buildOperationButton('压缩', 'minify', LucideIcons.minimize2),
          const SizedBox(width: 8),
          _buildOperationButton('转义', 'escape', LucideIcons.code),
          const SizedBox(width: 8),
          _buildOperationButton('反转义', 'unescape', LucideIcons.uncode),
          const SizedBox(width: 8),
          _buildOperationButton('转Dart', 'toDart', LucideIcons.braces),
          const SizedBox(width: 8),
          _buildOperationButton('转TS', 'toTypeScript', LucideIcons.fileCode),
          const Spacer(),
          ShadButton(
            size: ShadButtonSize.sm,
            onPressed: _processJson,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.play, size: 15),
                SizedBox(width: 6),
                Text('执行'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: _swapInputOutput,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowLeftRight, size: 15),
                SizedBox(width: 6),
                Text('交换'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationButton(String label, String value, IconData icon) {
    final shad = ShadTheme.of(context);
    final isSelected = _selectedOperation == value;

    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: () => setState(() => _selectedOperation = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? shad.colorScheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? shad.colorScheme.ring : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? shad.colorScheme.accentForeground : shad.colorScheme.mutedForeground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? shad.colorScheme.accentForeground : shad.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea(ShadThemeData shad) {
    return Row(
      children: [
        Expanded(
          child: _buildEditorPanel(
            shad,
            title: '输入',
            controller: _inputController,
            lineCount: _inputLineCount,
            isError: !_isValidJson && _inputController.text.isNotEmpty,
          ),
        ),
        Container(
          width: 1,
          color: shad.colorScheme.border,
        ),
        Expanded(
          child: _buildEditorPanel(
            shad,
            title: '输出',
            controller: _outputController,
            lineCount: _outputLineCount,
            readOnly: true,
            errorMessage: _errorMessage,
          ),
        ),
      ],
    );
  }

  Widget _buildEditorPanel(
    ShadThemeData shad, {
    required String title,
    required TextEditingController controller,
    required int lineCount,
    bool readOnly = false,
    bool isError = false,
    String? errorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: shad.colorScheme.muted,
            border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: shad.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!readOnly) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isError ? shad.colorScheme.destructive : shad.colorScheme.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isError ? '格式错误' : '格式正确',
                    style: TextStyle(
                      fontSize: 11,
                      color: isError ? Colors.white : shad.colorScheme.accentForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$lineCount 行',
                style: shad.textTheme.muted.copyWith(fontSize: 11),
              ),
              if (readOnly && controller.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: _copyToClipboard,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 13),
                      SizedBox(width: 4),
                      Text('复制', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: shad.colorScheme.destructive.withOpacity(0.1),
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 12,
                color: shad.colorScheme.destructive,
              ),
            ),
          ),
        Expanded(
          child: Container(
            color: shad.colorScheme.background,
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: readOnly ? '输出结果将显示在这里' : '请输入JSON内容...',
                hintStyle: TextStyle(
                  color: shad.colorScheme.mutedForeground,
                ),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(ShadThemeData shad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: shad.colorScheme.muted,
        border: Border(top: BorderSide(color: shad.colorScheme.border)),
      ),
      child: Row(
        children: [
          Icon(
            _isValidJson ? LucideIcons.checkCircle : LucideIcons.xCircle,
            size: 14,
            color: _isValidJson ? Colors.green : shad.colorScheme.destructive,
          ),
          const SizedBox(width: 6),
          Text(
            _isValidJson ? 'JSON格式有效' : 'JSON格式无效',
            style: TextStyle(
              fontSize: 12,
              color: _isValidJson ? Colors.green : shad.colorScheme.destructive,
            ),
          ),
          const Spacer(),
          Text(
            '当前操作: ${_getOperationName(_selectedOperation)}',
            style: shad.textTheme.muted.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getOperationName(String operation) {
    switch (operation) {
      case 'format':
        return '格式化';
      case 'minify':
        return '压缩';
      case 'escape':
        return '转义';
      case 'unescape':
        return '反转义';
      case 'toDart':
        return '转Dart Map';
      case 'toTypeScript':
        return '转TypeScript接口';
      default:
        return '格式化';
    }
  }
}
```

- [ ] **Step 2: 验证代码编译**

```bash
flutter analyze lib/features/json_formatter/presentation/json_formatter_page.dart
```

Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add lib/features/json_formatter/presentation/json_formatter_page.dart
git commit -m "feat: implement json formatter UI with multiple operations"
```

---

## Task 3: 注册路由和工具

**Files:**

- Modify: `lib/core/router/app_routes.dart`
- Modify: `lib/core/tools/tool_registry.dart`

- [ ] **Step 1: 添加路由**

修改 `lib/core/router/app_routes.dart`:

```dart
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String scheduler = '/tools/scheduler';
  static const String folderMapping = '/tools/folder-mapping';
  static const String backupRestore = '/tools/backup-restore';
  static const String jsonFormatter = '/tools/json-formatter';
}
```

- [ ] **Step 2: 注册工具**

修改 `lib/core/tools/tool_registry.dart`:

```dart
import 'package:flutter/material.dart';

import '../router/app_routes.dart';
import '../../features/backup_restore/presentation/backup_restore_page.dart';
import '../../features/folder_mapping/presentation/folder_mapping_page.dart';
import '../../features/json_formatter/presentation/json_formatter_page.dart';
import '../../features/scheduler/presentation/scheduler_page.dart';
import 'tool_descriptor.dart';

class ToolRegistry {
  ToolRegistry._();

  static final List<ToolDescriptor> tools = [
    ToolDescriptor(
      id: 'scheduler',
      title: '定时任务',
      description: '按时间与周期执行命令',
      icon: Icons.schedule,
      route: AppRoutes.scheduler,
      builder: (_) => const SchedulerPage(),
    ),
    ToolDescriptor(
      id: 'folder_mapping',
      title: '文件夹映射',
      description: '快捷管理并双击打开目录',
      icon: Icons.folder_copy_outlined,
      route: AppRoutes.folderMapping,
      builder: (_) => const FolderMappingPage(),
    ),
    ToolDescriptor(
      id: 'backup_restore',
      title: '备份还原',
      description: '导出当前数据或导入历史备份',
      icon: Icons.restore_page_outlined,
      route: AppRoutes.backupRestore,
      builder: (_) => const BackupRestorePage(),
    ),
    ToolDescriptor(
      id: 'json_formatter',
      title: 'JSON 格式化',
      description: '格式化、压缩、转义JSON数据',
      icon: Icons.data_object,
      route: AppRoutes.jsonFormatter,
      builder: (_) => const JsonFormatterPage(),
    ),
  ];
}
```

- [ ] **Step 3: 验证代码编译**

```bash
flutter analyze lib/core/router/app_routes.dart lib/core/tools/tool_registry.dart
```

Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/core/router/app_routes.dart lib/core/tools/tool_registry.dart
git commit -m "feat: register json formatter tool and route"
```

---

## Task 4: 排查修复开机自启bug

**Files:**

- Modify: `lib/core/system/app_tray_service.dart`

- [ ] **Step 1: 诊断当前问题**

检查当前的开机自启配置：

```bash
# 检查注册表中的自启动项
powershell -Command "Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' | Select-Object -Property '*工具集*', '*itools*'"
```

- [ ] **Step 2: 修复launch_at_startup配置**

当前问题分析：

1. `launch_at_startup`库需要正确的配置
2. 需要确保应用路径正确
3. 需要处理UAC权限问题

修改 `lib/core/system/app_tray_service.dart` 中的 `_setupLaunchAtStartup` 方法：

```dart
Future<void> _setupLaunchAtStartup() async {
  try {
    final executablePath = Platform.resolvedExecutable;
    final absolutePath = File(executablePath).absolute.path;

    debugPrint('[Tray] Setup launch at startup:');
    debugPrint('[Tray]   - App name: Windows 工具集');
    debugPrint('[Tray]   - Executable path: $executablePath');
    debugPrint('[Tray]   - Absolute path: $absolutePath');

    // 配置launch_at_startup
    launchAtStartup.setup(
      appName: 'Windows 工具集',
      appPath: absolutePath,
      // 添加参数以处理UAC
      args: ['--autostart'],
    );

    // 检查是否已启用
    _launchAtStartupEnabled = await launchAtStartup.isEnabled();
    debugPrint('[Tray] Launch at startup enabled: $_launchAtStartupEnabled');

    // 如果未启用，尝试启用
    if (!_launchAtStartupEnabled) {
      debugPrint('[Tray] Attempting to enable launch at startup...');
      await launchAtStartup.enable();
      _launchAtStartupEnabled = await launchAtStartup.isEnabled();
      debugPrint('[Tray] Launch at startup enabled after attempt: $_launchAtStartupEnabled');
    }

    // 验证注册表
    if (Platform.isWindows) {
      await _verifyRegistry();
    }
  } catch (e) {
    stderr.writeln('[Tray] setup launch at startup failed: $e');
    debugPrint('[Tray] ✗ Launch at startup setup failed: $e');
  }
}

Future<void> _verifyRegistry() async {
  try {
    final result = await Process.run('powershell', [
      '-Command',
      'Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" | Select-Object -Property "*工具集*"',
    ]);

    if (result.stdout.toString().isNotEmpty) {
      debugPrint('[Tray] Registry verification: ${result.stdout}');
    } else {
      debugPrint('[Tray] Warning: Registry entry not found');

      // 尝试手动设置注册表
      await _manualSetRegistry();
    }
  } catch (e) {
    debugPrint('[Tray] Failed to verify registry: $e');
  }
}

Future<void> _manualSetRegistry() async {
  try {
    final executablePath = Platform.resolvedExecutable;
    final absolutePath = File(executablePath).absolute.path;

    debugPrint('[Tray] Manually setting registry...');
    debugPrint('[Tray] Path: $absolutePath');

    // 使用VBS脚本处理UAC权限
    final vbsDir = File(absolutePath).parent.path;
    final vbsPath = '$vbsDir\\launch-elevated.vbs';

    // 创建VBS脚本
    final vbsContent = '''
Set objShell = CreateObject("Shell.Application")
objShell.ShellExecute "$absolutePath", "", "$vbsDir", "runas", 1
''';

    await File(vbsPath).writeAsString(vbsContent);
    debugPrint('[Tray] Created VBS script: $vbsPath');

    // 更新注册表指向VBS脚本
    final regCommand = '''
Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" `
  -Name "Windows 工具集" -Value "wscript.exe \\"$vbsPath\\"" -Force
''';

    final result = await Process.run('powershell', ['-Command', regCommand]);

    if (result.exitCode == 0) {
      debugPrint('[Tray] ✓ Registry updated successfully');
      _launchAtStartupEnabled = true;
    } else {
      debugPrint('[Tray] ✗ Failed to update registry: ${result.stderr}');
    }
  } catch (e) {
    debugPrint('[Tray] ✗ Manual registry setup failed: $e');
  }
}
```

- [ ] **Step 3: 添加开机自启状态检查方法**

在 `AppTrayService` 类中添加：

```dart
/// 检查开机自启状态
Future<bool> checkLaunchAtStartupStatus() async {
  try {
    final isEnabled = await launchAtStartup.isEnabled();
    debugPrint('[Tray] Launch at startup status: $isEnabled');

    if (Platform.isWindows) {
      // 额外检查注册表
      final result = await Process.run('powershell', [
        '-Command',
        'Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" | Select-Object -Property "*工具集*"',
      ]);

      debugPrint('[Tray] Registry check: ${result.stdout}');
    }

    return isEnabled;
  } catch (e) {
    debugPrint('[Tray] Failed to check launch at startup status: $e');
    return false;
  }
}

/// 修复开机自启
Future<bool> fixLaunchAtStartup() async {
  try {
    debugPrint('[Tray] Fixing launch at startup...');

    // 重新配置
    await _setupLaunchAtStartup();

    // 验证
    final isEnabled = await checkLaunchAtStartupStatus();

    debugPrint('[Tray] Launch at startup fix result: $isEnabled');
    return isEnabled;
  } catch (e) {
    debugPrint('[Tray] Failed to fix launch at startup: $e');
    return false;
  }
}
```

- [ ] **Step 4: 验证代码编译**

```bash
flutter analyze lib/core/system/app_tray_service.dart
```

Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git add lib/core/system/app_tray_service.dart
git commit -m "fix: improve launch at startup configuration and verification"
```

---

## Task 5: 更新项目文档

**Files:**

- Create: `docs/features/json-formatter.md`
- Modify: `docs/README.md`
- Create: `docs/AUTOSTART_TROUBLESHOOTING.md`

- [ ] **Step 1: 创建JSON格式化功能文档**

创建 `docs/features/json-formatter.md`:

````markdown
# JSON 格式化功能

## 功能概述

JSON 格式化工具提供了多种JSON数据处理功能，帮助开发者快速处理和转换JSON数据。

## 功能特性

### 1. 格式化

将压缩的JSON字符串格式化为易读的格式，支持自定义缩进。

**示例：**

```json
// 输入
{"name":"John","age":30,"city":"New York"}

// 输出
{
  "name": "John",
  "age": 30,
  "city": "New York"
}
```
````

### 2. 压缩

将格式化的JSON字符串压缩为单行，减少数据传输大小。

**示例：**

```json
// 输入
{
  "name": "John",
  "age": 30
}

// 输出
{"name":"John","age":30}
```

### 3. 转义

将JSON字符串进行转义，用于在代码中嵌入JSON。

**示例：**

```json
// 输入
{"key": "value"}

// 输出
"{\"key\": \"value\"}"
```

### 4. 反转义

将转义的JSON字符串还原。

**示例：**

```json
// 输入
"{\"key\": \"value\"}"

// 输出
{"key": "value"}
```

### 5. 转Dart Map

将JSON转换为Dart Map代码。

**示例：**

```dart
// 输入
{"name": "John", "age": 30}

// 输出
{
  'name': 'John',
  'age': 30,
}
```

### 6. 转TypeScript接口

根据JSON结构生成TypeScript接口定义。

**示例：**

```typescript
// 输入
{"name": "John", "age": 30}

// 输出
interface RootObject {
  name: string;
  age: number;
}
```

## 快捷操作

| 操作 | 说明                 |
| ---- | -------------------- |
| 执行 | 处理输入内容         |
| 交换 | 交换输入和输出内容   |
| 复制 | 复制输出内容到剪贴板 |
| 清空 | 清空所有内容         |

## 使用场景

1. **API调试**：格式化API响应数据
2. **数据处理**：压缩JSON以减少传输大小
3. **代码生成**：将JSON转换为Dart或TypeScript代码
4. **数据验证**：检查JSON格式是否正确

## 技术实现

- 使用Dart内置的`dart:convert`库进行JSON处理
- 支持UTF-8编码
- 实时验证JSON格式
- 错误提示和高亮

````

- [ ] **Step 2: 创建开机自启故障排查文档**

创建 `docs/AUTOSTART_TROUBLESHOOTING.md`:

```markdown
# 开机自启动故障排查指南

## 问题描述

应用配置了开机自启动，但Windows重启后应用没有自动启动。

## 可能原因

### 1. Windows启动管理器禁用了应用

**检查方法：**
1. 打开 Windows 设置
2. 进入 应用 > 启动
3. 查找"Windows 工具集"
4. 确保状态为"打开"

### 2. 注册表配置不正确

**检查方法：**
```powershell
# 检查注册表
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
  Select-Object -Property "*工具集*"
````

**预期输出：**

```
Windows 工具集 : C:\path\to\itools.exe
```

### 3. 应用路径变更

如果应用被移动或重命名，注册表中的路径将失效。

**解决方法：**

1. 重新运行应用
2. 在托盘菜单中禁用再启用开机自启

### 4. UAC权限问题

某些操作需要管理员权限，Windows无法自动提升权限。

**解决方法：**
使用VBS脚本代理启动（应用已自动配置）。

## 手动修复步骤

### 方法1：通过应用设置

1. 启动应用
2. 右键点击系统托盘图标
3. 选择"开机自启"（如果已启用，先禁用再启用）

### 方法2：通过注册表

```powershell
# 设置开机自启
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Windows 工具集" -Value "C:\path\to\itools.exe" -Force

# 删除开机自启
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Windows 工具集" -Force
```

### 方法3：通过任务计划程序

1. 打开"任务计划程序"
2. 创建基本任务
3. 设置触发器为"计算机启动时"
4. 设置操作为启动程序
5. 选择itools.exe

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

### Q: 为什么需要管理员权限？

A: 某些功能（如文件系统操作）需要管理员权限才能正常工作。

### Q: 如何避免UAC提示？

A: 可以调整Windows UAC设置，但不推荐，因为这会降低系统安全性。

### Q: 应用更新后需要重新配置吗？

A: 通常不需要，但如果应用路径发生变化，可能需要重新配置。

## 联系支持

如果以上方法都无法解决问题，请：

1. 收集诊断日志
2. 描述问题现象
3. 提供Windows版本信息
4. 联系开发团队

````

- [ ] **Step 3: 更新主文档**

修改 `docs/README.md`，添加新功能和文档链接：

```markdown
# iTools 开发文档

## 目录

- [功能模块](#功能模块)
- [开发指南](#开发指南)
- [部署指南](#部署指南)
- [故障排查](#故障排查)

## 功能模块

### 定时任务
按时间与周期执行命令，支持JS脚本和终端命令。

[详细文档](scheduler/README.md)

### 文件夹映射
快捷管理并双击打开目录，方便快速访问常用文件夹。

### 备份还原
导出当前数据或导入历史备份，支持数据迁移和恢复。

### JSON 格式化
格式化、压缩、转义JSON数据，支持多种转换操作。

[详细文档](features/json-formatter.md)

## 开发指南

### 环境要求
- Flutter SDK ^3.10.3
- Windows 10/11

### 项目结构
````

lib/
├── core/
│ ├── router/ # 路由配置
│ ├── system/ # 系统服务
│ ├── tools/ # 工具注册
│ └── widgets/ # 通用组件
├── features/
│ ├── backup_restore/ # 备份还原
│ ├── folder_mapping/ # 文件夹映射
│ ├── home/ # 首页
│ ├── json_formatter/ # JSON格式化
│ └── scheduler/ # 定时任务
└── main.dart

````

### 添加新工具

1. 在 `lib/features/` 下创建新目录
2. 实现功能模块
3. 在 `lib/core/tools/tool_registry.dart` 注册工具
4. 在 `lib/core/router/app_routes.dart` 添加路由

[详细指南](development/adding-tools.md)

## 部署指南

### 构建应用
```bash
flutter build windows --release
````

### 部署位置

默认部署到 `build/windows/x64/Release/`

[详细部署指南](deployment/README.md)

## 故障排查

### 开机自启问题

[开机自启故障排查指南](AUTOSTART_TROUBLESHOOTING.md)

### 应用无法启动

1. 检查是否缺少依赖
2. 以管理员身份运行
3. 检查防病毒软件

### 托盘图标不显示

1. 重启应用
2. 检查图标文件是否存在
3. 更新显卡驱动

````

- [ ] **Step 4: Commit**

```bash
git add docs/
git commit -m "docs: add json formatter and autostart troubleshooting documentation"
````

---

## Task 6: 最终验证和测试

- [ ] **Step 1: 运行代码分析**

```bash
flutter analyze
```

Expected: 无错误

- [ ] **Step 2: 运行测试**

```bash
flutter test
```

Expected: 所有测试通过

- [ ] **Step 3: 构建应用**

```bash
flutter build windows --release
```

Expected: 构建成功

- [ ] **Step 4: 测试JSON格式化功能**

1. 启动应用
2. 点击"JSON 格式化"工具卡片
3. 测试各种功能：
   - 格式化JSON
   - 压缩JSON
   - 转义JSON
   - 转Dart代码
   - 转TypeScript接口

- [ ] **Step 5: 测试开机自启功能**

1. 右键托盘图标
2. 点击"开机自启"
3. 重启电脑验证

- [ ] **Step 6: Final Commit**

```bash
git add .
git commit -m "feat: complete json formatter and autostart fix implementation"
```

---

## 总结

本计划完成了以下任务：

1. ✅ 创建JSON格式化功能模块
2. ✅ 实现多种JSON处理功能
3. ✅ 设计美观的UI界面
4. ✅ 注册路由和工具
5. ✅ 修复开机自启bug
6. ✅ 更新项目文档

所有代码遵循项目现有的架构和风格，确保一致性和可维护性。
