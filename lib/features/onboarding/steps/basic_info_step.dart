import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/age_calculator.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_button.dart';
import '../widgets/onboarding_card.dart';

/// Step 1: Basic Info — Name, DOB, Gender
class BasicInfoStep extends StatefulWidget {
  final UserModel userData;
  final ValueChanged<UserModel> onUpdate;
  final VoidCallback onNext;

  const BasicInfoStep({
    super.key,
    required this.userData,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late TextEditingController _nameController;
  String _selectedGender = '';
  DateTime? _selectedDob;
  int? _calculatedAge;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData.name);
    _selectedGender = widget.userData.gender;
    _selectedDob = widget.userData.dob;
    if (_selectedDob != null) {
      _calculatedAge = AgeCalculator.calculateAge(_selectedDob!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _calculatedAge = AgeCalculator.calculateAge(picked);
      });
    }
  }

  bool get _isValid =>
      _nameController.text.isNotEmpty &&
      _selectedDob != null &&
      _selectedGender.isNotEmpty;

  void _handleNext() {
    if (!_isValid) return;

    final age = AgeCalculator.calculateAge(_selectedDob!);
    final category = AgeCalculator.getCategory(age);

    widget.onUpdate(widget.userData.copyWith(
      name: _nameController.text.trim(),
      dob: _selectedDob,
      gender: _selectedGender,
      age: age,
      ageCategory: category.label,
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
            icon: LucideIcons.user,
            title: AppStrings.basicInfo,
            subtitle: 'Tell us a little about yourself',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                AppInput(
                  label: AppStrings.fullName,
                  hint: 'Enter your full name',
                  controller: _nameController,
                  prefixIcon: LucideIcons.user,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Date of Birth
                Text(
                  AppStrings.dateOfBirth,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.inputPaddingH,
                      vertical: AppSpacing.inputPaddingV,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          size: AppSpacing.iconMd,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _selectedDob != null
                                ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'
                                : 'Select your date of birth',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: _selectedDob != null
                                      ? AppColors.textPrimary
                                      : AppColors.textHint,
                                ),
                          ),
                        ),
                        if (_calculatedAge != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              '$_calculatedAge yrs',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Gender
                Text(
                  AppStrings.gender,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _GenderOption(
                      label: AppStrings.male,
                      icon: LucideIcons.user,
                      isSelected: _selectedGender.toLowerCase() == 'male',
                      onTap: () =>
                          setState(() => _selectedGender = 'Male'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _GenderOption(
                      label: AppStrings.female,
                      icon: LucideIcons.user,
                      isSelected: _selectedGender.toLowerCase() == 'female',
                      onTap: () =>
                          setState(() => _selectedGender = 'Female'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _GenderOption(
                      label: AppStrings.other,
                      icon: LucideIcons.user,
                      isSelected: _selectedGender.toLowerCase() == 'other',
                      onTap: () =>
                          setState(() => _selectedGender = 'Other'),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxxl),

                AppButton(
                  label: AppStrings.next,
                  onPressed: _isValid ? _handleNext : null,
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
}

/// Gender selection option chip
class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: AppSpacing.iconMd,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
