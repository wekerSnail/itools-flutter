import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ModernTheme {
  ModernTheme._();

  static ShadThemeData light() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFF8F9FE),
        foreground: Color(0xFF1A1A2E),
        cardForeground: Color(0xFF1A1A2E),
        primary: Color(0xFF6366F1),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFEEF2FF),
        secondaryForeground: Color(0xFF4338CA),
        muted: Color(0xFFF1F5F9),
        mutedForeground: Color(0xFF64748B),
        accent: Color(0xFFEEF2FF),
        accentForeground: Color(0xFF4338CA),
        border: Color(0xFFE2E8F0),
        input: Color(0xFFE2E8F0),
        ring: Color(0xFF6366F1),
        selection: Color(0xFFC7D2FE),
      ),
      radius: BorderRadius.circular(12),
    );
  }

  static ShadThemeData dark() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF0F0F1A),
        foreground: Color(0xFFE2E8F0),
        card: Color(0xFF1A1A2E),
        cardForeground: Color(0xFFE2E8F0),
        primary: Color(0xFF818CF8),
        primaryForeground: Color(0xFF0F0F1A),
        secondary: Color(0xFF1E1B4B),
        secondaryForeground: Color(0xFFA5B4FC),
        muted: Color(0xFF1E293B),
        mutedForeground: Color(0xFF94A3B8),
        accent: Color(0xFF1E1B4B),
        accentForeground: Color(0xFFA5B4FC),
        border: Color(0xFF2D2B5E),
        input: Color(0xFF2D2B5E),
        ring: Color(0xFF818CF8),
        selection: Color(0xFF3730A3),
      ),
      radius: BorderRadius.circular(12),
    );
  }
}
