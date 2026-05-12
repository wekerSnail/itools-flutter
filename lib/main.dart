import 'package:flutter/material.dart';
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
    runApp(ToolboxApp(toolId: toolId));

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
  runApp(const ToolboxApp());
}
