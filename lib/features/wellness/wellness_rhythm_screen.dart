import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'presentation/providers/cycle_provider.dart';
import 'domain/services/cycle_engine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_slider.dart';
import '../../shared/widgets/app_button.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';

class WellnessRhythmScreen extends ConsumerWidget {
  const WellnessRhythmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleState = ref.watch(cycleProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final isDesktop = Responsive.isDesktop(context);
    final data = cycleState.data;
    final isEnabled = data.isTrackingEnabled;
    final user = dashboardState.user;

    // Direct guard: if not female, show a friendly warning.
    // However, the router/sidebar should already prevent navigation.
    final isFemale = user?.gender.toLowerCase() == 'female';
    if (!isFemale) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shield_alert, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Access Restricted',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Wellness Rhythm is only available for female profiles.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.giant : AppSpacing.pageHorizontal,
            vertical: AppSpacing.pageVertical,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Text(
                    'Wellness Rhythm',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Align your physical activity, recovery guidance, and rest cycles with your natural monthly energetic phase.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  if (cycleState.isLoading)
                    const Center(child: CircularProgressIndicator(color: AppColors.secondary))
                  else if (!isEnabled)
                    _buildSetupState(context, ref)
                  else
                    _buildActiveState(context, ref, cycleState),
                ],
              ).animate().fadeIn(duration: 500.ms),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupState(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.flower_2,
                  size: 40,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                'Personalize Your Recovery Guidance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Enable Wellness Rhythm to automatically adapt your daily sleep targets, movement goals, and AI assistant observations based on your cycle phases.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            
            // Feature bullet list
            _buildFeatureBullet(
              context,
              icon: LucideIcons.moon,
              title: 'Adaptive Sleep Windows',
              desc: 'Recommends extra recovery hours during lower energy phases.',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildFeatureBullet(
              context,
              icon: LucideIcons.footprints,
              title: 'Intelligent Step Targets',
              desc: 'Encourages high intensity during peak energy and gentle movement during rest phases.',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildFeatureBullet(
              context,
              icon: LucideIcons.sparkles,
              title: 'Contextual AI Advice',
              desc: 'Adapts assistant insight tone and wellness recommendations to your active phase.',
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Enable Wellness Rhythm',
              icon: LucideIcons.flower_2,
              onPressed: () {
                ref.read(cycleProvider.notifier).toggleTracking(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(BuildContext context, {required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveState(BuildContext context, WidgetRef ref, CycleState state) {
    final data = state.data;
    final lastStart = data.lastCycleStart ?? DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy').format(lastStart);
    final cycleContext = CycleEngine.getCurrentContext(data);

    return Column(
      children: [
        // Tracking State Card (to disable)
        AppCard(
          child: SwitchListTile(
            title: Text(
              'Rhythm Personalization Active',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            subtitle: Text(
              'Your goals and recommendations are adapting dynamically.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
            ),
            value: data.isTrackingEnabled,
            activeThumbColor: AppColors.secondary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              ref.read(cycleProvider.notifier).toggleTracking(val);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Settings details
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rhythm Start Date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: lastStart,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.secondary,
                                onPrimary: AppColors.background,
                                surface: AppColors.surface,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        ref.read(cycleProvider.notifier).updateStartDate(picked);
                      }
                    },
                    icon: const Icon(LucideIcons.calendar, size: 14),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSlider(
                value: data.averageCycleLength.toDouble(),
                min: 21,
                max: 35,
                divisions: 14,
                label: 'Average Cycle Length',
                unit: 'days',
                onChanged: (val) {
                  ref.read(cycleProvider.notifier).updateLength(val.toInt());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Display current phase details
        if (cycleContext != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Phase: ${CycleEngine.getLabelString(cycleContext.phaseLabel)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                    ),
                    Text(
                      'Day ${cycleContext.daysIntoCycle}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  CycleEngine.getPhaseAdvice(cycleContext.phaseLabel),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
