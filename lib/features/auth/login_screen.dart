import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/animated_gradient_bg.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_input.dart';
import '../../shared/widgets/app_card.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

/// Login screen for VitalShield AI.
/// Centered card layout with animated gradient background.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = AuthService();
    final success = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final storage = StorageService();
    final profiles = await storage.getAllProfiles();

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please check your credentials.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (profiles.isEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'No Profile Found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'No profile is associated with this account. Please register your profile to get started.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/onboarding');
                },
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        await storage.clearCurrentProfileId();
        if (profiles.length == 1) {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final cardWidth = isDesktop ? 420.0 : double.infinity;

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 0 : AppSpacing.xxl,
                vertical: AppSpacing.xxxl,
              ),
              child: SizedBox(
                width: cardWidth,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo & App Name ──
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                          ),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        AppStrings.appName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      const SizedBox(height: AppSpacing.sm),

                      Text(
                        'Your intelligent wellness companion',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: AppSpacing.xxxl),

                      // ── Login Card ──
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppInput(
                              label: AppStrings.email,
                              hint: 'Enter your email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: LucideIcons.mail,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppSpacing.xl),

                            AppInput(
                              label: AppStrings.password,
                              hint: 'Enter your password',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              prefixIcon: LucideIcons.lock,
                              suffixIcon: _obscurePassword
                                  ? LucideIcons.eye_off
                                  : LucideIcons.eye,
                              onSuffixTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  AppStrings.forgotPassword,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.xl),

                            // Sign In button
                            AppButton(
                              label: AppStrings.signIn,
                              onPressed: _handleSignIn,
                              isLoading: _isLoading,
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.border,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  child: Text(
                                    AppStrings.orDivider,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.border,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            // Google Sign In
                            AppButton(
                              label: AppStrings.continueWithGoogle,
                              onPressed: () async {
                                String token = 'token_user_1_mockgoogle';
                                String email = 'google_user@vitalshield.ai';
                                try {
                                  final response = await ApiService().post('/auth/google_mock', {});
                                  if (response != null) {
                                    if (response['token'] != null) {
                                      token = response['token'] as String;
                                    }
                                    if (response['email'] != null) {
                                      email = response['email'] as String;
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Google mock backend request failed, using offline fallback: $e');
                                }
                                
                                await ApiService().setToken(token);
                                final storage = StorageService();
                                await storage.setAuthenticated(true);
                                await storage.setLoggedInEmail(email);
                                final profiles = await storage.getAllProfiles();
                                if (context.mounted) {
                                  if (profiles.isEmpty) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        title: const Text(
                                          'No Profile Found',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: const Text(
                                          'No profile is associated with this account. Please register your profile to get started.',
                                          style: TextStyle(color: AppColors.textSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                              context.go('/onboarding');
                                            },
                                            child: const Text(
                                              'Register',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    await storage.clearCurrentProfileId();
                                    if (profiles.length == 1) {
                                      await storage.setCurrentProfileId(profiles.first.id!);
                                      await storage.setLastSelectedProfileId(profiles.first.id!);
                                      if (context.mounted) {
                                        context.go('/dashboard');
                                      }
                                    } else {
                                      if (context.mounted) {
                                        context.go('/profile-select');
                                      }
                                    }
                                  }
                                }
                              },
                              isOutlined: true,
                              icon: LucideIcons.globe,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                            begin: 0.05,
                            end: 0,
                            duration: 500.ms,
                            curve: Curves.easeOut,
                          ),

                      const SizedBox(height: AppSpacing.xxl),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.noAccount,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/signup'),
                            child: Text(
                              AppStrings.signUp,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
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
}
