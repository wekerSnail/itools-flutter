import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/file_store.dart';
import '../../../core/themes/luxury_theme.dart';
import '../../../core/themes/modern_theme.dart';
import '../domain/app_theme_style.dart';
import '../domain/theme_mode.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _storagePath = 'settings/theme.json';

  final _store = FileStore();
  final ValueNotifier<AppThemeStyle> currentStyle = ValueNotifier(AppThemeStyle.modern);
  final ValueNotifier<AppThemeMode> currentMode = ValueNotifier(AppThemeMode.system);

  Future<void> initialize() async {
    final raw = await _store.readJson(_storagePath);
    if (raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;

        final styleName = json['themeStyle'] as String?;
        if (styleName != null) {
          currentStyle.value = AppThemeStyle.values.firstWhere(
            (e) => e.name == styleName,
            orElse: () => AppThemeStyle.modern,
          );
        }

        final modeName = json['themeMode'] as String?;
        if (modeName != null) {
          currentMode.value = AppThemeMode.values.firstWhere(
            (e) => e.name == modeName,
            orElse: () => AppThemeMode.system,
          );
        }
      } catch (_) {
        currentStyle.value = AppThemeStyle.modern;
        currentMode.value = AppThemeMode.system;
      }
    }
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    currentStyle.value = style;
    await _save();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    currentMode.value = mode;
    await _save();
  }

  Future<void> _save() async {
    final json = jsonEncode({
      'themeStyle': currentStyle.value.name,
      'themeMode': currentMode.value.name,
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
