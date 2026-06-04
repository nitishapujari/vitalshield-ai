import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/app_button.dart';

/// Step 4: Setup Complete — personalization animation + ready message.
class SetupCompleteStep extends StatefulWidget {
  final UserModel userData;
  final VoidCallback onComplete;

  const SetupCompleteStep({
    super.key,
    required this.userData,
    required this.onComplete,
  });

  @override
  State<SetupCompleteStep> createState() => _SetupCompleteStepState();
}

class _SetupCompleteStepState extends State<SetupCompleteStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated elegant custom symbol with soft pulse/illumination
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.08),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                              alpha: 0.04 + (_shimmerController.value * 0.04)),
                          blurRadius: 20 + (_shimmerController.value * 8),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _ElegantSetupSymbol(
                        animationValue: _shimmerController.value,
                      ),
                    ),
                  );
                },
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms),

              const SizedBox(height: 40.0),

              Text(
                AppStrings.setupCompleteMessage,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

              const SizedBox(height: 16.0),

              Text(
                AppStrings.setupCompleteDesc,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

              const SizedBox(height: 20.0),

              // User summary (no emoji)
              if (widget.userData.name.isNotEmpty)
                Text(
                  'Welcome, ${widget.userData.name}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

              const SizedBox(height: 80.0),

              SizedBox(
                width: isDesktop ? 280 : double.infinity,
                child: AppButton(
                  label: AppStrings.getStarted,
                  onPressed: widget.onComplete,
                  icon: LucideIcons.arrow_right,
                ),
              ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom elegant symbol representing a shield and vital pulse.
class _ElegantSetupSymbol extends StatelessWidget {
  final double animationValue;

  const _ElegantSetupSymbol({required this.animationValue});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _SetupSymbolPainter(animationValue: animationValue),
    );
  }
}

/// Painter for the elegant shield-curve and pulse symbol.
class _SetupSymbolPainter extends CustomPainter {
  final double animationValue;

  _SetupSymbolPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw minimal shield curve outline
    final shieldPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.secondary,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final shieldPath = Path();
    final shieldW = size.width * 0.8;
    final shieldH = size.height * 0.9;
    
    shieldPath.moveTo(center.dx, center.dy - shieldH / 2);
    // Top right curve
    shieldPath.quadraticBezierTo(
      center.dx + shieldW / 2, center.dy - shieldH / 2,
      center.dx + shieldW / 2, center.dy,
    );
    // Right bottom curve
    shieldPath.quadraticBezierTo(
      center.dx + shieldW / 2, center.dy + shieldH / 4,
      center.dx, center.dy + shieldH / 2,
    );
    // Left bottom curve
    shieldPath.quadraticBezierTo(
      center.dx - shieldW / 2, center.dy + shieldH / 4,
      center.dx - shieldW / 2, center.dy,
    );
    // Top left curve
    shieldPath.quadraticBezierTo(
      center.dx - shieldW / 2, center.dy - shieldH / 2,
      center.dx, center.dy - shieldH / 2,
    );
    canvas.drawPath(shieldPath, shieldPaint);

    // 2. Draw soft pulse line inside the shield (animated slightly)
    final pulsePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.7 + (animationValue * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final pulsePath = Path();
    final pulseW = shieldW * 0.75;
    final startX = center.dx - pulseW / 2;
    
    pulsePath.moveTo(startX, center.dy);
    pulsePath.lineTo(startX + pulseW * 0.2, center.dy);
    pulsePath.lineTo(startX + pulseW * 0.35, center.dy - shieldH * 0.15 * (0.8 + animationValue * 0.4));
    pulsePath.lineTo(startX + pulseW * 0.55, center.dy + shieldH * 0.2 * (0.8 + animationValue * 0.4));
    pulsePath.lineTo(startX + pulseW * 0.7, center.dy - shieldH * 0.08);
    pulsePath.lineTo(startX + pulseW * 0.8, center.dy);
    pulsePath.lineTo(startX + pulseW, center.dy);
    
    canvas.drawPath(pulsePath, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _SetupSymbolPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
