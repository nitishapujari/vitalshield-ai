import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/age_calculator.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_slider.dart';
import '../widgets/onboarding_card.dart';

/// Step 2: Health Basics — Height, Weight, Activity Level, Auto-BMI
class HealthBasicsStep extends StatefulWidget {
  final UserModel userData;
  final ValueChanged<UserModel> onUpdate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const HealthBasicsStep({
    super.key,
    required this.userData,
    required this.onUpdate,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<HealthBasicsStep> createState() => _HealthBasicsStepState();
}

class _HealthBasicsStepState extends State<HealthBasicsStep> {
  double _height = 170;
  double _weight = 65;
  String _activityLevel = 'Moderate';
  String _heightUnit = 'cm';

  @override
  void initState() {
    super.initState();
    _height = widget.userData.height ?? 170;
    _weight = widget.userData.weight ?? 65;
    _activityLevel = widget.userData.activityLevel ?? 'Moderate';
    _heightUnit = widget.userData.heightUnit;
    if (_heightUnit == 'in') {
      _height = (_height / 2.54).roundToDouble() * 2.54;
    }
  }

  double get _bmi => AgeCalculator.calculateBMI(_height, _weight);
  String get _bmiCategory => AgeCalculator.bmiCategory(_bmi);
  String get _bmiDescription => AgeCalculator.bmiDescription(_bmi);

  String _formatHeight() {
    if (_heightUnit == 'cm') {
      return '${_height.round()} cm';
    } else {
      final totalInches = (_height / 2.54).round();
      final feet = totalInches ~/ 12;
      final inches = totalInches % 12;
      return "$feet' $inches\" ($totalInches in)";
    }
  }

  void _handleNext() {
    widget.onUpdate(widget.userData.copyWith(
      height: _height,
      weight: _weight,
      bmi: _bmi,
      activityLevel: _activityLevel,
      heightUnit: _heightUnit,
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
            icon: LucideIcons.activity,
            title: AppStrings.healthBasics,
            subtitle: 'Help us understand your wellness baseline',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Height slider with unit selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.height,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatHeight(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButtonHideUnderline(
                          child: SizedBox(
                            height: 24,
                            child: DropdownButton<String>(
                              value: _heightUnit,
                              dropdownColor: AppColors.surface,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                              icon: const Icon(
                                LucideIcons.chevron_down,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'cm', child: Text('cm')),
                                DropdownMenuItem(value: 'in', child: Text('in')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _heightUnit = v;
                                    if (_heightUnit == 'cm') {
                                      _height = _height.roundToDouble();
                                    } else {
                                      _height = (_height / 2.54).roundToDouble() * 2.54;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceLight,
                    thumbColor: AppColors.primaryLight,
                    overlayColor: AppColors.primary.withValues(alpha: 0.08),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _heightUnit == 'cm' 
                        ? _height.clamp(100.0, 250.0) 
                        : (_height / 2.54).clamp(40.0, 95.0),
                    min: _heightUnit == 'cm' ? 100 : 40,
                    max: _heightUnit == 'cm' ? 250 : 95,
                    divisions: _heightUnit == 'cm' ? 150 : 55,
                    onChanged: (v) {
                      setState(() {
                        if (_heightUnit == 'cm') {
                          _height = v;
                        } else {
                          _height = v * 2.54;
                        }
                      });
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Weight slider
                AppSlider(
                  label: AppStrings.weight,
                  value: _weight,
                  min: 30,
                  max: 200,
                  divisions: 170,
                  unit: 'kg',
                  onChanged: (v) => setState(() => _weight = v),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // BMI Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BMI',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          Row(
                            children: [
                              Text(
                                _bmi.toStringAsFixed(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: _bmiCategoryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull),
                                ),
                                child: Text(
                                  _bmiCategory,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: _bmiCategoryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _bmiDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Activity Level
                Text(
                  AppStrings.activityLevel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppStrings.sedentary,
                    AppStrings.light,
                    AppStrings.moderate,
                    AppStrings.active,
                  ].map((level) {
                    final isSelected = _activityLevel == level;
                    return GestureDetector(
                      onTap: () => setState(() => _activityLevel = level),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceLight,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          level,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Navigation buttons
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: AppStrings.back,
                        onPressed: widget.onBack,
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: AppStrings.next,
                        onPressed: _handleNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideX(
                begin: 0.05,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOut,
              ),
        ),
      ),
    );
  }

  Color get _bmiCategoryColor {
    if (_bmi < 18.5) return AppColors.warning;
    if (_bmi < 25) return AppColors.success;
    if (_bmi < 30) return AppColors.warning;
    return AppColors.error;
  }
}
