import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/providers/theme_provider.dart';
import 'core/router/app_navigation.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/tools/tool_registry.dart';
import 'features/settings/domain/theme_mode.dart';

ThemeMode _toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

class ToolboxApp extends ConsumerStatefulWidget {
  const ToolboxApp({super.key, this.toolId});

  final String? toolId;

  @override
  ConsumerState<ToolboxApp> createState() => _ToolboxAppState();
}

class _ToolboxAppState extends ConsumerState<ToolboxApp> {
  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return themeState.when(
      loading: () => const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('加载中...')),
      ),
      error: (error, _) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('主题加载失败: $error')),
      ),
      data: (state) {
        final brightness = _resolveBrightness(state.mode);
        final themeData = ref
            .read(themeProvider.notifier)
            .getThemeData(state.style, brightness);

        return ShadApp(
          title: widget.toolId != null
              ? (ToolRegistry.findById(widget.toolId!)?.title ?? '工具集')
              : 'Windows 工具集',
          theme: themeData,
          themeMode: _toFlutterThemeMode(state.mode),
          home: widget.toolId != null
              ? ToolRegistry.findById(widget.toolId!)?.builder(context)
              : null,
          navigatorKey: widget.toolId == null ? appNavigatorKey : null,
          onGenerateRoute: widget.toolId == null
              ? AppRouter.onGenerateRoute
              : null,
          initialRoute: widget.toolId == null ? AppRoutes.home : null,
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
