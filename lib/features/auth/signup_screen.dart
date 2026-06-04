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

/// Sign up screen for VitalShield AI.
/// Same calm aesthetic as login, with additional fields.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {

    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final name = email.split('@').first;
    final auth = AuthService();
    
    final success = await auth.signUp(
      name: name,
      email: email,
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      context.go('/onboarding');
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
                      // ── Logo & Title ──
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                      ).animate().fadeIn(duration: 500.ms),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        'Create your account',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      const SizedBox(height: AppSpacing.sm),

                      Text(
                        'Start your wellness journey today',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: AppSpacing.xxxl),

                      // ── Signup Card ──
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
                              hint: 'Create a password',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              prefixIcon: LucideIcons.lock,
                              suffixIcon: _obscurePassword
                                  ? LucideIcons.eye_off
                                  : LucideIcons.eye,
                              onSuffixTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please create a password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                  return 'Password must contain at least one uppercase letter';
                                }
                                if (!RegExp(r'[a-z]').hasMatch(value)) {
                                  return 'Password must contain at least one lowercase letter';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(value)) {
                                  return 'Password must contain at least one number';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppSpacing.xl),

                            AppInput(
                              label: AppStrings.confirmPassword,
                              hint: 'Confirm your password',
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              prefixIcon: LucideIcons.lock,
                              suffixIcon: _obscureConfirm
                                  ? LucideIcons.eye_off
                                  : LucideIcons.eye,
                              onSuffixTap: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            AppButton(
                              label: AppStrings.signUp,
                              onPressed: _handleSignUp,
                              isLoading: _isLoading,
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  child: Text(
                                    AppStrings.orDivider,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.border)),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxl),

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
                                if (context.mounted) {
                                  context.go('/onboarding');
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

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.hasAccount,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              AppStrings.signIn,
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
