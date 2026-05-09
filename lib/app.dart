import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/router/app_navigation.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/tools/tool_registry.dart';

class ToolboxApp extends StatelessWidget {
  const ToolboxApp({super.key, this.toolId});

  final String? toolId;

  @override
  Widget build(BuildContext context) {
    final theme = ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadZincColorScheme.light(),
    );
    final darkTheme = ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    );

    if (toolId != null) {
      final tool = ToolRegistry.findById(toolId!);
      if (tool != null) {
        return ShadApp(
          title: tool.title,
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          home: tool.builder(context),
        );
      }
    }

    return ShadApp(
      title: 'Windows 工具集',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      navigatorKey: appNavigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRoutes.home,
    );
  }
}
