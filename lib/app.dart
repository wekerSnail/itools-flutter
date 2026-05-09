import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/router/app_navigation.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/tools/tool_registry.dart';
import 'features/settings/data/theme_service.dart';
import 'features/settings/domain/app_theme_style.dart';
import 'features/settings/domain/theme_mode.dart';

class ToolboxApp extends StatefulWidget {
  const ToolboxApp({super.key, this.toolId});

  final String? toolId;

  @override
  State<ToolboxApp> createState() => _ToolboxAppState();
}

class _ToolboxAppState extends State<ToolboxApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final service = ThemeService.instance;

    return ValueListenableBuilder<AppThemeStyle>(
      valueListenable: service.currentStyle,
      builder: (context, style, _) {
        return ValueListenableBuilder<AppThemeMode>(
          valueListenable: service.currentMode,
          builder: (context, mode, _) {
            final brightness = _resolveBrightness(mode);
            final themeData = service.getThemeData(style, brightness);

            return ShadApp(
              title: widget.toolId != null
                  ? (ToolRegistry.findById(widget.toolId!)?.title ?? '工具集')
                  : 'Windows 工具集',
              debugShowCheckedModeBanner: false,
              theme: themeData,
              themeMode: mode.toFlutterThemeMode(),
              home: widget.toolId != null
                  ? ToolRegistry.findById(widget.toolId!)?.builder(context)
                  : null,
              navigatorKey: widget.toolId == null ? appNavigatorKey : null,
              onGenerateRoute:
                  widget.toolId == null ? AppRouter.onGenerateRoute : null,
              initialRoute: widget.toolId == null ? AppRoutes.home : null,
            );
          },
        );
      },
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
