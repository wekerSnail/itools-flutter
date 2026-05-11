import 'package:flutter/material.dart';

enum AppThemeStyle {
  modern,
  luxury,
  stellar,
  aurora,
  sunset;

  String get label {
    switch (this) {
      case AppThemeStyle.modern:
        return '精致现代';
      case AppThemeStyle.luxury:
        return '极简轻奢';
      case AppThemeStyle.stellar:
        return 'Stellar (电蓝)';
      case AppThemeStyle.aurora:
        return 'Aurora (翠绿)';
      case AppThemeStyle.sunset:
        return 'Sunset (深紫)';
    }
  }

  String get description {
    switch (this) {
      case AppThemeStyle.modern:
        return '优雅蓝色背景，清新现代风格';
      case AppThemeStyle.luxury:
        return '米灰中性色调，极简优雅风格';
      case AppThemeStyle.stellar:
        return '电光蓝 + 粉红对比，科技感十足';
      case AppThemeStyle.aurora:
        return '翠绿 + 琥珀金，自然高级感';
      case AppThemeStyle.sunset:
        return '深紫 + 琥珀金，温暖优雅感';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeStyle.modern:
        return Icons.palette;
      case AppThemeStyle.luxury:
        return Icons.diamond;
      case AppThemeStyle.stellar:
        return Icons.star;
      case AppThemeStyle.aurora:
        return Icons.light_mode;
      case AppThemeStyle.sunset:
        return Icons.wb_twilight;
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
      case AppThemeStyle.stellar:
        return [
          const Color(0xFF2563EB),
          const Color(0xFF60A5FA),
          const Color(0xFFEC4899),
        ];
      case AppThemeStyle.aurora:
        return [
          const Color(0xFF059669),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
        ];
      case AppThemeStyle.sunset:
        return [
          const Color(0xFF9333EA),
          const Color(0xFFA855F7),
          const Color(0xFFF59E0B),
        ];
    }
  }
}
