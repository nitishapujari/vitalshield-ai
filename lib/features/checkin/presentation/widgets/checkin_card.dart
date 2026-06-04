import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

/// Interactive card wrapper displaying a single metric question with transition animations.
class CheckinCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String description;
  final Widget inputWidget;
  final String? errorText;

  const CheckinCard({
    super.key,
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.inputWidget,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon & Step Label
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Question Text
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subtitle Description
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Metric Input Widget
            inputWidget,
            
            // Validation Error indicator
            if (errorText != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 14,
                    color: AppColors.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ).animate().fadeIn(duration: 150.ms),
            ],
          ],
        ),
      ),
    ).animate(key: ValueKey(step))
     .fadeIn(duration: 300.ms, curve: Curves.easeOut)
     .slideX(begin: 0.04, end: 0.0, duration: 300.ms, curve: Curves.easeOut);
  }
}
