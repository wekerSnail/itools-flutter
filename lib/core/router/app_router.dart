import 'package:flutter/widgets.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../tools/tool_registry.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.home) {
      return PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HomePage(),
        settings: settings,
      );
    }

    if (settings.name == AppRoutes.settings) {
      return PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SettingsPage(),
        settings: settings,
      );
    }

    final tool = ToolRegistry.tools
        .where((t) => t.route == settings.name)
        .firstOrNull;
    if (tool != null) {
      return PageRouteBuilder<void>(
        pageBuilder: (context, __, ___) => tool.builder(context),
        settings: settings,
      );
    }

    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) =>
          const Center(child: Text('页面不存在')),
    );
  }
}
