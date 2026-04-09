import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../../features/home/presentation/home_page.dart';
import '../tools/tool_registry.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.home) {
      return MaterialPageRoute<void>(builder: (_) => const HomePage());
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
