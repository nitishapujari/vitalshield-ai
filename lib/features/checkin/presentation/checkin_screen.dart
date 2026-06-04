import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'providers/checkin_provider.dart';
import 'widgets/checkin_progress.dart';
import 'widgets/checkin_card.dart';
import 'widgets/metric_input.dart';
import 'widgets/analysis_loader.dart';
import '../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/app_button.dart';

/// Screen hosting the step-by-step Daily Check-In flow.
class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinProvider);
    final notifier = ref.read(checkinProvider.notifier);

    // Responsive configurations
    final isDesktop = Responsive.isDesktop(context);

    // Dynamic configuration for steps
    final List<(IconData, String, String)> stepConfig = [
      (
        LucideIcons.heart_pulse,
        'What is your resting heart rate today?',
        'Measure after 5 minutes of rest for the most accurate baseline.'
      ),
      (
        LucideIcons.activity,
        'What is your blood pressure?',
        'Enter your systolic (SYS) and diastolic (DIA) pressure levels.'
      ),
      (
        LucideIcons.droplet,
        'What is your fasting glucose level?',
        'Enter your blood sugar value (usually measured in the morning).'
      ),
      (
        LucideIcons.footprints,
        'How many steps did you walk today?',
        'Slide to estimate or enter the count from your tracker.'
      ),
      (
        LucideIcons.moon,
        'How many hours of sleep did you get?',
        'Rest is vital to physical and neural recovery.'
      ),
    ];

    final (icon, title, desc) = stepConfig[state.currentStep];

    // If analyzing state
    if (state.isAnalyzing) {
      return const Scaffold(
        body: Center(
          child: AnalysisLoader(text: 'Analyzing your wellness...'),
        ),
      );
    }

    // If completed transition state
    if (state.isCompleted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.check,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Daily check-in complete',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(
                    begin: 0.05,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOut,
                  ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Header & Close Button ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? AppSpacing.giant : AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Check-In',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      Text(
                        'Your guided wellness record',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                  // Exit close button
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    color: AppColors.textSecondary,
                    onPressed: (state.isAnalyzing || state.isCompleted)
                        ? null
                        : () {
                            notifier.reset();
                            context.go('/dashboard');
                          },
                  ),
                ],
              ),
            ),

            const Divider(),

            // ── 2. Progress bar ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? AppSpacing.giant : AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: CheckinProgress(
                currentStep: state.currentStep,
                totalSteps: stepConfig.length,
              ),
            ),

            // ── 3. Question Form Area ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 120.0 : AppSpacing.xl,
                  ),
                  child: SizedBox(
                    width: isDesktop ? 480.0 : double.infinity,
                    child: CheckinCard(
                      step: state.currentStep,
                      icon: icon,
                      title: title,
                      description: desc,
                      errorText: state.validationError,
                      inputWidget: MetricInput(step: state.currentStep),
                    ),
                  ),
                ),
              ),
            ),

            // ── 4. Bottom Navigation Action Buttons ──
            const Divider(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? AppSpacing.giant : AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 480.0 : double.infinity,
                  child: Row(
                    children: [
                      // Back Button (only if step > 0)
                      if (state.currentStep > 0) ...[
                        Expanded(
                          child: AppButton(
                            label: 'Back',
                            isOutlined: true,
                            onPressed: (state.isAnalyzing || state.isCompleted)
                                ? null
                                : notifier.previousStep,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      
                      // Continue / Complete Button
                      Expanded(
                        child: AppButton(
                          label: state.currentStep == stepConfig.length - 1
                              ? 'Complete'
                              : 'Continue',
                          onPressed: (state.isAnalyzing || state.isCompleted)
                              ? null
                              : () {
                                  final syncFailed = ref.read(checkinProvider).syncFailed;
                                  notifier.nextStep(() {
                                    // Reload dashboard state dynamically
                                    ref.read(dashboardProvider.notifier).loadDashboardData();
                                    // Navigate back to Dashboard
                                    context.go('/dashboard');
                                    if (syncFailed) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Daily check-in saved locally (Offline Mode).'),
                                          backgroundColor: AppColors.textSecondary,
                                        ),
                                      );
                                    }
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
