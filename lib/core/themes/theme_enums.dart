import 'package:flutter/material.dart';

/// Theme mode enum
enum AppThemeMode { light, dark, system }

extension AppThemeModeExt on AppThemeMode {
  ThemeMode toFlutterThemeMode() {
    return switch (this) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }
}

/// Theme style enum for selecting different color themes
enum AppThemeStyle { stellar, aurora, sunset }

extension AppThemeStyleExt on AppThemeStyle {
  String get displayName {
    return switch (this) {
      AppThemeStyle.stellar => 'Stellar (Blue)',
      AppThemeStyle.aurora => 'Aurora (Green)',
      AppThemeStyle.sunset => 'Sunset (Purple)',
    };
  }

  String get description {
    return switch (this) {
      AppThemeStyle.stellar => 'Modern, electric blue with pink accents',
      AppThemeStyle.aurora => 'Natural, emerald green with amber accents',
      AppThemeStyle.sunset => 'Warm, deep purple with amber accents',
    };
  }
}
