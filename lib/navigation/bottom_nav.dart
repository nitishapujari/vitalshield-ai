import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/constants/app_strings.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';

/// Bottom navigation for mobile layout.
/// Minimal elevation, semi-floating appearance, subtle styling.
class BottomNav extends ConsumerWidget {
  final String currentPath;

  const BottomNav({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final user = dashboardState.user;
    final isFemale = user?.gender.toLowerCase() == 'female';

    final morePaths = {
      '/journey',
      '/health-overview',
      '/predictions',
      '/wellness',
      '/wellness-rhythm',
      '/simulation',
    };

    final items = [
      _BottomNavItem(
        icon: LucideIcons.layout_dashboard,
        label: AppStrings.dashboard,
        path: '/dashboard',
      ),
      _BottomNavItem(
        icon: LucideIcons.clipboard_check,
        label: 'Check-In',
        path: '/checkin',
      ),
      _BottomNavItem(
        icon: LucideIcons.message_circle,
        label: AppStrings.aiAssistant,
        path: '/ai-assistant',
      ),
      _BottomNavItem(
        icon: LucideIcons.chart_bar,
        label: AppStrings.analytics,
        path: '/analytics',
      ),
      _BottomNavItem(
        icon: LucideIcons.menu,
        label: 'More',
        path: '',
      ),
    ];

    return Container(
      decoration: AppDecorations.bottomNav(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isActive = item.path.isEmpty
                  ? morePaths.contains(currentPath)
                  : currentPath == item.path;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (item.path.isEmpty) {
                      _showMoreBottomSheet(context, isFemale);
                    } else {
                      context.go(item.path);
                    }
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Icon(
                            item.icon,
                            size: AppSpacing.iconMd,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.label,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showMoreBottomSheet(BuildContext context, bool isFemale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'More Options',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          color: AppColors.textMuted,
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: AppSpacing.sm),

                  // Navigation list items
                  _buildSheetItem(
                    context: context,
                    icon: LucideIcons.route,
                    label: AppStrings.healthJourney,
                    path: '/journey',
                  ),
                  _buildSheetItem(
                    context: context,
                    icon: LucideIcons.heart_pulse,
                    label: AppStrings.healthOverview,
                    path: '/health-overview',
                  ),
                  _buildSheetItem(
                    context: context,
                    icon: LucideIcons.brain_circuit,
                    label: AppStrings.predictions,
                    path: '/predictions',
                  ),
                  _buildSheetItem(
                    context: context,
                    icon: LucideIcons.sparkles,
                    label: AppStrings.futureSimulation,
                    path: '/simulation',
                  ),
                  if (isFemale)
                    _buildSheetItem(
                      context: context,
                      icon: LucideIcons.flower_2,
                      label: 'Wellness Rhythm',
                      path: '/wellness-rhythm',
                    ),
                  _buildSheetItem(
                    context: context,
                    icon: LucideIcons.settings,
                    label: AppStrings.wellness,
                    path: '/wellness',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String path,
  }) {
    final isActive = currentPath == path;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            context.go(path);
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: isActive ? AppDecorations.activeNavItem() : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppSpacing.iconMd,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isActive ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ),
                if (isActive) ...[
                  const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ] else ...[
                  const Icon(
                    LucideIcons.chevron_right,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String path;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.path,
  });
}

