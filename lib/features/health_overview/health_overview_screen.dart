import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../predictions/presentation/providers/predictions_provider.dart';
import '../predictions/domain/models/prediction_model.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/app_card.dart';

class HealthOverviewScreen extends ConsumerWidget {
  const HealthOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);
    final state = ref.watch(predictionsProvider);
    final dashboardState = ref.watch(dashboardProvider);

    if (state.isLoading || dashboardState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.hasInsufficientData || state.latestSnapshot == null || dashboardState.latestCheckin == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.shield_alert, size: 48, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'No health data yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Log your daily check-in metrics to unlock your health overview and physiological trend summaries.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final snapshot = state.latestSnapshot!;
    final latestCheckin = dashboardState.latestCheckin!;

    // 1. Mood/Stress Index based on physiological metrics (resting heart rate)
    final hr = latestCheckin.heartRate;
    String moodValue = 'Stable';
    String moodDetail = 'Resting heart rate is in optimal range.';
    if (hr != null) {
      if (hr > 85) {
        moodValue = 'Elevated Stress';
        moodDetail = 'Elevated heart rate ($hr BPM) indicates physical fatigue.';
      } else {
        moodValue = 'Stable';
        moodDetail = 'Resting heart rate ($hr BPM) is stable.';
      }
    }

    // 2. Sleep Quality category trend
    final sleepCategory = snapshot.categories.firstWhere(
      (c) => c.categoryTitle.toLowerCase().contains('sleep'),
      orElse: () => const PredictionCategoryModel(
        categoryTitle: 'Sleep Wellness',
        score: 70,
        status: 'Stable',
        trendDirection: TrendDirection.stable,
        insight: 'Sleep duration is consistent.',
        recommendation: '',
      ),
    );
    final sleepValue = sleepCategory.status;
    final sleepDetail = sleepCategory.insight;

    // 3. Activity category trend
    final activityCategory = snapshot.categories.firstWhere(
      (c) => c.categoryTitle.toLowerCase().contains('activity'),
      orElse: () => const PredictionCategoryModel(
        categoryTitle: 'Activity Wellness',
        score: 70,
        status: 'Consistent',
        trendDirection: TrendDirection.stable,
        insight: 'Daily steps are on track.',
        recommendation: '',
      ),
    );
    final activityValue = activityCategory.status;
    final activityDetail = activityCategory.insight;

    // 4. Risk Summary based on overall wellness score
    final score = snapshot.overallWellnessScore;
    String riskValue = 'Low';
    String riskDetail = 'Early warning signals are minimal.';
    if (score < 60) {
      riskValue = 'High';
      riskDetail = 'Recovery metrics are significantly elevated. Rest advised.';
    } else if (score < 80) {
      riskValue = 'Moderate';
      riskDetail = 'Some recovery metrics are outside optimal ranges.';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? AppSpacing.giant : AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Overview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'A snapshot of your most recent wellness metrics and recovery signals.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      children: [
                        _buildStatCard(
                          context: context,
                          icon: LucideIcons.heart,
                          title: 'Latest Mood',
                          value: moodValue,
                          detail: moodDetail,
                        ),
                        _buildStatCard(
                          context: context,
                          icon: LucideIcons.moon,
                          title: 'Sleep Quality',
                          value: sleepValue,
                          detail: sleepDetail,
                        ),
                        _buildStatCard(
                          context: context,
                          icon: LucideIcons.activity,
                          title: 'Activity',
                          value: activityValue,
                          detail: activityDetail,
                        ),
                        _buildStatCard(
                          context: context,
                          icon: LucideIcons.shield,
                          title: 'Risk Summary',
                          value: riskValue,
                          detail: riskDetail,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Key insight',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              snapshot.primaryInsight,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required String detail,
  }) {
    return SizedBox(
      width: 280,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
