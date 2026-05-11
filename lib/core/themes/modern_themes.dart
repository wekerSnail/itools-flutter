import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design_tokens/index.dart';

/// Stellar Theme - Modern, electric blue with pink accents
/// Designed for tech-savvy users and developers
class StellarTheme {
  StellarTheme._();

  static ShadThemeData lightTheme() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFF8FAFC),
        foreground: Color(0xFF0F172A),
        cardForeground: Color(0xFF0F172A),
        primary: Color(0xFF2563EB),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFEC4899),
        secondaryForeground: Color(0xFFFFFFFF),
        muted: Color(0xFF64748B),
        mutedForeground: Color(0xFFF1F5F9),
        accent: Color(0xFFE0E7FF),
        accentForeground: Color(0xFF2563EB),
        border: Color(0xFFE2E8F0),
        input: Color(0xFFE2E8F0),
        ring: Color(0xFF2563EB),
        selection: Color(0xFFBFDBFE),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }

  static ShadThemeData darkTheme() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF0F172A),
        foreground: Color(0xFFF1F5F9),
        card: Color(0xFF1E293B),
        cardForeground: Color(0xFFF1F5F9),
        primary: Color(0xFF60A5FA),
        primaryForeground: Color(0xFF0F172A),
        secondary: Color(0xFFF472B6),
        secondaryForeground: Color(0xFF0F172A),
        muted: Color(0xFF94A3B8),
        mutedForeground: Color(0xFF334155),
        accent: Color(0xFF1E3A8A),
        accentForeground: Color(0xFF60A5FA),
        border: Color(0xFF334155),
        input: Color(0xFF334155),
        ring: Color(0xFF60A5FA),
        selection: Color(0xFF1E3A8A),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }
}

/// Aurora Theme - Natural, emerald green with amber accents
/// Designed for creative workers and designers
class AuroraTheme {
  AuroraTheme._();

  static ShadThemeData lightTheme() {
    return ShadThemeData(
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFF0FDF4),
        foreground: Color(0xFF0F766E),
        cardForeground: Color(0xFF0F766E),
        primary: Color(0xFF059669),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFF59E0B),
        secondaryForeground: Color(0xFFFFFFFF),
        muted: Color(0xFF64748B),
        mutedForeground: Color(0xFFF0FDF4),
        accent: Color(0xFFD1FAE5),
        accentForeground: Color(0xFF059669),
        border: Color(0xFFD1FAE5),
        input: Color(0xFFD1FAE5),
        ring: Color(0xFF059669),
        selection: Color(0xFFA7F3D0),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }

  static ShadThemeData darkTheme() {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF0F766E),
        foreground: Color(0xFFF0FDF4),
        card: Color(0xFF134E4A),
        cardForeground: Color(0xFFF0FDF4),
        primary: Color(0xFF10B981),
        primaryForeground: Color(0xFF0F766E),
        secondary: Color(0xFFFCD34D),
        secondaryForeground: Color(0xFF0F766E),
        muted: Color(0xFF94A3B8),
        mutedForeground: Color(0xFF2D5F59),
        accent: Color(0xFF047857),
        accentForeground: Color(0xFF10B981),
        border: Color(0xFF2D5F59),
        input: Color(0xFF2D5F59),
        ring: Color(0xFF10B981),
        selection: Color(0xFF047857),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }
}

/// Sunset Theme - Warm, deep purple with amber accents
/// Designed for premium users and creative professionals
class SunsetTheme {
  SunsetTheme._();

  static ShadThemeData lightTheme() {
    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadZincColorScheme.light(
        background: Color(0xFFFDF2F8),
        foreground: Color(0xFF3F0F5C),
        cardForeground: Color(0xFF3F0F5C),
        primary: Color(0xFF9333EA),
        primaryForeground: Color(0xFFFFFFFF),
        secondary: Color(0xFFF59E0B),
        secondaryForeground: Color(0xFFFFFFFF),
        muted: Color(0xFF64748B),
        mutedForeground: Color(0xFFFDF2F8),
        accent: Color(0xFFF3E8FF),
        accentForeground: Color(0xFF9333EA),
        border: Color(0xFFF3E8FF),
        input: Color(0xFFF3E8FF),
        ring: Color(0xFF9333EA),
        selection: Color(0xFFE9D5FF),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }

  static ShadThemeData darkTheme() {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(
        background: Color(0xFF3F0F5C),
        foreground: Color(0xFFF3E8FF),
        card: Color(0xFF581C87),
        cardForeground: Color(0xFFF3E8FF),
        primary: Color(0xFFA855F7),
        primaryForeground: Color(0xFF3F0F5C),
        secondary: Color(0xFFFCD34D),
        secondaryForeground: Color(0xFF3F0F5C),
        muted: Color(0xFF94A3B8),
        mutedForeground: Color(0xFF713F83),
        accent: Color(0xFF6D28D9),
        accentForeground: Color(0xFFA855F7),
        border: Color(0xFF713F83),
        input: Color(0xFF713F83),
        ring: Color(0xFFA855F7),
        selection: Color(0xFF6D28D9),
      ),
      radius: BorderRadius.circular(BorderRadiusTokens.md),
    );
  }
}
