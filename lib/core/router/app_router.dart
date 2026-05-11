import 'package:flutter/material.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../tools/tool_registry.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.home) {
      return MaterialPageRoute<void>(builder: (_) => const HomePage());
    }

    if (settings.name == AppRoutes.settings) {
      return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
    }

    final tool = ToolRegistry.tools
        .where((t) => t.route == settings.name)
        .firstOrNull;
    if (tool != null) {
      return MaterialPageRoute<void>(builder: tool.builder, settings: settings);
    }

    return MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('页面不存在'))),
    );
  }
}
