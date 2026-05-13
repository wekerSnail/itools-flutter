import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/file_store.dart';
import '../../../core/themes/luxury_theme.dart';
import '../../../core/themes/modern_theme.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

class ThemeLoadResult {
  const ThemeLoadResult({
    required this.style,
    required this.mode,
  });

  final AppThemeStyle style;
  final AppThemeMode mode;
}

class ThemeService {
  static const String _storagePath = 'settings/theme.json';

  final _store = FileStore();

  Future<ThemeLoadResult?> load() async {
    final raw = await _store.readJson(_storagePath);
    if (raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final styleName = json['themeStyle'] as String?;
      final style = styleName != null
          ? AppThemeStyle.values.firstWhere(
              (e) => e.name == styleName,
              orElse: () => AppThemeStyle.modern,
            )
          : AppThemeStyle.modern;

      final modeName = json['themeMode'] as String?;
      final mode = modeName != null
          ? AppThemeMode.values.firstWhere(
              (e) => e.name == modeName,
              orElse: () => AppThemeMode.system,
            )
          : AppThemeMode.system;

      return ThemeLoadResult(style: style, mode: mode);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required AppThemeStyle style,
    required AppThemeMode mode,
  }) async {
    final json = jsonEncode({
      'themeStyle': style.name,
      'themeMode': mode.name,
    });
    await _store.writeJson(_storagePath, json);
  }

  ShadThemeData getThemeData(AppThemeStyle style, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    switch (style) {
      case AppThemeStyle.modern:
        return isDark ? ModernTheme.dark() : ModernTheme.light();
      case AppThemeStyle.luxury:
        return isDark ? LuxuryTheme.dark() : LuxuryTheme.light();
    }
  }
}
