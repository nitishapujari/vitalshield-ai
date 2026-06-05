import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/utils/responsive.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/app_button.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/animated_gradient_bg.dart';
import '../dashboard/presentation/providers/dashboard_provider.dart';
import '../predictions/presentation/providers/predictions_provider.dart';
import '../analytics/presentation/providers/analytics_provider.dart';
import '../assistant/presentation/providers/assistant_provider.dart';
import '../wellness/presentation/providers/cycle_provider.dart';
import '../simulation/presentation/providers/simulation_provider.dart';
import '../reminders/presentation/providers/reminder_provider.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen> {
  final StorageService _storage = StorageService();
  List<UserModel> _profiles = [];
  String? _activeProfileId;
  UserModel? _lastSelectedProfile;
  bool _isLoading = true;
  bool _hasError = false;

  static const List<LinearGradient> _avatarGradients = [
    LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFFA78BFA), Color(0xFFC4B5FD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF67E8F9), Color(0xFF4DD0E1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF34D399), Color(0xFF6EE7B7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final profiles = await _storage.getAllProfiles();
      final activeId = await _storage.getCurrentProfileId();
      final lastSelectedId = await _storage.getLastSelectedProfileId();
      
      UserModel? lastSelected;
      if (lastSelectedId != null) {
        final index = profiles.indexWhere((p) => p.id == lastSelectedId);
        if (index != -1) {
          lastSelected = profiles[index];
        }
      }
      
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeId;
        _lastSelectedProfile = lastSelected;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profiles: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profiles. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'VS';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  LinearGradient _getGradient(String id) {
    final hash = id.hashCode;
    return _avatarGradients[hash.abs() % _avatarGradients.length];
  }

  Future<void> _selectProfile(UserModel profile) async {
    if (profile.id == null) return;
    await _storage.setCurrentProfileId(profile.id!);
    await _storage.setLastSelectedProfileId(profile.id!);
    
    // Invalidate and refresh Riverpod providers to clear cached stale state
    ref.invalidate(dashboardProvider);
    ref.invalidate(predictionsProvider);
    ref.invalidate(analyticsProvider);
    ref.invalidate(assistantProvider);
    ref.invalidate(cycleProvider);
    ref.invalidate(simulationProvider);
    ref.invalidate(reminderProvider);
    
    ref.read(dashboardProvider.notifier).loadDashboardData();
    
    if (mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _deleteProfile(UserModel profile) async {
    if (profile.id == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Delete Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        content: Text(
          'Are you sure you want to delete ${profile.name}? This will permanently remove all local health checkins, predictions, and history associated with this profile.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ApiService();
        final token = await apiService.getToken();
        if (token != null && token.isNotEmpty) {
          await apiService.delete('/profiles/${profile.id}');
          debugPrint('Profile deleted from backend database.');
        }
      } catch (e) {
        debugPrint('Failed to delete profile from backend: $e');
      }
      await _storage.deleteProfile(profile.id!);
      await _loadProfiles();
      
      // If no profiles left, GoRouter should navigate to onboarding
      if (_profiles.isEmpty) {
        if (mounted) {
          context.go('/onboarding');
        }
      } else {
        // Invalidate and refresh active user state
        ref.invalidate(dashboardProvider);
        ref.invalidate(predictionsProvider);
        ref.invalidate(analyticsProvider);
        ref.invalidate(assistantProvider);
        ref.invalidate(cycleProvider);
        ref.invalidate(simulationProvider);
        ref.invalidate(reminderProvider);
        
        await ref.read(dashboardProvider.notifier).loadDashboardData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.shield_alert, color: AppColors.error, size: 48),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Failed to load profiles',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'There was an error reading your local user profiles.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          width: 160,
                          child: AppButton(
                            label: 'Retry',
                            onPressed: _loadProfiles,
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 60.0 : AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1000 : 500,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Logo and Tagline ──
                          Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                          const SizedBox(height: 12.0),
                          Text(
                            'VitalShield AI',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                          const SizedBox(height: 8.0),
                          Text(
                            'Your Intelligent Wellness Companion',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.2,
                                ),
                          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                          const SizedBox(height: 48.0),

                          // ── Title ──
                          Text(
                            'Who is tracking wellness today?',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                          const SizedBox(height: 32.0),

                          // ── Continue As Shortcut Card ──
                          _buildContinueAsShortcut(context),

                          // ── Responsive Profiles Grid / List ──
                          isDesktop
                              ? _buildGrid(context, crossAxisCount: 3)
                              : _buildList(context),

                          const SizedBox(height: 40.0),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, {required int crossAxisCount}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 0.85,
      ),
      itemCount: _profiles.length + 1,
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          return _buildAddProfileCard(context, isGrid: true);
        }
        return _buildProfileCard(context, _profiles[index], isGrid: true)
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms)
            .scale(begin: const Offset(0.95, 0.95));
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _profiles.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 16.0),
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          return _buildAddProfileCard(context, isGrid: false);
        }
        return _buildProfileCard(context, _profiles[index], isGrid: false)
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms);
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, UserModel profile, {required bool isGrid}) {
    final id = profile.id ?? '';
    final isActive = id == _activeProfileId;
    final initials = _getInitials(profile.name);
    final gradient = _getGradient(id);
    final ageLabel = profile.ageCategory ?? 'Adult';

    if (isGrid) {
      return Container(
        decoration: AppDecorations.card(
          color: isActive ? AppColors.surfaceLight : AppColors.surface,
          radius: AppSpacing.radiusXl,
          withBorder: true,
        ).copyWith(
          border: isActive
              ? Border.all(color: AppColors.primary, width: 2.0)
              : Border.all(color: AppColors.border, width: 1.0),
        ),
        child: InkWell(
          onTap: () => _selectProfile(profile),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Initials Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                // Name
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 6.0),
                // Age label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ageLabel,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
                // Active State Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      isActive ? 'Active now' : 'Last active: Recently',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isActive ? AppColors.success : AppColors.textMuted,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                // Actions (Edit, Delete)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.textSecondary),
                      onPressed: () => context.push('/profile-edit?id=$id'),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash_2, size: 16, color: AppColors.error),
                      onPressed: () => _deleteProfile(profile),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Mobile List Card
      return Container(
        decoration: AppDecorations.card(
          color: isActive ? AppColors.surfaceLight : AppColors.surface,
          radius: AppSpacing.radiusLg,
          withBorder: true,
        ).copyWith(
          border: isActive
              ? Border.all(color: AppColors.primary, width: 2.0)
              : Border.all(color: AppColors.border, width: 1.0),
        ),
        child: InkWell(
          onTap: () => _selectProfile(profile),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                // Initials Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14.0),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Text(
                            ageLabel,
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            isActive ? 'Active now' : 'Recently active',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isActive ? AppColors.success : AppColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions (Edit, Delete)
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.textSecondary),
                  onPressed: () => context.push('/profile-edit?id=$id'),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash_2, size: 16, color: AppColors.error),
                  onPressed: () => _deleteProfile(profile),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAddProfileCard(BuildContext context, {required bool isGrid}) {
    if (isGrid) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: AppColors.borderLight,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/onboarding'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceLight,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Icon(LucideIcons.plus, size: 24, color: AppColors.primaryLight),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Add Profile',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'Set up a new companion',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: (_profiles.length * 100).ms, duration: 400.ms);
    } else {
      // Mobile List Card
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.borderLight,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/onboarding'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.plus, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 8.0),
                Text(
                  'Add New Profile',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: (_profiles.length * 100).ms, duration: 400.ms);
    }
  }

  Widget _buildContinueAsShortcut(BuildContext context) {
    if (_lastSelectedProfile == null) return const SizedBox();
    
    final profile = _lastSelectedProfile!;
    final initials = _getInitials(profile.name);
    final gradient = _getGradient(profile.id ?? '');
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24.0),
        width: double.infinity,
        decoration: AppDecorations.card(
          color: AppColors.surfaceLight.withValues(alpha: 0.8),
          radius: AppSpacing.radiusLg,
          withBorder: true,
        ).copyWith(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        child: InkWell(
          onTap: () => _selectProfile(profile),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            profile.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () => _selectProfile(profile),
                    icon: const Icon(LucideIcons.arrow_right, size: 16),
                    label: Text(
                      'Continue as ${profile.name.split(' ').first}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: 350.ms, duration: 500.ms).slideY(begin: 0.05, end: 0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 32.0),
      width: double.infinity,
      decoration: AppDecorations.card(
        color: AppColors.surfaceLight.withValues(alpha: 0.8),
        radius: AppSpacing.radiusXl,
        withBorder: true,
      ).copyWith(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: () => _selectProfile(profile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                ),
                // Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  onPressed: () => _selectProfile(profile),
                  icon: const Icon(LucideIcons.arrow_right, size: 16),
                  label: Text(
                    'Continue as ${profile.name.split(' ').first}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 500.ms).slideY(begin: 0.05, end: 0);
  }
}
