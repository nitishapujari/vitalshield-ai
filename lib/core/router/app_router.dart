import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/layouts/app_scaffold.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_selection_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/checkin/presentation/checkin_screen.dart';
import '../../features/health_overview/health_overview_screen.dart';
import '../../features/predictions/predictions_screen.dart';
import '../../features/assistant/assistant_screen.dart';
import '../../features/wellness/wellness_screen.dart';
import '../../features/wellness/wellness_rhythm_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/simulation/simulation_screen.dart';
import '../../features/journey/journey_screen.dart';

import '../../services/storage_service.dart';

/// App router configuration using go_router.
/// Shell route wraps post-auth screens with AppScaffold.
final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final location = state.uri.path;

    // Allow SplashScreen to render immediately without blocking on async checks on mobile.
    // On web, run the checks inline to bypass the splash screen completely and route to the destination.
    if (location == '/') {
      if (kIsWeb) {
        final storage = StorageService();
        final authenticated = await storage.isAuthenticated();
        if (!authenticated) {
          return '/login';
        }
        final profiles = await storage.getAllProfiles();
        if (profiles.isEmpty) {
          return '/onboarding';
        }
        final activeId = await storage.getCurrentProfileId();
        if (activeId == null && profiles.isNotEmpty) {
          if (profiles.length == 1) {
            await storage.setCurrentProfileId(profiles.first.id!);
            await storage.setLastSelectedProfileId(profiles.first.id!);
            return '/dashboard';
          } else {
            return '/profile-select';
          }
        }
        return '/dashboard';
      }
      return null;
    }

    final storage = StorageService();
    final authenticated = await storage.isAuthenticated();
    final profiles = await storage.getAllProfiles();

    final isPublicPath = location == '/login' || location == '/signup';

    if (!authenticated) {
      if (!isPublicPath) {
        return '/login';
      }
      return null;
    }

    // User is authenticated
    if (profiles.isEmpty) {
      if (location != '/onboarding') {
        return '/onboarding';
      }
      return null;
    }

    // Authenticated and has profiles
    if (location == '/login' || location == '/signup') {
      final activeId = await storage.getCurrentProfileId();
      if (activeId == null) {
        if (profiles.length == 1) {
          await storage.setCurrentProfileId(profiles.first.id!);
          await storage.setLastSelectedProfileId(profiles.first.id!);
          return '/dashboard';
        }
        return '/profile-select';
      }
      return '/dashboard';
    }

    // Guard dashboard and feature pages: redirect if no active profile is selected
    final isSpecialPath = location == '/' || location == '/onboarding' || location == '/profile-select';
    if (!isSpecialPath) {
      final activeId = await storage.getCurrentProfileId();
      if (activeId == null) {
        if (profiles.length == 1) {
          await storage.setCurrentProfileId(profiles.first.id!);
          await storage.setLastSelectedProfileId(profiles.first.id!);
        } else {
          return '/profile-select';
        }
      }
    }

    return null;
  },
  routes: [
    // ── Pre-auth routes (no scaffold) ──
    GoRoute(
      path: '/',
      builder: (context, state) => kIsWeb
          ? Container(color: const Color(0xFF0A0E1A))
          : const SplashScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/profile-select', builder: (context, state) => const ProfileSelectionScreen()),
    GoRoute(path: '/profile-edit', builder: (context, state) => ProfileEditScreen(profileId: state.uri.queryParameters['id'])),

    // ── Post-auth routes (with AppScaffold shell) ──
    ShellRoute(
      builder: (context, state, child) {
        return Consumer(
          builder: (context, ref, _) {
            return AppScaffold(
              currentPath: state.uri.path,
              showWellness: true,
              child: child,
            );
          },
        );
      },
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/checkin', builder: (context, state) => const CheckinScreen()),
        GoRoute(path: '/health-overview', builder: (context, state) => const HealthOverviewScreen()),
        GoRoute(path: '/predictions', builder: (context, state) => const PredictionsScreen()),
        GoRoute(path: '/ai-assistant', builder: (context, state) => const AssistantScreen()),
        GoRoute(path: '/wellness', builder: (context, state) => const WellnessScreen()),
        GoRoute(path: '/wellness-rhythm', builder: (context, state) => const WellnessRhythmScreen()),
        GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        GoRoute(path: '/simulation', builder: (context, state) => const SimulationScreen()),
        GoRoute(path: '/journey', builder: (context, state) => const JourneyScreen()),
      ],
    ),
  ],
);

