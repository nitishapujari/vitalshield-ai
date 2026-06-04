import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Reusable card widget for VitalShield AI.
/// Soft surface with subtle border, spacious padding.
/// No heavy glassmorphism — minimal translucency only.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final bool withBorder;
  final bool withGlow;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppSpacing.radiusXl,
    this.backgroundColor,
    this.withBorder = true,
    this.withGlow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: withBorder
            ? Border.all(color: AppColors.border, width: 1)
            : null,
        boxShadow: withGlow
            ? [
                BoxShadow(
                  color: AppColors.glowPrimary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: AppColors.primary.withValues(alpha: 0.05),
                highlightColor: AppColors.primary.withValues(alpha: 0.03),
                child: Padding(
                  padding: padding ??
                      const EdgeInsets.all(AppSpacing.cardPadding),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ??
                    const EdgeInsets.all(AppSpacing.cardPadding),
                child: child,
              ),
      ),
    );
  }
}
