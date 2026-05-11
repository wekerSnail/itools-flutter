import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LuxuryTheme {
  LuxuryTheme._();

  static ShadThemeData light() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFFAF8F5),
        foreground: Color(0xFF2C2C2C),
        cardForeground: Color(0xFF2C2C2C),
        primary: Color(0xFF8B7355),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFF5F0EB),
        secondaryForeground: Color(0xFF5C4A3A),
        muted: Color(0xFFF0EBE3),
        mutedForeground: Color(0xFF8C8C8C),
        accent: Color(0xFFF5F0EB),
        accentForeground: Color(0xFF5C4A3A),
        border: Color(0xFFE5DDD5),
        input: Color(0xFFE5DDD5),
        ring: Color(0xFF8B7355),
        selection: Color(0xFFD4C5B2),
      ),
      radius: BorderRadius.circular(16),
    );
  }

  static ShadThemeData dark() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF1A1814),
        foreground: Color(0xFFE8E0D8),
        card: Color(0xFF242018),
        cardForeground: Color(0xFFE8E0D8),
        primary: Color(0xFFD4C5B2),
        primaryForeground: Color(0xFF1A1814),
        secondary: Color(0xFF2A2520),
        secondaryForeground: Color(0xFFC4B5A2),
        muted: Color(0xFF2A2520),
        mutedForeground: Color(0xFF8C8070),
        accent: Color(0xFF2A2520),
        accentForeground: Color(0xFFC4B5A2),
        border: Color(0xFF3A3530),
        input: Color(0xFF3A3530),
        ring: Color(0xFFD4C5B2),
        selection: Color(0xFF5C4A3A),
      ),
      radius: BorderRadius.circular(16),
    );
  }
}
