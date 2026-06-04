import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/animated_gradient_bg.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import 'widgets/step_indicator.dart';
import 'steps/basic_info_step.dart';
import 'steps/health_basics_step.dart';
import 'steps/wellness_prefs_step.dart';
import 'steps/setup_complete_step.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../predictions/presentation/providers/predictions_provider.dart';
import '../analytics/presentation/providers/analytics_provider.dart';
import '../assistant/presentation/providers/assistant_provider.dart';
import '../wellness/presentation/providers/cycle_provider.dart';
import '../simulation/presentation/providers/simulation_provider.dart';
import '../reminders/presentation/providers/reminder_provider.dart';

/// Multi-step onboarding host for VitalShield AI.
/// One card at a time, conversational feeling, smooth transitions.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  late PageController _pageController;

  // Onboarding data
  UserModel _userData = const UserModel();

  // Total steps (dynamic based on gender)
  int get _totalSteps => _userData.gender.toLowerCase() == 'female' ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // If not female, skip wellness preferences (step index 2 in 4-step flow)
    int nextStep = _currentStep + 1;

    // In 3-step flow (non-female), steps are: 0, 1, 2 (complete)
    // In 4-step flow (female), steps are: 0, 1, 2 (wellness), 3 (complete)
    if (nextStep >= _totalSteps) {
      // Navigate to dashboard
      context.go('/dashboard');
      return;
    }

    setState(() => _currentStep = nextStep);
    _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep = _currentStep - 1);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateUserData(UserModel data) {
    setState(() => _userData = data);
  }

  List<Widget> _buildSteps() {
    final steps = <Widget>[
      BasicInfoStep(
        userData: _userData,
        onUpdate: _updateUserData,
        onNext: _nextStep,
      ),
      HealthBasicsStep(
        userData: _userData,
        onUpdate: _updateUserData,
        onNext: _nextStep,
        onBack: _previousStep,
      ),
    ];

    if (_userData.gender.toLowerCase() == 'female') {
      steps.add(
        WellnessPrefsStep(
          userData: _userData,
          onUpdate: _updateUserData,
          onNext: _nextStep,
          onBack: _previousStep,
        ),
      );
    }

    steps.add(
      SetupCompleteStep(
        userData: _userData,
        onComplete: () async {
          final storage = StorageService();
          await storage.addProfile(_userData);
          
          final loadedUser = await storage.loadUser();
          if (loadedUser != null) {
            try {
              final apiService = ApiService();
              // Pre-flight check: only call backend if we have a valid auth token
              final token = await apiService.getToken();
              if (token != null && token.isNotEmpty) {
                await apiService.post('/profiles/create', loadedUser.toJson());
                debugPrint('Profile synced to backend successfully.');
              } else {
                debugPrint('Skipping backend profile sync: no auth token available.');
              }
            } catch (e) {
              debugPrint('Failed to sync profile to backend: $e');
            }
          }

          await storage.setOnboardingComplete();
          await storage.setAuthenticated(true);
          
          // Invalidate and refresh Riverpod providers to clear cached stale state
          ref.invalidate(dashboardProvider);
          ref.invalidate(predictionsProvider);
          ref.invalidate(analyticsProvider);
          ref.invalidate(assistantProvider);
          ref.invalidate(cycleProvider);
          ref.invalidate(simulationProvider);
          ref.invalidate(reminderProvider);

          await ref.read(dashboardProvider.notifier).loadDashboardData();
          
          if (mounted) {
            context.go('/dashboard');
          }
        },
      ),
    );

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final steps = _buildSteps();

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // ── Step Indicator ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 120 : AppSpacing.xxl,
                  vertical: AppSpacing.xxl,
                ),
                child: StepIndicator(
                  totalSteps: _totalSteps,
                  currentStep: _currentStep,
                ),
              ),

              // ── Step Content ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: steps,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
