import 'package:flutter/material.dart';

enum AppThemeStyle {
  modern,
  luxury;

  String get label {
    switch (this) {
      case AppThemeStyle.modern:
        return '精致现代';
      case AppThemeStyle.luxury:
        return '极简轻奢';
    }
  }

  String get description {
    switch (this) {
      case AppThemeStyle.modern:
        return '优雅蓝色背景，清新现代风格';
      case AppThemeStyle.luxury:
        return '米灰中性色调，极简优雅风格';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeStyle.modern:
        return Icons.palette;
      case AppThemeStyle.luxury:
        return Icons.diamond;
    }
  }

  List<Color> get previewColors {
    switch (this) {
      case AppThemeStyle.modern:
        return [
          const Color(0xFF6366F1),
          const Color(0xFF8B5CF6),
          const Color(0xFFA78BFA),
        ];
      case AppThemeStyle.luxury:
        return [
          const Color(0xFFF5F0EB),
          const Color(0xFFD4C5B2),
          const Color(0xFF8B7355),
        ];
    }
  }
}
