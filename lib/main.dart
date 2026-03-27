import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/system/app_tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(980, 720),
    minimumSize: Size(860, 620),
    center: true,
    title: '工具集',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ToolboxApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await AppTrayService.instance.initialize();
  });
}
