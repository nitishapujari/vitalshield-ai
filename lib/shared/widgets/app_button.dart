import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Reusable rounded gradient button for VitalShield AI.
/// Supports loading state, full-width mode, and outlined variant.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool fullWidth;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.fullWidth = true,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.fullWidth ? double.infinity : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.isOutlined
              ? null
              : LinearGradient(
                  colors: isDisabled
                      ? [AppColors.surfaceLight, AppColors.surfaceLight]
                      : [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: widget.isOutlined
              ? Border.all(
                  color: _isHovered ? AppColors.primary : AppColors.border,
                  width: 1,
                )
              : null,
          boxShadow: !widget.isOutlined && _isHovered && !isDisabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            splashColor: AppColors.primaryLight.withValues(alpha: 0.15),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isOutlined
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: AppSpacing.iconMd,
                            color: widget.isOutlined
                                ? AppColors.textPrimary
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          widget.label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: widget.isOutlined
                                        ? AppColors.textPrimary
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
