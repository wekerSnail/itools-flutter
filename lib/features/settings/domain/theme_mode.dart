enum AppThemeMode {
  light,
  dark,
  system;

  String get label {
    switch (this) {
      case AppThemeMode.light:
        return '亮色模式';
      case AppThemeMode.dark:
        return '暗色模式';
      case AppThemeMode.system:
        return '自动（跟随系统）';
    }
  }
}
