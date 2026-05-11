import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design_tokens/index.dart';
import 'modern_themes.dart';
import 'theme_enums.dart';

/// Theme service to manage application themes
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  final ValueNotifier<AppThemeStyle> _currentStyle =
      ValueNotifier<AppThemeStyle>(AppThemeStyle.stellar);
  final ValueNotifier<AppThemeMode> _currentMode = ValueNotifier<AppThemeMode>(
    AppThemeMode.system,
  );

  ValueNotifier<AppThemeStyle> get styleNotifier => _currentStyle;
  ValueNotifier<AppThemeMode> get modeNotifier => _currentMode;

  AppThemeStyle get currentStyle => _currentStyle.value;
  AppThemeMode get currentMode => _currentMode.value;

  /// Get theme data for the current style and mode
  ShadThemeData getThemeData({AppThemeStyle? style, Brightness? brightness}) {
    final themeStyle = style ?? _currentStyle.value;
    final isDark = brightness == Brightness.dark;

    return switch (themeStyle) {
      AppThemeStyle.stellar =>
        isDark ? StellarTheme.darkTheme() : StellarTheme.lightTheme(),
      AppThemeStyle.aurora =>
        isDark ? AuroraTheme.darkTheme() : AuroraTheme.lightTheme(),
      AppThemeStyle.sunset =>
        isDark ? SunsetTheme.darkTheme() : SunsetTheme.lightTheme(),
    };
  }

  /// Set the theme style
  void setThemeStyle(AppThemeStyle style) {
    _currentStyle.value = style;
  }

  /// Set the theme mode
  void setThemeMode(AppThemeMode mode) {
    _currentMode.value = mode;
  }

  /// Get primary color for current theme
  Color getPrimaryColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkPrimary
            : StellarColors.stellarLightPrimary,
      AppThemeStyle.aurora =>
        isDark
            ? AuroraColors.auroraDarkPrimary
            : AuroraColors.auroraLightPrimary,
      AppThemeStyle.sunset =>
        isDark
            ? SunsetColors.sunsetDarkPrimary
            : SunsetColors.sunsetLightPrimary,
    };
  }

  /// Get secondary color for current theme
  Color getSecondaryColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkSecondary
            : StellarColors.stellarLightSecondary,
      AppThemeStyle.aurora =>
        isDark
            ? AuroraColors.auroraDarkSecondary
            : AuroraColors.auroraLightSecondary,
      AppThemeStyle.sunset =>
        isDark
            ? SunsetColors.sunsetDarkSecondary
            : SunsetColors.sunsetLightSecondary,
    };
  }

  /// Get background color for current theme
  Color getBackgroundColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkBackground
            : StellarColors.stellarLightBackground,
      AppThemeStyle.aurora =>
        isDark
            ? AuroraColors.auroraDarkBackground
            : AuroraColors.auroraLightBackground,
      AppThemeStyle.sunset =>
        isDark
            ? SunsetColors.sunsetDarkBackground
            : SunsetColors.sunsetLightBackground,
    };
  }

  /// Get surface color for current theme
  Color getSurfaceColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkSurface
            : StellarColors.stellarLightSurface,
      AppThemeStyle.aurora =>
        isDark
            ? AuroraColors.auroraDarkSurface
            : AuroraColors.auroraLightSurface,
      AppThemeStyle.sunset =>
        isDark
            ? SunsetColors.sunsetDarkSurface
            : SunsetColors.sunsetLightSurface,
    };
  }

  /// Get text color for current theme
  Color getTextColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark ? StellarColors.stellarDarkText : StellarColors.stellarLightText,
      AppThemeStyle.aurora =>
        isDark ? AuroraColors.auroraDarkText : AuroraColors.auroraLightText,
      AppThemeStyle.sunset =>
        isDark ? SunsetColors.sunsetDarkText : SunsetColors.sunsetLightText,
    };
  }

  /// Get border color for current theme
  Color getBorderColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkBorder
            : StellarColors.stellarLightBorder,
      AppThemeStyle.aurora =>
        isDark ? AuroraColors.auroraDarkBorder : AuroraColors.auroraLightBorder,
      AppThemeStyle.sunset =>
        isDark ? SunsetColors.sunsetDarkBorder : SunsetColors.sunsetLightBorder,
    };
  }

  /// Get muted color for current theme
  Color getMutedColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (_currentStyle.value) {
      AppThemeStyle.stellar =>
        isDark
            ? StellarColors.stellarDarkMuted
            : StellarColors.stellarLightMuted,
      AppThemeStyle.aurora =>
        isDark ? AuroraColors.auroraDarkMuted : AuroraColors.auroraLightMuted,
      AppThemeStyle.sunset =>
        isDark ? SunsetColors.sunsetDarkMuted : SunsetColors.sunsetLightMuted,
    };
  }
}
