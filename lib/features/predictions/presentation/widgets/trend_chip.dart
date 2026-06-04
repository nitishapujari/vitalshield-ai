import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../domain/models/prediction_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class TrendChip extends StatelessWidget {
  final TrendDirection trend;

  const TrendChip({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    IconData icon;

    switch (trend) {
      case TrendDirection.improving:
        label = 'Improving';
        color = AppColors.success;
        icon = LucideIcons.trending_up;
        break;
      case TrendDirection.stable:
        label = 'Stable';
        color = AppColors.warning;
        icon = LucideIcons.minus;
        break;
      case TrendDirection.needsAttention:
        label = 'Needs Attention';
        color = AppColors.error;
        icon = LucideIcons.activity;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
