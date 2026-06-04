import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../widgets/onboarding_card.dart';

class WellnessPrefsStep extends StatefulWidget {
  final UserModel userData;
  final ValueChanged<UserModel> onUpdate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const WellnessPrefsStep({
    super.key,
    required this.userData,
    required this.onUpdate,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<WellnessPrefsStep> createState() => _WellnessPrefsStepState();
}

class _WellnessPrefsStepState extends State<WellnessPrefsStep> {
  bool _wellnessEnabled = false;

  @override
  void initState() {
    super.initState();
    _wellnessEnabled = widget.userData.wellnessTrackingEnabled;
  }

  void _handleNext() {
    widget.onUpdate(widget.userData.copyWith(
      wellnessTrackingEnabled: _wellnessEnabled,
    ));
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 120 : AppSpacing.xxl,
        ),
        child: SizedBox(
          width: isDesktop ? 480 : double.infinity,
          child: OnboardingCard(
            icon: LucideIcons.flower_2,
            title: AppStrings.wellnessPreferences,
            subtitle: 'Personalize your wellness experience',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _wellnessEnabled = !_wellnessEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: _wellnessEnabled
                          ? AppColors.secondary.withValues(alpha: 0.08)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: _wellnessEnabled
                            ? AppColors.secondary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: _wellnessEnabled
                                ? AppColors.secondary.withValues(alpha: 0.15)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(LucideIcons.flower_2, size: 24,
                            color: _wellnessEnabled ? AppColors.secondary : AppColors.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppStrings.enableWellnessTracking,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(AppStrings.wellnessTrackingDesc,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _wellnessEnabled,
                          onChanged: (v) => setState(() => _wellnessEnabled = v),
                          activeThumbColor: AppColors.secondary,
                          activeTrackColor: AppColors.secondary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_wellnessEnabled) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What\'s included:', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppSpacing.md),
                        ...[
                          (LucideIcons.calendar_days, 'Cycle timeline tracking'),
                          (LucideIcons.smile, 'Mood & energy patterns'),
                          (LucideIcons.sparkles, 'Personalized wellness insights'),
                          (LucideIcons.heart, 'Gentle suggestions'),
                        ].map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(children: [
                            Icon(item.$1, size: 14, color: AppColors.secondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(item.$2, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary)),
                          ]),
                        )),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                Row(children: [
                  Expanded(child: AppButton(label: AppStrings.back, onPressed: widget.onBack, isOutlined: true)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: AppButton(label: AppStrings.next, onPressed: _handleNext)),
                ]),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOut),
        ),
      ),
    );
  }
}
