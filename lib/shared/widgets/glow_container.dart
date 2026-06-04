import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Subtle glow wrapper for VitalShield AI.
/// Reduced intensity per design feedback — softly illuminated, not heavily glowing.
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double blurRadius;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor,
    this.blurRadius = 12,
    this.borderRadius = 20,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? AppColors.glowPrimary).withValues(alpha: 0.06),
            blurRadius: blurRadius,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
