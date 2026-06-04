import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Reassuring loading animation showing a soft breathing opacity fade.
/// Free of heavy futuristic scanner effects or flashing rings.
class AnalysisLoader extends StatefulWidget {
  final String text;

  const AnalysisLoader({
    super.key,
    this.text = 'Analyzing your wellness...',
  });

  @override
  State<AnalysisLoader> createState() => _AnalysisLoaderState();
}

class _AnalysisLoaderState extends State<AnalysisLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo symbol with breathing opacity
          FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // Calming analysis message
          FadeTransition(
            opacity: _opacityAnimation,
            child: Text(
              widget.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
