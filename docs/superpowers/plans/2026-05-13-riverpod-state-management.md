# Riverpod 状态管理迁移计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将项目从单例模式 + ValueNotifier 迁移到 Riverpod 状态管理，提高可测试性和代码可维护性

**Architecture:** 使用 Riverpod 的 Provider 替换单例服务，StateNotifier/AsyncNotifier 管理复杂状态，ConsumerWidget 替代 StatefulWidget 访问状态

**Tech Stack:** flutter_riverpod, riverpod_annotation (可选代码生成)

---

## 当前状态分析

### 需要迁移的单例服务

| 服务 | 当前模式 | 状态类型 | Riverpod 方案 |
|------|----------|----------|---------------|
| ThemeService | 单例 + ValueNotifier | AppThemeStyle, AppThemeMode | StateNotifierProvider |
| SchedulerService | 单例 + List<ScheduledTask> | 任务列表 | StateNotifierProvider |
| TaskRunner | 单例 + ValueNotifier | 日志列表 | StateNotifierProvider |
| HotkeyService | 单例 + List<HotkeyConfig> | 热键配置 | StateNotifierProvider |
| HotkeyActionRegistry | 单例 + Map | 动作注册表 | Provider (只读) |
| WindowManagerService | 单例 | 窗口管理 | Provider (只读) |
| AppTrayService | 单例 | 托盘服务 | Provider (只读) |

### 依赖关系

```
ThemeService (独立)
SchedulerService -> TaskRunner
HotkeyService -> HotkeyActionRegistry
WindowManagerService (独立)
AppTrayService (独立)
```

---

## 文件结构

### 新增文件

```
lib/
  core/
    providers/
      theme_provider.dart        # 主题状态 Provider
      scheduler_provider.dart    # 定时任务 Provider
      task_runner_provider.dart  # 任务运行 Provider
      hotkey_provider.dart       # 热键 Provider
      window_provider.dart       # 窗口管理 Provider
      tray_provider.dart         # 托盘服务 Provider
      providers.dart             # 统一导出
  app.dart                       # 修改：使用 ProviderScope
  main.dart                      # 修改：移除单例初始化
```

### 修改文件

```
lib/features/settings/presentation/theme_settings_page.dart
lib/features/settings/presentation/autostart_settings_page.dart
lib/features/scheduler/presentation/scheduler_page.dart
lib/features/scheduler/presentation/task_editor_page.dart
lib/features/scheduler/presentation/task_logs_page.dart
lib/features/hotkey_settings/presentation/hotkey_settings_page.dart
lib/features/home/presentation/home_page.dart
lib/features/folder_mapping/presentation/folder_mapping_page.dart
lib/features/json_formatter/presentation/json_formatter_page.dart
lib/features/backup_restore/presentation/backup_restore_page.dart
lib/features/settings/presentation/backup_settings_page.dart
lib/features/settings/presentation/settings_page.dart
```

---

## 实施任务

### Task 1: 添加 Riverpod 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 flutter_riverpod 依赖**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  # ... 其他依赖
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 验证安装**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add flutter_riverpod for state management"
```

---

### Task 2: 创建 ThemeProvider

**Files:**
- Create: `lib/core/providers/theme_provider.dart`
- Modify: `lib/features/settings/data/theme_service.dart`

- [ ] **Step 1: 创建 ThemeNotifier**

```dart
// lib/core/providers/theme_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../features/settings/data/theme_service.dart';
import '../../features/settings/domain/app_theme_style.dart';
import '../../features/settings/domain/theme_mode.dart';

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _load();
  }

  final _service = ThemeService();

  Future<void> _load() async {
    await _service.initialize();
    state = ThemeState(
      style: _service.currentStyle.value,
      mode: _service.currentMode.value,
    );
  }

  Future<void> setStyle(AppThemeStyle style) async {
    await _service.setThemeStyle(style);
    state = state.copyWith(style: style);
  }

  Future<void> setMode(AppThemeMode mode) async {
    await _service.setThemeMode(mode);
    state = state.copyWith(mode: mode);
  }

  ShadThemeData getThemeData(AppThemeStyle style, Brightness brightness) {
    return _service.getThemeData(style, brightness);
  }
}

class ThemeState {
  const ThemeState({
    this.style = AppThemeStyle.modern,
    this.mode = AppThemeMode.system,
  });

  final AppThemeStyle style;
  final AppThemeMode mode;

  ThemeState copyWith({
    AppThemeStyle? style,
    AppThemeMode? mode,
  }) {
    return ThemeState(
      style: style ?? this.style,
      mode: mode ?? this.mode,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
```

- [ ] **Step 2: 重构 ThemeService 移除单例**

```dart
// lib/features/settings/data/theme_service.dart
import 'dart:convert';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/file_store.dart';
import '../../../core/themes/luxury_theme.dart';
import '../../../core/themes/modern_theme.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

class ThemeService {
  ThemeService();  // 移除私有构造函数

  // 移除 static final instance

  static const String _storagePath = 'settings/theme.json';

  final _store = FileStore();
  
  // 保留 ValueNotifier 用于内部状态，但不再暴露为公共 API
  AppThemeStyle _currentStyle = AppThemeStyle.modern;
  AppThemeMode _currentMode = AppThemeMode.system;

  AppThemeStyle get currentStyle => _currentStyle;
  AppThemeMode get currentMode => _currentMode;

  Future<void> initialize() async {
    final raw = await _store.readJson(_storagePath);
    if (raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;

        final styleName = json['themeStyle'] as String?;
        if (styleName != null) {
          _currentStyle = AppThemeStyle.values.firstWhere(
            (e) => e.name == styleName,
            orElse: () => AppThemeStyle.modern,
          );
        }

        final modeName = json['themeMode'] as String?;
        if (modeName != null) {
          _currentMode = AppThemeMode.values.firstWhere(
            (e) => e.name == modeName,
            orElse: () => AppThemeMode.system,
          );
        }
      } catch (_) {
        _currentStyle = AppThemeStyle.modern;
        _currentMode = AppThemeMode.system;
      }
    }
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    _currentStyle = style;
    await _save();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _currentMode = mode;
    await _save();
  }

  Future<void> _save() async {
    final json = jsonEncode({
      'themeStyle': _currentStyle.name,
      'themeMode': _currentMode.name,
    });
    await _store.writeJson(_storagePath, json);
  }

  ShadThemeData getThemeData(AppThemeStyle style, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    switch (style) {
      case AppThemeStyle.modern:
        return isDark ? ModernTheme.dark() : ModernTheme.light();
      case AppThemeStyle.luxury:
        return isDark ? LuxuryTheme.dark() : LuxuryTheme.light();
    }
  }
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/providers/theme_provider.dart lib/features/settings/data/theme_service.dart
git commit -m "feat: create ThemeProvider with StateNotifier"
```

---

### Task 3: 创建 SchedulerProvider

**Files:**
- Create: `lib/core/providers/scheduler_provider.dart`
- Modify: `lib/features/scheduler/application/scheduler_service.dart`

- [ ] **Step 1: 创建 SchedulerNotifier**

```dart
// lib/core/providers/scheduler_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scheduler/application/scheduler_service.dart';
import '../../features/scheduler/domain/scheduled_task.dart';

class SchedulerNotifier extends StateNotifier<List<ScheduledTask>> {
  SchedulerNotifier() : super([]) {
    _load();
  }

  final _service = SchedulerService();

  Future<void> _load() async {
    await _service.initialize();
    state = List.unmodifiable(_service.tasks);
  }

  Future<void> reload() async {
    await _service.reloadTasks();
    state = List.unmodifiable(_service.tasks);
  }

  void addTask(ScheduledTask task) {
    _service.addTask(task);
    state = List.unmodifiable(_service.tasks);
  }

  void updateTask(ScheduledTask task) {
    _service.updateTask(task);
    state = List.unmodifiable(_service.tasks);
  }

  void removeTask(String taskId) {
    _service.removeTask(taskId);
    state = List.unmodifiable(_service.tasks);
  }

  Future<void> save() async {
    await _service.saveTasks();
  }
}

final schedulerProvider =
    StateNotifierProvider<SchedulerNotifier, List<ScheduledTask>>((ref) {
  return SchedulerNotifier();
});
```

- [ ] **Step 2: 重构 SchedulerService 移除单例**

```dart
// lib/features/scheduler/application/scheduler_service.dart
import 'package:flutter/foundation.dart';

import '../data/scheduler_store.dart';
import '../domain/scheduled_task.dart';
import 'task_runner.dart';

class SchedulerService {
  SchedulerService();  // 移除私有构造函数

  // 移除 static final instance

  final SchedulerStore _store = SchedulerStore();
  final List<ScheduledTask> _tasks = <ScheduledTask>[];
  bool _initialized = false;

  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[SchedulerService] Already initialized, skipping');
      return;
    }

    debugPrint('[SchedulerService] Initializing...');
    await _loadTasks();

    // TaskRunner 现在通过 Provider 管理
    _initialized = true;
    debugPrint('[SchedulerService] Initialized with ${_tasks.length} tasks');
  }

  Future<void> _loadTasks() async {
    try {
      final loaded = await _store.loadTasks();
      _tasks
        ..clear()
        ..addAll(loaded);
      debugPrint('[SchedulerService] Loaded ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[SchedulerService] Failed to load tasks: $e');
    }
  }

  Future<void> reloadTasks() async {
    await _loadTasks();
  }

  Future<void> saveTasks() async {
    try {
      await _store.saveTasks(_tasks);
      debugPrint('[SchedulerService] Saved ${_tasks.length} tasks');
    } catch (e) {
      debugPrint('[SchedulerService] Failed to save tasks: $e');
    }
  }

  void addTask(ScheduledTask task) {
    _tasks.insert(0, task);
  }

  void updateTask(ScheduledTask task) {
    final idx = _tasks.indexWhere((e) => e.id == task.id);
    if (idx >= 0) {
      _tasks[idx] = task;
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((e) => e.id == taskId);
  }

  void dispose() {
    _initialized = false;
  }
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/providers/scheduler_provider.dart lib/features/scheduler/application/scheduler_service.dart
git commit -m "feat: create SchedulerProvider with StateNotifier"
```

---

### Task 4: 创建 TaskRunnerProvider

**Files:**
- Create: `lib/core/providers/task_runner_provider.dart`
- Modify: `lib/features/scheduler/application/task_runner.dart`

- [ ] **Step 1: 创建 TaskRunnerNotifier**

```dart
// lib/core/providers/task_runner_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/scheduler/application/task_runner.dart';
import '../../features/scheduler/domain/scheduled_task.dart';

class TaskRunnerNotifier extends StateNotifier<List<String>> {
  TaskRunnerNotifier() : super([]) {
    _runner = TaskRunner();
    _runner.logs.addListener(_onLogsChanged);
  }

  late final TaskRunner _runner;

  void _onLogsChanged() {
    state = List.unmodifiable(_runner.logs.value);
  }

  void start({required List<ScheduledTask> Function() tasksProvider}) {
    _runner.start(tasksProvider: tasksProvider);
  }

  Future<void> runNow(ScheduledTask task) async {
    await _runner.runNow(task);
  }

  void stop() {
    _runner.stop();
  }

  @override
  void dispose() {
    _runner.logs.removeListener(_onLogsChanged);
    _runner.dispose();
    super.dispose();
  }
}

final taskRunnerProvider =
    StateNotifierProvider<TaskRunnerNotifier, List<String>>((ref) {
  final notifier = TaskRunnerNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
```

- [ ] **Step 2: 重构 TaskRunner 移除单例**

```dart
// lib/features/scheduler/application/task_runner.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/data/file_store.dart';
import '../domain/scheduled_task.dart';

class TaskRunner {
  TaskRunner();  // 移除私有构造函数

  // 移除 static final instance

  static const String _logsPath = 'scheduler/logs.json';
  static const Duration _logRetentionDuration = Duration(days: 5);
  final _store = FileStore();

  final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>(
    <String>[],
  );
  // ... 其余代码保持不变
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/providers/task_runner_provider.dart lib/features/scheduler/application/task_runner.dart
git commit -m "feat: create TaskRunnerProvider with StateNotifier"
```

---

### Task 5: 创建 HotkeyProvider

**Files:**
- Create: `lib/core/providers/hotkey_provider.dart`
- Modify: `lib/features/hotkey_settings/application/hotkey_service.dart`
- Modify: `lib/features/hotkey_settings/data/hotkey_action_registry.dart`

- [ ] **Step 1: 创建 HotkeyNotifier**

```dart
// lib/core/providers/hotkey_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/hotkey_settings/application/hotkey_service.dart';
import '../../features/hotkey_settings/data/hotkey_action_registry.dart';
import '../../features/hotkey_settings/domain/hotkey_config.dart';

class HotkeyNotifier extends StateNotifier<List<HotkeyConfig>> {
  HotkeyNotifier() : super([]) {
    _load();
  }

  final _service = HotkeyService();
  final _registry = HotkeyActionRegistry.instance;

  Future<void> _load() async {
    await _service.initialize();
    state = List.unmodifiable(_service.configs);
  }

  Future<void> updateConfig(HotkeyConfig config) async {
    await _service.updateConfig(config);
    state = List.unmodifiable(_service.configs);
  }

  Future<void> removeConfig(String configId) async {
    await _service.removeConfig(configId);
    state = List.unmodifiable(_service.configs);
  }
}

final hotkeyProvider =
    StateNotifierProvider<HotkeyNotifier, List<HotkeyConfig>>((ref) {
  return HotkeyNotifier();
});

final hotkeyRegistryProvider = Provider<HotkeyActionRegistry>((ref) {
  return HotkeyActionRegistry.instance;
});
```

- [ ] **Step 2: 重构 HotkeyService 移除单例**

```dart
// lib/features/hotkey_settings/application/hotkey_service.dart
import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../data/hotkey_action_registry.dart';
import '../data/hotkey_store.dart';
import '../domain/hotkey_config.dart';

class HotkeyService {
  HotkeyService();  // 移除私有构造函数

  // 移除 static final instance

  final HotkeyStore _store = HotkeyStore();
  final List<HotkeyConfig> _configs = <HotkeyConfig>[];
  bool _initialized = false;

  List<HotkeyConfig> get configs => List.unmodifiable(_configs);

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[HotkeyService] Already initialized, skipping');
      return;
    }

    debugPrint('[HotkeyService] Initializing...');
    await _loadConfigs();
    await _registerAll();
    _initialized = true;
    debugPrint('[HotkeyService] Initialized with ${_configs.length} configs');
  }

  // ... 其余代码保持不变，但移除 singleton 相关
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/core/providers/hotkey_provider.dart lib/features/hotkey_settings/application/hotkey_service.dart
git commit -m "feat: create HotkeyProvider with StateNotifier"
```

---

### Task 6: 创建 Window 和 Tray Provider

**Files:**
- Create: `lib/core/providers/window_provider.dart`
- Create: `lib/core/providers/tray_provider.dart`
- Modify: `lib/core/system/window_manager_service.dart`
- Modify: `lib/core/system/app_tray_service.dart`

- [ ] **Step 1: 创建 WindowProvider**

```dart
// lib/core/providers/window_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../system/window_manager_service.dart';

final windowServiceProvider = Provider<WindowManagerService>((ref) {
  return WindowManagerService.instance;
});
```

- [ ] **Step 2: 创建 TrayProvider**

```dart
// lib/core/providers/tray_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../system/app_tray_service.dart';

final trayServiceProvider = Provider<AppTrayService>((ref) {
  return AppTrayService.instance;
});
```

- [ ] **Step 3: 创建统一导出文件**

```dart
// lib/core/providers/providers.dart
export 'hotkey_provider.dart';
export 'scheduler_provider.dart';
export 'task_runner_provider.dart';
export 'theme_provider.dart';
export 'tray_provider.dart';
export 'window_provider.dart';
```

- [ ] **Step 4: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/
git commit -m "feat: create Window and Tray providers"
```

---

### Task 7: 修改 App 入口使用 ProviderScope

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 修改 app.dart 使用 Riverpod**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/providers/providers.dart';
import 'core/router/app_navigation.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/tools/tool_registry.dart';

class ToolboxApp extends ConsumerWidget {
  const ToolboxApp({super.key, this.toolId});

  final String? toolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final brightness = _resolveBrightness(themeState.mode);
    final themeData = ref
        .read(themeProvider.notifier)
        .getThemeData(themeState.style, brightness);

    return ShadApp(
      title: toolId != null
          ? (ToolRegistry.findById(toolId!)?.title ?? '工具集')
          : 'Windows 工具集',
      theme: themeData,
      themeMode: themeState.mode.toFlutterThemeMode(),
      home: toolId != null
          ? ToolRegistry.findById(toolId!)?.builder(context)
          : null,
      navigatorKey: toolId == null ? appNavigatorKey : null,
      onGenerateRoute: toolId == null ? AppRouter.onGenerateRoute : null,
      initialRoute: toolId == null ? AppRoutes.home : null,
    );
  }

  Brightness _resolveBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }
}
```

- [ ] **Step 2: 修改 main.dart 使用 ProviderScope**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/system/app_tray_service.dart';
import 'core/system/single_instance_manager.dart';
import 'core/system/window_manager_service.dart';
import 'core/tools/tool_registry.dart';
import 'features/hotkey_settings/application/hotkey_service.dart';
import 'features/hotkey_settings/data/hotkey_action_registry.dart';
import 'features/hotkey_settings/domain/hotkey_action_descriptor.dart';
import 'features/scheduler/application/scheduler_service.dart';

void _registerBuiltinHotkeyActions() {
  final registry = HotkeyActionRegistry.instance
    ..register(
      HotkeyActionDescriptor(
        id: 'open_main_window',
        title: '打开主窗口',
        description: '显示/隐藏应用主窗口',
        icon: LucideIcons.appWindow,
        onTrigger: () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );

  for (final tool in ToolRegistry.tools) {
    registry.register(
      HotkeyActionDescriptor(
        id: 'open_${tool.id}',
        title: '打开${tool.title}',
        description: '打开${tool.title}页面',
        icon: tool.icon,
        onTrigger: () {
          WindowManagerService.instance.openToolWindow(tool);
        },
      ),
    );
  }

  debugPrint('[Main] Registered ${registry.actions.length} hotkey actions');
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] Flutter binding initialized');

  _registerBuiltinHotkeyActions();

  if (args.isNotEmpty && args.first == 'multi_window') {
    final toolId = WindowManagerService.decodeToolId(args.elementAtOrNull(2));
    debugPrint('[Main] Child window launched: toolId=$toolId');

    final tool = toolId != null ? ToolRegistry.findById(toolId) : null;
    final windowSize = tool?.windowSize ?? const Size(900, 650);
    final minSize = tool?.minWindowSize ?? const Size(700, 500);
    final title = tool?.title ?? '工具集';

    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: minSize,
      center: true,
      title: title,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.setAlignment(Alignment.center);
    runApp(
      ProviderScope(
        child: ToolboxApp(toolId: toolId),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.show();
      await windowManager.focus();
    });

    return;
  }

  final singleInstance = SingleInstanceManager.instance;
  if (!singleInstance.tryAcquire()) {
    debugPrint('[Main] Another instance is already running, exiting');
    return;
  }

  debugPrint('[Main] Single instance acquired, continuing startup');

  await windowManager.ensureInitialized();
  debugPrint('[Main] Window manager initialized');

  const windowOptions = WindowOptions(
    size: Size(680, 520),
    minimumSize: Size(580, 450),
    center: true,
    title: '工具集',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    debugPrint('[Main] Window ready to show');
    await windowManager.show();
    await windowManager.focus();

    debugPrint('[Main] Window is now visible, initializing tray...');
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await AppTrayService.instance.initialize();
      debugPrint('[Main] Tray service initialized successfully');
    } catch (e, st) {
      debugPrint('[Main] Tray initialization failed: $e');
      debugPrint('[Main] Stack: $st');
    }

    debugPrint('[Main] Initializing scheduler service...');
    try {
      await SchedulerService.instance.initialize();
      debugPrint('[Main] Scheduler service initialized successfully');
    } catch (e, st) {
      debugPrint('[Main] Scheduler initialization failed: $e');
      debugPrint('[Main] Stack: $st');
    }

    debugPrint('[Main] Initializing hotkey service...');
    try {
      await HotkeyService.instance.initialize();
      debugPrint('[Main] Hotkey service initialized successfully');
    } catch (e, st) {
      debugPrint('[Main] Hotkey initialization failed: $e');
      debugPrint('[Main] Stack: $st');
    }
  });

  debugPrint('[Main] Running app');
  runApp(
    const ProviderScope(
      child: ToolboxApp(),
    ),
  );
}
```

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart lib/main.dart
git commit -m "feat: wrap app with ProviderScope for Riverpod"
```

---

### Task 8: 迁移 ThemeSettingsPage 使用 Riverpod

**Files:**
- Modify: `lib/features/settings/presentation/theme_settings_page.dart`

- [ ] **Step 1: 修改为 ConsumerWidget**

```dart
// lib/features/settings/presentation/theme_settings_page.dart
import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/themes/luxury_theme.dart';
import '../../../core/themes/modern_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shad = ShadTheme.of(context);
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '主题设置',
        subtitle: '自定义应用的外观风格',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          _buildOverviewSection(context, ref, shad, themeState),
          const SizedBox(height: Spacing.xl),
          _buildLivePreviewSection(context, ref, shad, themeState),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    WidgetRef ref,
    ShadThemeData shad,
    ThemeState themeState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageSectionHeader(
          title: '当前配置',
          subtitle: '选择主题风格和显示模式',
          icon: LucideIcons.palette,
        ),
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: Column(
            children: [
              _buildThemeStyleSelector(context, ref, shad, themeState),
              const SizedBox(height: Spacing.md),
              _buildThemeModeSelector(context, ref, shad, themeState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeStyleSelector(
    BuildContext context,
    WidgetRef ref,
    ShadThemeData shad,
    ThemeState themeState,
  ) {
    return Row(
      children: [
        Icon(LucideIcons.paintbrush, size: 18, color: shad.colorScheme.primary),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '主题风格',
                style: Typography.label.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
              Text(
                '选择应用的整体视觉风格',
                style: Typography.bodySmall.copyWith(
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        SegmentedButton<AppThemeStyle>(
          segments: const [
            ButtonSegment(
              value: AppThemeStyle.modern,
              label: Text('现代'),
            ),
            ButtonSegment(
              value: AppThemeStyle.luxury,
              label: Text('奢华'),
            ),
          ],
          selected: {themeState.style},
          onSelectionChanged: (selected) {
            ref.read(themeProvider.notifier).setStyle(selected.first);
          },
        ),
      ],
    );
  }

  Widget _buildThemeModeSelector(
    BuildContext context,
    WidgetRef ref,
    ShadThemeData shad,
    ThemeState themeState,
  ) {
    return Row(
      children: [
        Icon(LucideIcons.sun, size: 18, color: shad.colorScheme.primary),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '显示模式',
                style: Typography.label.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
              Text(
                '选择亮色、暗色或跟随系统',
                style: Typography.bodySmall.copyWith(
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment(
              value: AppThemeMode.light,
              label: Text('亮色'),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              label: Text('暗色'),
            ),
            ButtonSegment(
              value: AppThemeMode.system,
              label: Text('系统'),
            ),
          ],
          selected: {themeState.mode},
          onSelectionChanged: (selected) {
            ref.read(themeProvider.notifier).setMode(selected.first);
          },
        ),
      ],
    );
  }

  Widget _buildLivePreviewSection(
    BuildContext context,
    WidgetRef ref,
    ShadThemeData shad,
    ThemeState themeState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageSectionHeader(
          title: '实时预览',
          subtitle: '预览当前主题配置的效果',
          icon: LucideIcons.eye,
        ),
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: Column(
            children: [
              _buildPreviewCard(shad),
              const SizedBox(height: Spacing.md),
              _buildPreviewButtons(shad),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ShadThemeData shad) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: shad.colorScheme.card,
        border: Border.all(color: shad.colorScheme.border),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '示例卡片',
            style: Typography.h4.copyWith(
              color: shad.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '这是主题预览的示例内容',
            style: Typography.body.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewButtons(ShadThemeData shad) {
    return Row(
      children: [
        ShadButton(
          child: const Text('主要按钮'),
          onPressed: () {},
        ),
        const SizedBox(width: Spacing.sm),
        ShadButton.outline(
          child: const Text('次要按钮'),
          onPressed: () {},
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/presentation/theme_settings_page.dart
git commit -m "refactor: migrate ThemeSettingsPage to Riverpod"
```

---

### Task 9: 迁移 SchedulerPage 使用 Riverpod

**Files:**
- Modify: `lib/features/scheduler/presentation/scheduler_page.dart`

- [ ] **Step 1: 修改为 ConsumerStatefulWidget**

```dart
// lib/features/scheduler/presentation/scheduler_page.dart
import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/animations/animation_builders.dart';
import '../../../core/design_tokens/index.dart';
import '../../../core/providers/scheduler_provider.dart';
import '../../../core/providers/task_runner_provider.dart';
import '../../../core/widgets/loading_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../domain/scheduled_task.dart';
import 'task_editor_page.dart';
import 'task_logs_page.dart';

class SchedulerPage extends ConsumerStatefulWidget {
  const SchedulerPage({super.key});

  @override
  ConsumerState<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends ConsumerState<SchedulerPage> {
  final Set<String> _runningTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    ref.read(schedulerProvider.notifier).reload();
  }

  Future<void> _openEditor({ScheduledTask? task}) async {
    final savedTask = await Navigator.of(context).push<ScheduledTask>(
      PageTransitionBuilder.buildPageTransition<ScheduledTask>(
        context: context,
        builder: (_) => TaskEditorPage(initialTask: task),
      ),
    );
    if (savedTask == null || !mounted) return;

    final notifier = ref.read(schedulerProvider.notifier);
    if (task != null) {
      notifier.updateTask(savedTask);
    } else {
      notifier.addTask(savedTask);
    }
    await notifier.save();
  }

  Future<void> _toggleTask(ScheduledTask task, bool enabled) async {
    final notifier = ref.read(schedulerProvider.notifier)
      ..updateTask(task.copyWith(enabled: enabled));
    await notifier.save();
  }

  Future<void> _deleteTask(ScheduledTask task) async {
    final notifier = ref.read(schedulerProvider.notifier)
      ..removeTask(task.id);
    await notifier.save();
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<void> _runTaskNow(ScheduledTask task) async {
    if (_runningTaskIds.contains(task.id)) {
      return;
    }

    setState(() => _runningTaskIds.add(task.id));
    _showToast('开始测试运行：${task.name}');

    try {
      await ref.read(taskRunnerProvider.notifier).runNow(task);
      if (!mounted) return;
      _showToast('任务已执行完成：${task.name}');
    } catch (error) {
      if (!mounted) return;
      _showToast('任务执行失败：$error');
    } finally {
      if (mounted) {
        setState(() => _runningTaskIds.remove(task.id));
      }
    }
  }

  String _taskTypeLabel(ScheduledTaskType type) {
    switch (type) {
      case ScheduledTaskType.jsScript:
        return 'JS 脚本';
      case ScheduledTaskType.terminalCommand:
        return '终端命令';
    }
  }

  String _scheduleUnitLabel(ScheduleUnit unit) {
    switch (unit) {
      case ScheduleUnit.second:
        return '秒';
      case ScheduleUnit.minute:
        return '分钟';
      case ScheduleUnit.hour:
        return '小时';
      case ScheduleUnit.day:
        return '天';
      case ScheduleUnit.week:
        return '周';
      case ScheduleUnit.month:
        return '月';
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final tasks = ref.watch(schedulerProvider);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '定时任务',
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => Navigator.of(context).push(
              PageTransitionBuilder.buildPageTransition<void>(
                context: context,
                builder: (_) => const TaskLogsPage(),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText, size: 15),
                SizedBox(width: Spacing.xs),
                Text('运行日志'),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          ShadButton(
            size: ShadButtonSize.sm,
            onPressed: () => _openEditor(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 15),
                SizedBox(width: Spacing.xs),
                Text('添加任务'),
              ],
            ),
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: tasks.isEmpty
          ? _buildEmptyState(shad)
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                const PageSectionHeader(
                  title: '任务总览',
                  subtitle: '把定时任务的状态、频率和操作入口放在一套统一的列表语言里。',
                  icon: Icons.schedule,
                ),
                const SizedBox(height: Spacing.md),
                ...tasks.asMap().entries.map(
                  (entry) => StaggeredAnimationBuilder(
                    index: entry.key,
                    child: _buildTaskCard(context, shad, entry.value),
                  ),
                ),
              ],
            ),
    );
  }

  // ... _buildEmptyState 和 _buildTaskCard 方法保持不变
}
```

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/scheduler/presentation/scheduler_page.dart
git commit -m "refactor: migrate SchedulerPage to Riverpod"
```

---

### Task 10: 迁移其余页面使用 Riverpod

**Files:**
- Modify: `lib/features/settings/presentation/autostart_settings_page.dart`
- Modify: `lib/features/hotkey_settings/presentation/hotkey_settings_page.dart`
- Modify: `lib/features/home/presentation/home_page.dart`
- Modify: `lib/features/folder_mapping/presentation/folder_mapping_page.dart`
- Modify: `lib/features/json_formatter/presentation/json_formatter_page.dart`
- Modify: `lib/features/backup_restore/presentation/backup_restore_page.dart`
- Modify: `lib/features/settings/presentation/backup_settings_page.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`

- [ ] **Step 1: 迁移 autostart_settings_page.dart**

将 `StatefulWidget` 改为 `ConsumerStatefulWidget`，使用 `ref.read` 访问 `AppTrayService.instance`

- [ ] **Step 2: 迁移 hotkey_settings_page.dart**

将 `StatefulWidget` 改为 `ConsumerStatefulWidget`，使用 `ref.watch` 监听 `hotkeyProvider`

- [ ] **Step 3: 迁移 home_page.dart**

将 `StatelessWidget` 改为 `ConsumerWidget`，使用 `ref.read` 访问 `WindowManagerService`

- [ ] **Step 4: 迁移其余页面**

按照相同模式迁移其余页面

- [ ] **Step 5: 运行静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/features/
git commit -m "refactor: migrate remaining pages to Riverpod"
```

---

### Task 11: 运行测试验证

**Files:**
- Test: `test/widget_test.dart`
- Test: `test/visual/*.dart`

- [ ] **Step 1: 运行 flutter analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: 运行 flutter test**

Run: `flutter test`
Expected: 所有测试通过

- [ ] **Step 3: 修复失败的测试（如有）**

根据测试失败原因进行修复

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: fix tests after Riverpod migration"
```

---

## 执行顺序建议

1. Task 1: 添加依赖
2. Task 2-6: 创建 Provider（可并行）
3. Task 7: 修改 App 入口
4. Task 8-10: 迁移页面（可并行）
5. Task 11: 测试验证

## 注意事项

1. **渐进式迁移**：可以先保留单例服务，逐步迁移到 Provider
2. **测试策略**：每迁移一个服务就运行测试，确保不破坏现有功能
3. **依赖注入**：Riverpod 的 Provider 天然支持依赖注入，便于测试
4. **性能优化**：使用 `select` 和 `listen` 精确控制重建范围
