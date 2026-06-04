import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class WellnessScoreRing extends StatelessWidget {
  final int score;

  const WellnessScoreRing({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    String scoreLabel = 'Moderate';
    Color labelColor = AppColors.warning;
    
    if (score >= 85) {
      scoreLabel = 'Optimal';
      labelColor = AppColors.success;
    } else if (score < 65) {
      scoreLabel = 'High Risk';
      labelColor = AppColors.error;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: score / 100.0,
                strokeWidth: 8,
                backgroundColor: AppColors.surfaceLight,
                color: labelColor,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: labelColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: labelColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            scoreLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
