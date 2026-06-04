import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// VitalShield AI Decoration System
/// Reusable BoxDecorations, shadows, and gradient presets.
class AppDecorations {
  AppDecorations._();

  // ── Card Decoration ──
  static BoxDecoration card({
    Color? color,
    double radius = AppSpacing.radiusXl,
    bool withBorder = true,
    bool withGlow = false,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: withBorder
          ? Border.all(color: AppColors.border, width: 1)
          : null,
      boxShadow: withGlow
          ? [
              BoxShadow(
                color: AppColors.glowPrimary,
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  // ── Elevated Card ──
  static BoxDecoration elevatedCard({
    double radius = AppSpacing.radiusXl,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ── Input Field Decoration ──
  static BoxDecoration input({
    bool focused = false,
    double radius = AppSpacing.radiusMd,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused ? AppColors.borderFocus : AppColors.border,
        width: focused ? 1.5 : 1,
      ),
    );
  }

  // ── Sidebar Decoration ──
  static BoxDecoration sidebar() {
    return const BoxDecoration(
      color: AppColors.surface,
      border: Border(
        right: BorderSide(color: AppColors.border, width: 1),
      ),
    );
  }

  // ── Active Nav Item (subtle tinted pill) ──
  static BoxDecoration activeNavItem({
    double radius = AppSpacing.radiusMd,
  }) {
    return BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  // ── Subtle Glow Shadow ──
  static List<BoxShadow> subtleGlow({
    Color? color,
    double blur = 12,
  }) {
    return [
      BoxShadow(
        color: (color ?? AppColors.glowPrimary).withValues(alpha: 0.08),
        blurRadius: blur,
        spreadRadius: 0,
      ),
    ];
  }

  // ── Bottom Nav Decoration (minimal elevation) ──
  static BoxDecoration bottomNav() {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.95),
      border: const Border(
        top: BorderSide(color: AppColors.border, width: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }
}
