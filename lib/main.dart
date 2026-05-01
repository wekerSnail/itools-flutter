import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/system/app_tray_service.dart';
import 'core/system/single_instance_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] Flutter binding initialized');

  final singleInstance = SingleInstanceManager.instance;
  if (!singleInstance.tryAcquire()) {
    debugPrint('[Main] Another instance is already running, exiting');
    return;
  }

  await windowManager.ensureInitialized();
  debugPrint('[Main] Window manager initialized');

  const windowOptions = WindowOptions(
    size: Size(980, 720),
    minimumSize: Size(860, 620),
    center: true,
    title: '工具集',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    debugPrint('[Main] Window ready to show');
    await windowManager.show();
    await windowManager.focus();
    
    debugPrint('[Main] Window is now visible, initializing tray...');
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await AppTrayService.instance.initialize();
      debugPrint('[Main] ✓ Tray service initialized successfully');
    } catch (e, st) {
      debugPrint('[Main] ✗ Tray initialization failed: $e');
      debugPrint('[Main] Stack: $st');
    }
  });

  debugPrint('[Main] Running app');
  runApp(const ToolboxApp());
}
