import 'package:flutter/material.dart';
import '../../domain/models/explanation_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ExplanationCard extends StatefulWidget {
  final PredictionExplanation explanation;

  const ExplanationCard({super.key, required this.explanation});

  @override
  State<ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<ExplanationCard> {
  bool _isExpanded = false;

  Color _getImpactColor(FactorImpact impact) {
    switch (impact) {
      case FactorImpact.positive:
        return AppColors.success.withValues(alpha: 0.7);
      case FactorImpact.negative:
        return const Color(0xFFFCA5A5); // Soft peach/coral instead of harsh red
      case FactorImpact.neutral:
        return AppColors.textSecondary.withValues(alpha: 0.5);
    }
  }

  /// Converts a numerical contribution into a calm, human-friendly label.
  String _getImpactLabel(double contributionPercent) {
    if (contributionPercent >= 60) return 'Key factor';
    if (contributionPercent >= 35) return 'Supporting factor';
    return 'Minor factor';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.explanation.factors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Why this insight?',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    ...widget.explanation.factors.map((factor) {
                      final color = _getImpactColor(factor.impact);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  factor.label,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  _getImpactLabel(factor.contributionPercent),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            // Progress bar showing contribution
                            Stack(
                              children: [
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: factor.contributionPercent / 100.0,
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              factor.description,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
