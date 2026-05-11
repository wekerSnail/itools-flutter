import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/system/app_tray_service.dart';
import 'core/system/single_instance_manager.dart';
import 'core/system/window_manager_service.dart';
import 'core/tools/tool_registry.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] Flutter binding initialized');

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
  });

  debugPrint('[Main] Running app');
  runApp(const ToolboxApp());
}
