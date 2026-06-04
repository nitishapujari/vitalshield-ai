import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Calm empty state shown when no conversation exists yet.
class EmptyConversationState extends StatelessWidget {
  final ValueChanged<String>? onQuickPrompt;

  const EmptyConversationState({super.key, this.onQuickPrompt});

  static const _quickPrompts = [
    'How is my sleep trend?',
    'Explain my wellness score',
    'What can improve my activity?',
    'Show recent wellness insights',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                LucideIcons.message_circle,
                size: AppSpacing.iconXl,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Your Wellness Companion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask about your wellness trends or recent insights.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _quickPrompts.map((prompt) {
                return GestureDetector(
                  onTap: () => onQuickPrompt?.call(prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      prompt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
