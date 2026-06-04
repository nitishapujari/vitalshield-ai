import 'package:flutter/material.dart';

/// VitalShield AI Color System
/// Soft Blue-Purple Futurism palette
class AppColors {
  AppColors._();

  // ── Background & Surfaces ──
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF121830);
  static const Color surfaceLight = Color(0xFF1A2240);
  static const Color surfaceElevated = Color(0xFF1F2952);

  // ── Primary ──
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B83FF);
  static const Color primaryMuted = Color(0xFF4A43CC);

  // ── Secondary ──
  static const Color secondary = Color(0xFFA78BFA);
  static const Color secondaryLight = Color(0xFFC4B5FD);

  // ── Accent ──
  static const Color accent = Color(0xFF67E8F9);
  static const Color accentMuted = Color(0xFF4DD0E1);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF4B5563);

  // ── Status ──
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  // ── Glow (reduced intensity per feedback) ──
  static const Color glowPrimary = Color(0x156C63FF); // ~8% opacity
  static const Color glowAccent = Color(0x1567E8F9);
  static const Color glowSecondary = Color(0x15A78BFA);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF0F1529), Color(0xFF0A0E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF141A3A), Color(0xFF0D1225)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Borders ──
  static const Color border = Color(0xFF1E2748);
  static const Color borderLight = Color(0xFF2A3560);
  static const Color borderFocus = Color(0x806C63FF); // 50% primary
}
