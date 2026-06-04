import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/age_calculator.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';

import '../../shared/widgets/animated_gradient_bg.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_input.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../predictions/presentation/providers/predictions_provider.dart';
import '../analytics/presentation/providers/analytics_provider.dart';
import '../assistant/presentation/providers/assistant_provider.dart';
import '../wellness/presentation/providers/cycle_provider.dart';
import '../simulation/presentation/providers/simulation_provider.dart';
import '../reminders/presentation/providers/reminder_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final String? profileId;

  const ProfileEditScreen({super.key, this.profileId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final StorageService _storage = StorageService();
  final _formKey = GlobalKey<FormState>();

  late UserModel _profileToEdit;
  bool _isLoading = true;

  // Form Fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  DateTime? _selectedDob;
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Moderately Active';
  bool _wellnessTrackingEnabled = false;
  String _heightUnit = 'cm';

  @override
  void initState() {
    super.initState();
    _heightController.addListener(_onHeightWeightChanged);
    _weightController.addListener(_onHeightWeightChanged);
    _loadProfileData();
  }

  void _onHeightWeightChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    
    UserModel? targetProfile;
    final id = widget.profileId;
    
    if (id != null && id.isNotEmpty) {
      final profiles = await _storage.getAllProfiles();
      final index = profiles.indexWhere((p) => p.id == id);
      if (index != -1) {
        targetProfile = profiles[index];
      }
    }
    
    // Fallback to active user if no specific ID or not found
    targetProfile ??= await _storage.loadUser();
    
    // Default fallback if still null
    targetProfile ??= const UserModel(
      name: '',
      email: '',
      gender: 'Male',
      activityLevel: 'Moderately Active',
    );

    _profileToEdit = targetProfile;
    
    // Populate form
    _nameController.text = _profileToEdit.name;
    _emailController.text = _profileToEdit.email;
    
    _heightUnit = (_profileToEdit.heightUnit == 'in') ? 'in' : 'cm';
    if (_profileToEdit.height != null) {
      if (_heightUnit == 'in') {
        final double roundedInches = double.parse((_profileToEdit.height! / 2.54).toStringAsFixed(1));
        _heightController.text = roundedInches == roundedInches.roundToDouble() 
            ? roundedInches.round().toString() 
            : roundedInches.toString();
      } else {
        final double roundedCm = double.parse(_profileToEdit.height!.toStringAsFixed(1));
        _heightController.text = roundedCm == roundedCm.roundToDouble()
            ? roundedCm.round().toString()
            : roundedCm.toString();
      }
    } else {
      _heightController.text = '';
    }

    _weightController.text = _profileToEdit.weight?.toString() ?? '';
    _selectedDob = _profileToEdit.dob;
    
    // Normalize gender context safely
    final rawGender = _profileToEdit.gender.trim().toLowerCase();
    if (rawGender == 'female') {
      _selectedGender = 'Female';
    } else if (rawGender == 'other') {
      _selectedGender = 'Other';
    } else {
      _selectedGender = 'Male';
    }

    // Normalize activity level safely to match dropdown options
    final rawActivity = _profileToEdit.activityLevel;
    if (rawActivity == 'Light') {
      _selectedActivityLevel = 'Lightly Active';
    } else if (rawActivity == 'Moderate') {
      _selectedActivityLevel = 'Moderately Active';
    } else if (rawActivity == 'Active') {
      _selectedActivityLevel = 'Very Active';
    } else if (rawActivity == 'Sedentary') {
      _selectedActivityLevel = 'Sedentary';
    } else if (rawActivity != null && [
      'Sedentary',
      'Lightly Active',
      'Moderately Active',
      'Very Active'
    ].contains(rawActivity)) {
      _selectedActivityLevel = rawActivity;
    } else {
      _selectedActivityLevel = 'Moderately Active';
    }

    _wellnessTrackingEnabled = _profileToEdit.wellnessTrackingEnabled;

    setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    var height = double.tryParse(_heightController.text);
    if (height != null && _heightUnit == 'in') {
      height = height * 2.54;
    }
    final weight = double.tryParse(_weightController.text);
    
    // Recalculate computed fields
    final age = AgeCalculator.calculateAge(_selectedDob!);
    final ageCat = AgeCalculator.getCategory(age).label;
    final bmi = (height != null && weight != null) 
        ? AgeCalculator.calculateBMI(height, weight)
        : null;

    final updatedUser = _profileToEdit.copyWith(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      dob: _selectedDob,
      gender: _selectedGender,
      height: height,
      weight: weight,
      bmi: bmi,
      activityLevel: _selectedActivityLevel,
      wellnessTrackingEnabled: _wellnessTrackingEnabled,
      age: age,
      ageCategory: ageCat,
      heightUnit: _heightUnit,
    );

    await _storage.updateProfile(updatedUser);

    // Sync to backend database
    try {
      final apiService = ApiService();
      await apiService.put('/profiles/update', updatedUser.toJson());
      debugPrint('Successfully synchronized profile update to backend.');
    } catch (e) {
      debugPrint('Failed to synchronize profile update to backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated locally (Offline Mode).'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    }


    // If we edited the CURRENT active profile, refresh the active state
    final activeId = await _storage.getCurrentProfileId();
    if (activeId == updatedUser.id) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(predictionsProvider);
      ref.invalidate(analyticsProvider);
      ref.invalidate(assistantProvider);
      ref.invalidate(cycleProvider);
      ref.invalidate(simulationProvider);
      ref.invalidate(reminderProvider);

      await ref.read(dashboardProvider.notifier).loadDashboardData();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 60.0 : AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        decoration: AppDecorations.card(
                          color: AppColors.surface,
                          radius: AppSpacing.radiusXl,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.arrow_left, color: Colors.white),
                                    onPressed: () => context.pop(),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Edit Profile',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Padding(
                                padding: const EdgeInsets.only(left: 48.0),
                                child: Text(
                                  'Refine details to tailor your companion.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 32.0),

                              // Name
                              AppInput(
                                label: 'Full Name',
                                hint: 'e.g. Nitisha Pujari',
                                controller: _nameController,
                                prefixIcon: LucideIcons.user,
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                              ),
                              const SizedBox(height: 20.0),

                              // Email
                              AppInput(
                                label: 'Email Address (Optional)',
                                hint: 'e.g. nitisha@vitalshield.ai',
                                controller: _emailController,
                                prefixIcon: LucideIcons.mail,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20.0),

                              // DOB Date Picker
                              Text(
                                'Date of Birth',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              InkWell(
                                onTap: () => _selectDate(context),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                  decoration: AppDecorations.input(),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.calendar, color: AppColors.textMuted, size: 20),
                                      const SizedBox(width: 12.0),
                                      Text(
                                        _selectedDob == null
                                            ? 'Select Date'
                                            : DateFormat('MMMM dd, yyyy').format(_selectedDob!),
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: _selectedDob == null
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_selectedDob != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(LucideIcons.sparkles, size: 12, color: AppColors.primaryLight),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            '${AgeCalculator.getCategory(AgeCalculator.calculateAge(_selectedDob!)).label} (Age ${AgeCalculator.calculateAge(_selectedDob!)})',
                                            style: const TextStyle(
                                              color: AppColors.primaryLight,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20.0),

                              // Gender Choice Cards
                              Text(
                                'Gender Context',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: ['Male', 'Female', 'Other'].map((g) {
                                  final isSel = _selectedGender == g;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedGender = g),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          decoration: AppDecorations.card(
                                            color: isSel ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight,
                                            radius: AppSpacing.radiusMd,
                                            withBorder: true,
                                          ).copyWith(
                                            border: Border.all(
                                              color: isSel ? AppColors.primary : AppColors.border,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              g,
                                              style: TextStyle(
                                                color: isSel ? Colors.white : AppColors.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20.0),

                              // Height & Weight Rows
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AppInput(
                                          label: 'Height',
                                          hint: _heightUnit == 'cm' ? '175' : '67',
                                          controller: _heightController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          prefixIcon: LucideIcons.ruler,
                                        ),
                                        if (_heightUnit == 'in') ...[
                                          const SizedBox(height: 4.0),
                                          Builder(
                                            builder: (context) {
                                              final double? hVal = double.tryParse(_heightController.text);
                                              if (hVal != null && hVal > 0) {
                                                final totalInches = hVal.round();
                                                final feet = totalInches ~/ 12;
                                                final inches = totalInches % 12;
                                                return Text(
                                                  "Equivalent to $feet' $inches\"",
                                                  style: const TextStyle(
                                                    color: AppColors.primaryLight,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unit',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _heightUnit,
                                              dropdownColor: AppColors.surface,
                                              isExpanded: true,
                                              style: const TextStyle(color: Colors.white, fontSize: 15),
                                              icon: const Icon(
                                                LucideIcons.chevron_down,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 'cm', child: Text('cm')),
                                                DropdownMenuItem(value: 'in', child: Text('in')),
                                              ],
                                              onChanged: (val) {
                                                if (val != null && val != _heightUnit) {
                                                  final double? currentVal = double.tryParse(_heightController.text);
                                                  setState(() {
                                                    _heightUnit = val;
                                                    if (currentVal != null) {
                                                      if (val == 'cm') {
                                                        // Convert from inches to cm
                                                        final converted = (currentVal * 2.54).roundToDouble();
                                                        _heightController.text = converted == converted.roundToDouble()
                                                            ? converted.round().toString()
                                                            : converted.toString();
                                                      } else {
                                                        // Convert from cm to inches
                                                        final converted = (currentVal / 2.54).roundToDouble();
                                                        _heightController.text = converted == converted.roundToDouble()
                                                            ? converted.round().toString()
                                                            : converted.toString();
                                                      }
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    flex: 4,
                                    child: AppInput(
                                      label: 'Weight (kg)',
                                      hint: '70',
                                      controller: _weightController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      prefixIcon: LucideIcons.scale,
                                    ),
                                  ),
                                ],
                              ),
                              // Dynamic BMI Display
                              () {
                                var height = double.tryParse(_heightController.text);
                                if (height != null && _heightUnit == 'in') {
                                  height = height * 2.54;
                                }
                                final weight = double.tryParse(_weightController.text);
                                if (height == null || weight == null || height <= 0 || weight <= 0) {
                                  return const SizedBox.shrink();
                                }
                                final bmi = AgeCalculator.calculateBMI(height, weight);
                                final bmiCat = AgeCalculator.bmiCategory(bmi);
                                final bmiDesc = AgeCalculator.bmiDescription(bmi);
                                final catColor = bmi < 18.5
                                    ? AppColors.warning
                                    : (bmi < 25
                                        ? AppColors.success
                                        : (bmi < 30 ? AppColors.warning : AppColors.error));
                                
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 20.0),
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                                bmi.toStringAsFixed(1),
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
                                                  color: catColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                                ),
                                                child: Text(
                                                  bmiCat,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: catColor,
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
                                        bmiDesc,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }(),
                              const SizedBox(height: 20.0),

                              // Activity Level Choice
                              Text(
                                'Activity Level',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedActivityLevel,
                                dropdownColor: AppColors.surface,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                                items: [
                                  'Sedentary',
                                  'Lightly Active',
                                  'Moderately Active',
                                  'Very Active',
                                ].map((act) {
                                  return DropdownMenuItem<String>(
                                    value: act,
                                    child: Text(act),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedActivityLevel = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 24.0),

                              // Wellness Cycle Tracking Enable (Female only or available to toggles)
                              SwitchListTile(
                                activeThumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                                inactiveThumbColor: AppColors.textSecondary,
                                inactiveTrackColor: AppColors.surfaceLight,
                                title: const Text(
                                  'Wellness Cycle Tracking',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Enables adaptive wellness tracking specialized context.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                value: _wellnessTrackingEnabled,
                                onChanged: (val) {
                                  setState(() => _wellnessTrackingEnabled = val);
                                },
                              ),
                              const SizedBox(height: 40.0),

                              // Save Button
                              AppButton(
                                label: 'Save Changes',
                                onPressed: _saveProfile,
                                icon: LucideIcons.save,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
