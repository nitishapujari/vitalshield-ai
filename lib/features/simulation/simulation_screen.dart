import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'presentation/providers/simulation_provider.dart';
import '../predictions/presentation/widgets/wellness_score_ring.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_slider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';

class SimulationScreen extends ConsumerWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(simulationProvider);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.giant : AppSpacing.pageHorizontal,
            vertical: AppSpacing.pageVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text(
                'Future Wellness Simulation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Explore how adjusting your daily habits could shift your wellness projection.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              if (state.isBackendOffline)
                _buildOfflineBanner(context),

              // ── Top Section: Projected Score & Summary ──
              if (state.result != null)
                _buildProjectedScoreSummary(context, state.result!)
              else
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),

              const SizedBox(height: AppSpacing.xxxl),

              // ── Middle Section: Sliders & Projections ──
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildSimulationSliders(context, ref, state),
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          flex: 2,
                          child: _buildTrendProjections(context, state),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildSimulationSliders(context, ref, state),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildTrendProjections(context, state),
                      ],
                    ),

              const SizedBox(height: AppSpacing.xxxl),

              // ── Bottom Section: Observations ──
              if (state.result != null && state.result!.observations.isNotEmpty)
                _buildObservations(context, state.result!.observations),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
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
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.15),
        ),
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
              'Running local simulation while the backend is offline.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectedScoreSummary(BuildContext context, dynamic result) {
    return AppCard(
      withGlow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          WellnessScoreRing(score: result.projectedWellnessScore),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Projected Wellness Balance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  result.supportiveSummary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationSliders(
      BuildContext context, WidgetRef ref, SimulationState state) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adjust Daily Habits',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSlider(
            value: state.input.sleepHours,
            min: 4.0,
            max: 12.0,
            label: 'Projected Sleep Hours',
            unit: 'hrs',
            onChanged: (val) {
              ref.read(simulationProvider.notifier).updateInput(sleepHours: val);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSlider(
            value: state.input.steps.toDouble(),
            min: 0,
            max: 20000,
            divisions: 20,
            label: 'Projected Steps',
            unit: 'steps',
            onChanged: (val) {
              ref.read(simulationProvider.notifier).updateInput(steps: val.toInt());
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSlider(
            value: state.input.consistencyLevel,
            min: 0,
            max: 100,
            label: 'Habit Consistency Level',
            unit: '%',
            onChanged: (val) {
              ref.read(simulationProvider.notifier).updateInput(consistencyLevel: val);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSlider(
            value: state.input.routineQuality,
            min: 0,
            max: 100,
            label: 'Wellness Routine Quality',
            unit: '%',
            onChanged: (val) {
              ref.read(simulationProvider.notifier).updateInput(routineQuality: val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendProjections(BuildContext context, SimulationState state) {
    final shifts = state.result?.trendShifts ?? {};
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projected Trend Shifts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (shifts.isEmpty)
            Text(
              'No significant trend shifts estimated for these parameters.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ...shifts.entries.map((entry) {
              final isImproving = entry.value.contains('Improving');
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      isImproving ? LucideIcons.trending_up : LucideIcons.trending_down,
                      size: 16,
                      color: isImproving ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.value,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildObservations(BuildContext context, List<dynamic> observations) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Simulation Insights',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          ...observations.map((obs) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    obs.isPositive ? LucideIcons.circle_check : LucideIcons.info,
                    size: 16,
                    color: obs.isPositive ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obs.title,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          obs.description,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
