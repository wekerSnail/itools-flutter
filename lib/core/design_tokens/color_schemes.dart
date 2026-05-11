import 'package:flutter/material.dart';

/// Color scheme definitions for all themes
/// Each theme has light and dark variants

// ============== THEME 1: Stellar (Star Blue) ==============
class StellarColors {
  // Light mode
  static const stellarLightPrimary = Color(0xFF2563EB); // Electric Blue
  static const stellarLightSecondary = Color(0xFFEC4899); // Pink
  static const stellarLightBackground = Color(
    0xFFF8FAFC,
  ); // Ultra light blue-gray
  static const stellarLightSurface = Color(0xFFFFFFFF); // White
  static const stellarLightBorder = Color(0xFFE2E8F0); // Light blue-gray
  static const stellarLightText = Color(0xFF0F172A); // Dark blue-black
  static const stellarLightMuted = Color(0xFF64748B); // Muted gray

  // Dark mode
  static const stellarDarkPrimary = Color(0xFF60A5FA); // Light blue
  static const stellarDarkSecondary = Color(0xFFF472B6); // Light pink
  static const stellarDarkBackground = Color(0xFF0F172A); // Dark blue
  static const stellarDarkSurface = Color(0xFF1E293B); // Slightly lighter dark
  static const stellarDarkBorder = Color(0xFF334155); // Dark blue-gray
  static const stellarDarkText = Color(0xFFF1F5F9); // Light blue-gray
  static const stellarDarkMuted = Color(0xFF94A3B8); // Muted light
}

// ============== THEME 2: Aurora (Aurora Green) ==============
class AuroraColors {
  // Light mode
  static const auroraLightPrimary = Color(0xFF059669); // Emerald Green
  static const auroraLightSecondary = Color(0xFFF59E0B); // Amber
  static const auroraLightBackground = Color(0xFFF0FDF4); // Ultra light green
  static const auroraLightSurface = Color(0xFFFFFFFF); // White
  static const auroraLightBorder = Color(0xFFD1FAE5); // Light mint
  static const auroraLightText = Color(0xFF0F766E); // Dark teal
  static const auroraLightMuted = Color(0xFF64748B); // Muted gray

  // Dark mode
  static const auroraDarkPrimary = Color(0xFF10B981); // Light green
  static const auroraDarkSecondary = Color(0xFFFCD34D); // Light amber
  static const auroraDarkBackground = Color(0xFF0F766E); // Dark teal
  static const auroraDarkSurface = Color(0xFF134E4A); // Slightly lighter dark
  static const auroraDarkBorder = Color(0xFF2D5F59); // Dark teal-gray
  static const auroraDarkText = Color(0xFFF0FDF4); // Light green
  static const auroraDarkMuted = Color(0xFF94A3B8); // Muted light
}

// ============== THEME 3: Sunset (Sunset Purple) ==============
class SunsetColors {
  // Light mode
  static const sunsetLightPrimary = Color(0xFF9333EA); // Deep Purple
  static const sunsetLightSecondary = Color(0xFFF59E0B); // Amber
  static const sunsetLightBackground = Color(0xFFFDF2F8); // Ultra light purple
  static const sunsetLightSurface = Color(0xFFFFFFFF); // White
  static const sunsetLightBorder = Color(0xFFF3E8FF); // Light purple
  static const sunsetLightText = Color(0xFF3F0F5C); // Dark purple
  static const sunsetLightMuted = Color(0xFF64748B); // Muted gray

  // Dark mode
  static const sunsetDarkPrimary = Color(0xFFA855F7); // Light purple
  static const sunsetDarkSecondary = Color(0xFFFCD34D); // Light amber
  static const sunsetDarkBackground = Color(0xFF3F0F5C); // Dark purple
  static const sunsetDarkSurface = Color(0xFF581C87); // Slightly lighter dark
  static const sunsetDarkBorder = Color(0xFF713F83); // Dark purple-gray
  static const sunsetDarkText = Color(0xFFF3E8FF); // Light purple
  static const sunsetDarkMuted = Color(0xFF94A3B8); // Muted light
}

// ============== Neutral/Status Colors ==============
class StatusColors {
  // Success
  static const successLight = Color(0xFF10B981);
  static const successDark = Color(0xFF6EE7B7);

  // Warning
  static const warningLight = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFFBBF24);

  // Error
  static const errorLight = Color(0xFFEF4444);
  static const errorDark = Color(0xFFFCA5A5);

  // Info
  static const infoLight = Color(0xFF3B82F6);
  static const infoDark = Color(0xFF93C5FD);
}
