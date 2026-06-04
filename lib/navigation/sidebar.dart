import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/constants/app_strings.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';

/// Sidebar navigation for desktop and tablet layouts.
/// Subtle tinted active state, no heavy gradients.
class Sidebar extends ConsumerWidget {
  final String currentPath;
  final bool showWellness;

  const Sidebar({
    super.key,
    required this.currentPath,
    this.showWellness = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final user = dashboardState.user;
    final String userName = user?.name ?? 'User';
    final String userRole = user?.ageCategory ?? 'Wellness Explorer';
    final isFemale = user?.gender.toLowerCase() == 'female';

    // Calculate initials
    String initials = 'VS';
    if (userName.isNotEmpty && userName != 'User') {
      final parts = userName.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: AppDecorations.sidebar(),
      child: Column(
        children: [
          // ── Logo Section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    AppStrings.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Nav Items ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ListView(
                children: [
                  _NavItem(
                    icon: LucideIcons.layout_dashboard,
                    label: AppStrings.dashboard,
                    path: '/dashboard',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.clipboard_check,
                    label: AppStrings.dailyCheckIn,
                    path: '/checkin',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.heart_pulse,
                    label: AppStrings.healthOverview,
                    path: '/health-overview',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.brain_circuit,
                    label: AppStrings.predictions,
                    path: '/predictions',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.message_circle,
                    label: AppStrings.aiAssistant,
                    path: '/ai-assistant',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.settings,
                    label: AppStrings.wellness,
                    path: '/wellness',
                    currentPath: currentPath,
                  ),
                  if (isFemale)
                    _NavItem(
                      icon: LucideIcons.flower_2,
                      label: 'Wellness Rhythm',
                      path: '/wellness-rhythm',
                      currentPath: currentPath,
                    ),
                  _NavItem(
                    icon: LucideIcons.chart_bar,
                    label: AppStrings.analytics,
                    path: '/analytics',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.sparkles,
                    label: AppStrings.futureSimulation,
                    path: '/simulation',
                    currentPath: currentPath,
                  ),
                  _NavItem(
                    icon: LucideIcons.route,
                    label: AppStrings.healthJourney,
                    path: '/journey',
                    currentPath: currentPath,
                  ),
                ],
              ),
            ),
          ),

          // ── User Section (Clickable Switcher) ──
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: InkWell(
              onTap: () => context.go('/profile-select'),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          Text(
                            userRole,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.arrow_left_right,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single navigation item with subtle active state.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  bool get _isActive => widget.currentPath == widget.path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: _isActive
              ? AppDecorations.activeNavItem()
              : BoxDecoration(
                  color: _isHovered
                      ? AppColors.surfaceLight.withValues(alpha: 0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go(widget.path),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: AppSpacing.iconMd,
                      color: _isActive
                          ? AppColors.primary
                          : _isHovered
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _isActive
                                  ? AppColors.primary
                                  : _isHovered
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                              fontWeight: _isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                    if (_isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
