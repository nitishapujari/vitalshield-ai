import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'presentation/providers/dashboard_provider.dart';
import '../checkin/domain/models/daily_checkin_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../services/api_service.dart';

/// Premium, minimal Dashboard for VitalShield AI.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final backendState = ref.watch(backendProvider);
    final isDesktop = Responsive.isDesktop(context);
    final userName = state.user?.name ?? 'Nitisha';

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Ambient Glow Orbs for visual depth ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 350,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // ── Main Content ──
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? AppSpacing.giant : AppSpacing.xl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Header Greeting Section ──
                        _buildHeader(
                          context,
                          userName,
                          state.hasCheckedInToday,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        if (backendState.isOffline)
                          _buildOfflineBanner(context, ref),

                        if (state.latestCheckin == null)
                          // ── 2. Onboarding Empty State ──
                          _buildEmptyState(context, ref)
                        else
                          // ── 3. Filled State (Health Score, Daily Wellness Cards, Insights) ──
                          _buildDashboardContent(context, state, ref),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, bool hasCheckedIn) {
    final todayStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayStr.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Welcome, $name',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here is your daily wellness status.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (hasCheckedIn) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Checked In',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            IconButton(
              icon: const Icon(
                LucideIcons.settings,
                size: 20,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Wellness Preferences',
              onPressed: () => context.go('/wellness'),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.05),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Your Wellness Space is Ready',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'VitalShield AI assists you in tracking and maintaining your health consistency. Complete your first check-in to compute your wellness score, establish baseline metrics, and generate intelligent insights.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    SizedBox(
                      width: 260,
                      child: AppButton(
                        label: 'Start First Check-In',
                        icon: LucideIcons.chevron_right,
                        onPressed: () => context.go('/checkin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Text(
                'What to expect on VitalShield AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildEducationalCard(
                          context,
                          icon: LucideIcons.heart_pulse,
                          color: AppColors.primary,
                          title: 'Daily Wellness Log',
                          description:
                              'Track blood pressure, heart rate, fasting glucose, sleep, and steps in one unified space.',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _buildEducationalCard(
                          context,
                          icon: LucideIcons.brain_circuit,
                          color: AppColors.secondary,
                          title: 'Intelligent Predictions',
                          description:
                              'Calculate wellness scores and observe personalized predictions adjusted for age and gender.',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _buildEducationalCard(
                          context,
                          icon: LucideIcons.trending_up,
                          color: AppColors.accent,
                          title: 'Rhythm & Consistency',
                          description:
                              'Establish healthy routines with custom sleep and activity indices tracking long-term habits.',
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildEducationalCard(
                        context,
                        icon: LucideIcons.heart_pulse,
                        color: AppColors.primary,
                        title: 'Daily Wellness Log',
                        description:
                            'Track blood pressure, heart rate, fasting glucose, sleep, and steps in one unified space.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildEducationalCard(
                        context,
                        icon: LucideIcons.brain_circuit,
                        color: AppColors.secondary,
                        title: 'Intelligent Predictions',
                        description:
                            'Calculate wellness scores and observe personalized predictions adjusted for age and gender.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildEducationalCard(
                        context,
                        icon: LucideIcons.trending_up,
                        color: AppColors.accent,
                        title: 'Rhythm & Consistency',
                        description:
                            'Establish healthy routines with custom sleep and activity indices tracking long-term habits.',
                      ),
                    ],
                  ),
          ],
        )
        .animate()
        .fadeIn(delay: 150.ms, duration: 450.ms)
        .slideY(begin: 0.02, end: 0, duration: 450.ms, curve: Curves.easeOut);
  }

  Widget _buildEducationalCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.06),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    DashboardState state,
    WidgetRef ref,
  ) {
    final isDesktop = Responsive.isDesktop(context);
    final checkin = state.latestCheckin!;
    final formatter = NumberFormat('#,###');
    final isSenior = state.user?.ageCategory == 'Senior' || state.user?.ageCategory == 'Senior Citizen';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid with Score Card & Daily Wellness Cards
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildScoreCard(context, state.healthScore, state.hasCheckedInToday),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    flex: 8,
                    child: _buildWellnessCardsGrid(
                      context,
                      checkin,
                      formatter,
                      isSenior,
                      state.hasCheckedInToday,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildScoreCard(context, state.healthScore, state.hasCheckedInToday),
                  const SizedBox(height: AppSpacing.xl),
                  _buildWellnessCardsGrid(
                    context,
                    checkin,
                    formatter,
                    isSenior,
                    state.hasCheckedInToday,
                  ),
                ],
              ),
        const SizedBox(height: AppSpacing.xl),

        // Primary Dynamic Wellness Insight
        _buildInsightsCard(context, state.primaryInsight, state.hasCheckedInToday),
        const SizedBox(height: AppSpacing.xl),

        // Action banner (if user wants to re-do / update check-in)
        if (!state.hasCheckedInToday)
          _buildPendingBanner(context)
        else
          _buildCheckinAgainButton(context),
      ],
    );
  }

  Widget _buildScoreCard(BuildContext context, int score, bool hasCheckedInToday) {
    String scoreLabel = hasCheckedInToday ? 'Moderate' : 'Pending';
    Color labelColor = hasCheckedInToday
        ? (score >= 85
            ? AppColors.success
            : (score < 65 ? AppColors.error : AppColors.warning))
        : AppColors.textSecondary; // neutral grey

    if (hasCheckedInToday) {
      if (score >= 85) {
        scoreLabel = 'Optimal';
      } else if (score < 65) {
        scoreLabel = 'High Risk';
      }
    }

    return GestureDetector(
      onTap: hasCheckedInToday ? null : () => context.go('/checkin'),
      child: AppCard(
        withGlow: hasCheckedInToday,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Wellness Score',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),

            // Glowing score circle
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: labelColor.withValues(alpha: 0.02),
                    boxShadow: hasCheckedInToday
                        ? [
                            BoxShadow(
                              color: labelColor.withValues(alpha: 0.04),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: hasCheckedInToday ? score / 100.0 : 0.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, _) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: animValue,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceLight,
                        color: hasCheckedInToday ? labelColor : AppColors.border,
                        strokeCap: StrokeCap.round,
                      ),
                    );
                  },
                ),
                if (hasCheckedInToday)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: score.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animValue, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${animValue.toInt()}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  fontSize: 34,
                                  letterSpacing: -1,
                                ),
                          ),
                          Text(
                            'OF 100',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '--',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              fontSize: 34,
                              letterSpacing: -1,
                            ),
                      ),
                      Text(
                        'PENDING',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Score Category Tag
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs + 1,
              ),
              decoration: BoxDecoration(
                color: labelColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: labelColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                scoreLabel.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildWellnessCardsGrid(
    BuildContext context,
    DailyCheckinModel checkin,
    NumberFormat formatter,
    bool isSenior,
    bool hasCheckedInToday,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Dynamically scale aspect ratio to provide more height for cards on narrower screens
        final double aspectRatio = width < 360 ? 1.05 : (width < 400 ? 1.2 : (width < 600 ? 1.3 : 1.5));
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
          children: [
            _InteractiveWellnessCard(
              onTap: hasCheckedInToday ? null : () => context.go('/checkin'),
              child: _buildWellnessCard(
                context: context,
                title: 'Heart Rate',
                value: hasCheckedInToday && checkin.heartRate != null
                    ? '${checkin.heartRate} BPM'
                    : '--',
                icon: LucideIcons.heart,
                status: hasCheckedInToday
                    ? _getHeartRateStatus(checkin.heartRate, isSenior)
                    : MetricStatus.normal,
                hasCheckedInToday: hasCheckedInToday,
              ),
            ),
            _InteractiveWellnessCard(
              onTap: hasCheckedInToday ? null : () => context.go('/checkin'),
              child: _buildWellnessCard(
                context: context,
                title: 'Blood Pressure',
                value: hasCheckedInToday ? checkin.bloodPressureDisplay : '--',
                icon: LucideIcons.activity,
                status: hasCheckedInToday
                    ? _getBloodPressureStatus(
                        checkin.systolic,
                        checkin.diastolic,
                        isSenior,
                      )
                    : MetricStatus.normal,
                hasCheckedInToday: hasCheckedInToday,
              ),
            ),
            _InteractiveWellnessCard(
              onTap: hasCheckedInToday ? null : () => context.go('/checkin'),
              child: _buildWellnessCard(
                context: context,
                title: 'Fasting Glucose',
                value: hasCheckedInToday && checkin.glucose != null
                    ? '${checkin.glucose} mg/dL'
                    : '--',
                icon: LucideIcons.droplet,
                status: hasCheckedInToday
                    ? _getGlucoseStatus(checkin.glucose, isSenior)
                    : MetricStatus.normal,
                hasCheckedInToday: hasCheckedInToday,
              ),
            ),
            _InteractiveWellnessCard(
              onTap: hasCheckedInToday ? null : () => context.go('/checkin'),
              child: _buildDoubleWellnessCard(
                context: context,
                title: 'Sleep & Steps',
                value1: hasCheckedInToday && checkin.sleepHours != null
                    ? '${checkin.sleepHours}h'
                    : '--',
                icon1: LucideIcons.moon,
                status1: hasCheckedInToday
                    ? _getSleepStatus(checkin.sleepHours, isSenior)
                    : MetricStatus.normal,
                value2: hasCheckedInToday && checkin.steps != null
                    ? formatter.format(checkin.steps)
                    : '--',
                icon2: LucideIcons.footprints,
                status2: hasCheckedInToday
                    ? _getStepsStatus(checkin.steps, isSenior)
                    : MetricStatus.normal,
                hasCheckedInToday: hasCheckedInToday,
              ),
            ),
          ],
        );
      },
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildWellnessCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required MetricStatus status,
    bool hasCheckedInToday = true,
  }) {
    final statusColor = hasCheckedInToday ? _getStatusColor(status) : AppColors.textSecondary;
    final statusLabel = hasCheckedInToday ? _getStatusLabel(status) : 'Pending';
    final isSmall = MediaQuery.of(context).size.width < 400;
    final padding = isSmall ? AppSpacing.md : AppSpacing.lg;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.02),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          children: [
            // Soft status color strip at the top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              child: Container(color: statusColor),
            ),
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: (isSmall
                              ? Theme.of(context).textTheme.bodySmall
                              : Theme.of(context).textTheme.titleSmall)
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: isSmall ? 8 : 9,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value,
                              style: (isSmall
                                  ? Theme.of(context).textTheme.titleLarge
                                  : Theme.of(context).textTheme.headlineSmall)
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: -0.5,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!hasCheckedInToday) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Tap to record',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: isSmall ? 8 : 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(isSmall ? AppSpacing.xs : AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasCheckedInToday ? icon : LucideIcons.plus,
                          size: isSmall ? 12 : 16,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleWellnessCard({
    required BuildContext context,
    required String title,
    required String value1,
    required IconData icon1,
    required MetricStatus status1,
    required String value2,
    required IconData icon2,
    required MetricStatus status2,
    bool hasCheckedInToday = true,
  }) {
    final color1 = hasCheckedInToday ? _getStatusColor(status1) : AppColors.textSecondary;
    final label1 = hasCheckedInToday ? _getStatusLabel(status1) : 'Pending';
    final color2 = hasCheckedInToday ? _getStatusColor(status2) : AppColors.textSecondary;
    final label2 = hasCheckedInToday ? _getStatusLabel(status2) : 'Pending';
    final isSmall = MediaQuery.of(context).size.width < 400;
    final padding = isSmall ? AppSpacing.md : AppSpacing.lg;
    final spacing = isSmall ? AppSpacing.xs : AppSpacing.md;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.glowPrimary.withValues(alpha: 0.02),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: (isSmall
                        ? Theme.of(context).textTheme.bodySmall
                        : Theme.of(context).textTheme.titleSmall)
                        ?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!hasCheckedInToday)
                  Text(
                    'Tap to record',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: isSmall ? 8 : 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmall ? AppSpacing.xs : AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: color1.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasCheckedInToday ? icon1 : LucideIcons.plus,
                            size: isSmall ? 12 : 14,
                            color: color1,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                value1,
                                style: (isSmall
                                    ? Theme.of(context).textTheme.titleSmall
                                    : Theme.of(context).textTheme.titleMedium)
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: color1,
                                      letterSpacing: -0.3,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color1,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      isSmall ? 'Sleep' : 'Sleep ($label1)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.border,
                    margin: EdgeInsets.symmetric(
                      horizontal: spacing,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmall ? AppSpacing.xs : AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: color2.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasCheckedInToday ? icon2 : LucideIcons.plus,
                            size: isSmall ? 12 : 14,
                            color: color2,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                value2,
                                style: (isSmall
                                    ? Theme.of(context).textTheme.titleSmall
                                    : Theme.of(context).textTheme.titleMedium)
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: color2,
                                      letterSpacing: -0.3,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color2,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      isSmall ? 'Steps' : 'Steps ($label2)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MetricStatus _getHeartRateStatus(int? hr, bool isSenior) {
    if (hr == null) return MetricStatus.normal;
    final normalMin = isSenior ? 55 : 60;
    final normalMax = isSenior ? 90 : 85;

    if (hr >= normalMin && hr <= normalMax) {
      return MetricStatus.normal;
    }
    if (hr < 50 || hr > 105) {
      return MetricStatus.high;
    }
    return MetricStatus.moderate;
  }

  MetricStatus _getBloodPressureStatus(int? sys, int? dia, bool isSenior) {
    if (sys == null || dia == null) return MetricStatus.normal;
    if (sys < 90 || dia < 60 || sys >= 140 || dia >= 90) {
      return MetricStatus.high;
    }
    if (sys > 120 || dia > 80) {
      return MetricStatus.moderate;
    }
    return MetricStatus.normal;
  }

  MetricStatus _getGlucoseStatus(double? glu, bool isSenior) {
    if (glu == null) return MetricStatus.normal;
    if (glu < 70 || glu >= 126) {
      return MetricStatus.high;
    }
    if (glu >= 100) {
      return MetricStatus.moderate;
    }
    return MetricStatus.normal;
  }

  MetricStatus _getSleepStatus(double? sleep, bool isSenior) {
    if (sleep == null) return MetricStatus.normal;
    final optimalMin = isSenior ? 6.5 : 7.0;
    final optimalMax = isSenior ? 8.5 : 9.0;

    if (sleep >= optimalMin && sleep <= optimalMax) {
      return MetricStatus.normal;
    }

    final criticalMin = isSenior ? 5.5 : 6.0;
    final criticalMax = isSenior ? 9.5 : 10.0;

    if (sleep < criticalMin || sleep > criticalMax) {
      return MetricStatus.high;
    }
    return MetricStatus.moderate;
  }

  MetricStatus _getStepsStatus(int? steps, bool isSenior) {
    if (steps == null) return MetricStatus.normal;
    final optimalMin = isSenior ? 6000 : 8000;
    if (steps >= optimalMin) {
      return MetricStatus.normal;
    }
    final criticalMin = isSenior ? 3000 : 4000;
    if (steps < criticalMin) {
      return MetricStatus.high;
    }
    return MetricStatus.moderate;
  }

  Color _getStatusColor(MetricStatus status) {
    switch (status) {
      case MetricStatus.normal:
        return AppColors.success;
      case MetricStatus.moderate:
        return AppColors.warning;
      case MetricStatus.high:
        return AppColors.error;
    }
  }

  String _getStatusLabel(MetricStatus status) {
    switch (status) {
      case MetricStatus.normal:
        return 'Normal';
      case MetricStatus.moderate:
        return 'Moderate';
      case MetricStatus.high:
        return 'High';
    }
  }

  Widget _buildInsightsCard(BuildContext context, String primaryInsight, bool hasCheckedInToday) {
    final displayInsight = hasCheckedInToday
        ? primaryInsight
        : "Complete today's check-in to generate updated insights and compute your wellness score.";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg + 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 14,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'AI Wellness Insight',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    displayInsight,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _buildPendingBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(color: AppColors.primary),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Check-In Pending',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Sync your metrics to update your wellness score.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 140,
                    child: AppButton(
                      label: 'Check-In',
                      onPressed: () => context.go('/checkin'),
                      height: 40,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildCheckinAgainButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        icon: const Icon(LucideIcons.refresh_cw, size: 14),
        label: const Text('Update Daily Check-In'),
        onPressed: () => context.go('/checkin'),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildOfflineBanner(BuildContext context, WidgetRef ref) {
    final backendState = ref.watch(backendProvider);
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.wifi_off,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Using local wellness estimation while reconnecting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                onPressed: backendState.isCheckingHealth
                    ? null
                    : () async {
                        await ref.read(backendProvider.notifier).checkHealth();
                        await ref.read(dashboardProvider.notifier).loadDashboardData();
                      },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: backendState.isCheckingHealth
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.05, end: 0, curve: Curves.easeOut);
  }
}

/// Interactive wellness card with hover scale animation for desktop.
class _InteractiveWellnessCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveWellnessCard({required this.child, this.onTap});

  @override
  State<_InteractiveWellnessCard> createState() =>
      _InteractiveWellnessCardState();
}

class _InteractiveWellnessCardState extends State<_InteractiveWellnessCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

enum MetricStatus { normal, moderate, high }
