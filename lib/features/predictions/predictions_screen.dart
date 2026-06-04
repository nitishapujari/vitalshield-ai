import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../services/api_service.dart';

import 'domain/models/prediction_model.dart';
import 'presentation/providers/predictions_provider.dart';
import 'presentation/widgets/prediction_empty_state.dart';
import 'presentation/widgets/wellness_score_ring.dart';
import 'presentation/widgets/prediction_summary.dart';
import 'presentation/widgets/prediction_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(predictionsProvider);
    final isDesktop = Responsive.isDesktop(context);

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.hasInsufficientData || state.latestSnapshot == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: PredictionEmptyState(),
        ),
      );
    }

    final snapshot = state.latestSnapshot!;
    final formattedDate = DateFormat('MMMM d, yyyy').format(snapshot.timestamp);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? AppSpacing.giant : AppSpacing.pageHorizontal,
              vertical: AppSpacing.pageVertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isBackendOffline)
                  _buildOfflineBanner(context, ref),

                // 1. Top Section: Heading & Subtitle
                Text(
                  'Wellness Trends & Predictions',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Personalized insights based on your recent check-in history.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // 2. Top Section: Score Ring & Middle Section: Summary Card
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: WellnessScoreRing(
                            score: snapshot.overallWellnessScore,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxl),
                      Expanded(
                        flex: 2,
                        child: PredictionSummary(
                          primaryInsight: snapshot.primaryInsight,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Center(
                        child: WellnessScoreRing(
                          score: snapshot.overallWellnessScore,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PredictionSummary(
                        primaryInsight: snapshot.primaryInsight,
                      ),
                    ],
                  ),

                const SizedBox(height: AppSpacing.xxxl),

                // 3. Main Content: Prediction Cards Grid
                Text(
                  'Category Trends',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Builder(
                  builder: (context) {
                    final isTablet = Responsive.isTablet(context);
                    
                    // Sort categories dynamically by recommendationPriority descending, then score ascending
                    final sortedCategories = List<PredictionCategoryModel>.from(snapshot.categories)
                      ..sort((a, b) {
                        int getPriorityRank(String priority) {
                          switch (priority.toLowerCase()) {
                            case 'critical':
                              return 3;
                            case 'warning':
                              return 2;
                            case 'info':
                            default:
                              return 1;
                          }
                        }

                        final pA = getPriorityRank(a.recommendationPriority);
                        final pB = getPriorityRank(b.recommendationPriority);

                        if (pA != pB) {
                          return pB.compareTo(pA); // descending priority
                        }

                        // If both are critical, sort by deterministic order using vitals from snapshot
                        if (pA == 3) {
                          final glucose = snapshot.glucose ?? 90.0;
                          final systolic = snapshot.systolic ?? 120;
                          final diastolic = snapshot.diastolic ?? 80;
                          final isBpCrisis = (systolic >= 180 || diastolic >= 120);

                          int getCriticalRank(PredictionCategoryModel c) {
                            if (c.categoryTitle == 'Glucose Wellness' && glucose < 55.0) {
                              return 3;
                            }
                            if (c.categoryTitle == 'Blood Pressure Wellness' && isBpCrisis) {
                              return 2;
                            }
                            if (c.categoryTitle == 'Glucose Wellness' && glucose > 300.0) {
                              return 1;
                            }
                            return 0;
                          }

                          final cA = getCriticalRank(a);
                          final cB = getCriticalRank(b);
                          if (cA != cB) {
                            return cB.compareTo(cA); // descending
                          }
                        }

                        if (a.score != b.score) {
                          return a.score.compareTo(b.score); // ascending score
                        }

                        return a.categoryTitle.compareTo(b.categoryTitle);
                      });

                    final cardWidgets = sortedCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      return PredictionCard(prediction: category)
                          .animate(delay: (index * 100).ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
                    }).toList();

                    if (isDesktop) {
                      final List<List<Widget>> cols = [[], [], []];
                      for (int i = 0; i < cardWidgets.length; i++) {
                        cols[i % 3].add(Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: cardWidgets[i],
                        ));
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cols[0],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cols[1],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cols[2],
                            ),
                          ),
                        ],
                      );
                    } else if (isTablet) {
                      final List<List<Widget>> cols = [[], []];
                      for (int i = 0; i < cardWidgets.length; i++) {
                        cols[i % 2].add(Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: cardWidgets[i],
                        ));
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cols[0],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cols[1],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: cardWidgets.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: w,
                        )).toList(),
                      );
                    }
                  },
                ),
                
                const SizedBox(height: AppSpacing.xxxl),

                // 4. Bottom Section: Metadata
                Center(
                  child: Text(
                    'Last updated: $formattedDate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, WidgetRef ref) {
    final backendState = ref.watch(backendProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.wifi_off,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Running offline local prediction models while reconnecting.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TextButton(
            onPressed: backendState.isCheckingHealth
                ? null
                : () async {
                    await ref.read(backendProvider.notifier).checkHealth();
                    await ref.read(predictionsProvider.notifier).refreshPredictions();
                  },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: backendState.isCheckingHealth
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : const Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
