import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'presentation/providers/cycle_provider.dart';
import '../reminders/presentation/providers/reminder_provider.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../../shared/widgets/app_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import 'package:go_router/go_router.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_button.dart';
import '../predictions/presentation/providers/predictions_provider.dart';
import '../analytics/presentation/providers/analytics_provider.dart';
import '../assistant/presentation/providers/assistant_provider.dart';
import '../simulation/presentation/providers/simulation_provider.dart';
import '../journey/presentation/providers/journey_provider.dart';

class WellnessScreen extends ConsumerWidget {
  const WellnessScreen({super.key});

  Future<void> _selectTime(
    BuildContext context,
    int currentHour,
    int currentMinute,
    Function(int, int) onTimeSelected,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.background,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onTimeSelected(picked.hour, picked.minute);
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final cycleState = ref.watch(cycleProvider);
    final reminderState = ref.watch(reminderProvider);
    final isDesktop = Responsive.isDesktop(context);

    final user = dashboardState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.giant : AppSpacing.pageHorizontal,
            vertical: AppSpacing.pageVertical,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Text(
                    'Wellness Preferences',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Personalize your wellness targets, smart reminders, and adaptive observations.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildGeneralPreferences(context, ref, user),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildReminderPreferences(context, ref, reminderState, cycleState.data.isTrackingEnabled),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildAccountSection(context, ref, user),
                ],
              ).animate().fadeIn(duration: 500.ms),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralPreferences(BuildContext context, WidgetRef ref, dynamic user) {
    final trackingEnabled = user?.wellnessTrackingEnabled ?? false;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.settings, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tracking Preferences',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            title: Text(
              'Personalized Insights',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            subtitle: Text(
              'Enable heart rate, sleep consistency, and activity trend adaptations.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
            ),
            value: trackingEnabled,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) async {
              if (user != null) {
                final updatedUser = user.copyWith(wellnessTrackingEnabled: val);
                await StorageService().saveUser(updatedUser);
                ref.read(dashboardProvider.notifier).loadDashboardData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReminderPreferences(
    BuildContext context,
    WidgetRef ref,
    ReminderState state,
    bool isCycleTrackingEnabled,
  ) {
    final settings = state.settings;
    final notifier = ref.read(reminderProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bell, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Smart Reminders',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
              Switch(
                value: !settings.isMuted,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  notifier.toggleMute(!val);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Receive calm, supportive wellness nudges to stay balanced throughout the day.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
          ),
          if (!settings.isMuted) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            // 1. Daily Check-in Reminder
            _buildReminderTimeRow(
              context,
              title: 'Daily Check-in Reminder',
              subtitle: 'Gentle nudge to complete your daily log.',
              isEnabled: settings.checkInEnabled,
              hour: settings.checkInHour,
              minute: settings.checkInMinute,
              onToggle: notifier.toggleCheckIn,
              onSelectTime: notifier.updateCheckInTime,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Hydration Reminder
            _buildReminderIntervalRow(
              context,
              title: 'Hydration Nudges',
              subtitle: 'Mindful suggestions to drink water.',
              isEnabled: settings.hydrationEnabled,
              intervalHours: settings.hydrationIntervalHours,
              minHours: 1,
              maxHours: 6,
              onToggle: notifier.toggleHydration,
              onIntervalChanged: notifier.updateHydrationInterval,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3. Sleep wind-down
            _buildReminderTimeRow(
              context,
              title: 'Sleep Wind-down',
              subtitle: 'Time to prepare for restful sleep.',
              isEnabled: settings.sleepEnabled,
              hour: settings.sleepHour,
              minute: settings.sleepMinute,
              onToggle: notifier.toggleSleep,
              onSelectTime: notifier.updateSleepTime,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 4. Rhythm reminder (if cycle tracking enabled)
            if (isCycleTrackingEnabled) ...[
              _buildReminderTimeRow(
                context,
                title: 'Wellness Rhythm Reminder',
                subtitle: 'Receive a daily notification with your energetic phase guidance.',
                isEnabled: settings.rhythmEnabled,
                hour: settings.rhythmHour,
                minute: settings.rhythmMinute,
                onToggle: notifier.toggleRhythm,
                onSelectTime: notifier.updateRhythmTime,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // 5. Movement reminders
            _buildReminderIntervalRow(
              context,
              title: 'Movement Prompts',
              subtitle: 'A quiet nudge to stand and stretch.',
              isEnabled: settings.movementEnabled,
              intervalHours: settings.movementIntervalHours,
              minHours: 1,
              maxHours: 8,
              onToggle: notifier.toggleMovement,
              onIntervalChanged: notifier.updateMovementInterval,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderTimeRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isEnabled,
    required int hour,
    required int minute,
    required Function(bool) onToggle,
    required Function(int, int) onSelectTime,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (isEnabled) ...[
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => _selectTime(context, hour, minute, onSelectTime),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.clock, size: 12, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatTime(hour, minute),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: isEnabled,
          activeThumbColor: AppColors.primary,
          onChanged: onToggle,
        ),
      ],
    );
  }

  Widget _buildReminderIntervalRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isEnabled,
    required int intervalHours,
    required int minHours,
    required int maxHours,
    required Function(bool) onToggle,
    required Function(int) onIntervalChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (isEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      'Every',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DropdownButton<int>(
                      value: intervalHours,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(LucideIcons.chevron_down, size: 12, color: AppColors.primary),
                      underline: const SizedBox(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      onChanged: (val) {
                        if (val != null) onIntervalChanged(val);
                      },
                      items: List.generate(
                        maxHours - minHours + 1,
                        (index) {
                          final value = minHours + index;
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value hours'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: isEnabled,
          activeThumbColor: AppColors.primary,
          onChanged: onToggle,
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref, dynamic user) {
    final email = (user != null && user.email.isNotEmpty) ? user.email : 'No email associated';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.user, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Logged in as:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (user != null && user.name.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Profile Name:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Switch Profile',
            fullWidth: true,
            icon: LucideIcons.arrow_left_right,
            onPressed: () {
              context.go('/profile-select');
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Logout',
            isOutlined: true,
            fullWidth: true,
            icon: LucideIcons.log_out,
            onPressed: () async {
              final auth = AuthService();
              await auth.signOut();
              
              // Invalidate Riverpod states to clear in-memory state
              ref.invalidate(dashboardProvider);
              ref.invalidate(predictionsProvider);
              ref.invalidate(analyticsProvider);
              ref.invalidate(assistantProvider);
              ref.invalidate(cycleProvider);
              ref.invalidate(simulationProvider);
              ref.invalidate(reminderProvider);
              ref.invalidate(journeyProvider);
              
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

}
