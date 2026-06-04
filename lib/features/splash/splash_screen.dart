import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../shared/widgets/animated_gradient_bg.dart';
import '../../services/storage_service.dart';

/// Animated splash screen for VitalShield AI.
/// Logo fade-in, elegant static tagline, thin horizontal progress line.
/// Profile-aware routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    debugPrint('[SplashScreen] Started at: $_startTime');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Defer async calls and routing until after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final minDelay = kIsWeb ? Duration.zero : const Duration(milliseconds: 800);
      
      // Start both storage loading and minimum animation delay in parallel
      final delayFuture = Future.delayed(minDelay);
      
      late final bool isAuthenticated;
      late final List<dynamic> profiles;
      late final String? activeId;
      
      final checkFuture = () async {
        final storage = StorageService();
        isAuthenticated = await storage.isAuthenticated();
        profiles = await storage.getAllProfiles();
        activeId = await storage.getCurrentProfileId();
      }();

      Future.wait([delayFuture, checkFuture]).then((_) async {
        if (mounted) {
          final endTime = DateTime.now();
          final durationMs = endTime.difference(_startTime).inMilliseconds;
          debugPrint('[SplashScreen] Navigation triggered at: $endTime (Total startup duration: ${durationMs}ms)');
          
          if (!isAuthenticated) {
            context.go('/login');
          } else if (profiles.isEmpty) {
            context.go('/onboarding');
          } else {
            if (activeId == null) {
              if (profiles.length == 1) {
                final storage = StorageService();
                await storage.setCurrentProfileId(profiles.first.id!);
                await storage.setLastSelectedProfileId(profiles.first.id!);
                if (mounted) {
                  context.go('/dashboard');
                }
              } else {
                if (mounted) {
                  context.go('/profile-select');
                }
              }
            } else {
              if (mounted) {
                context.go('/dashboard');
              }
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBg(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo with subtle pulse glow ──
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.06 + (_pulseController.value * 0.06),
                          ),
                          blurRadius: 30 + (_pulseController.value * 10),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 800.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: AppSpacing.xxl),

              // ── App Name ──
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.0,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms),

              const SizedBox(height: AppSpacing.md),

              // ── Static Tagline ──
              Text(
                AppStrings.tagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms),

              const SizedBox(height: AppSpacing.giant),

              // ── Sleek thin horizontal progress line ──
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    minHeight: 1.5,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
