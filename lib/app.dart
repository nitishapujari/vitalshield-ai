import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_strings.dart';
import 'features/predictions/services/prediction_sync_service.dart';

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Suppress scrollbar overlay rendering globally
  }
}

/// Root application widget for VitalShield AI.
class VitalShieldApp extends ConsumerWidget {
  const VitalShieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch PredictionSyncService so it initializes and runs its triggers (startup & online transitions)
    ref.watch(predictionSyncServiceProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      scrollBehavior: const _NoScrollbarBehavior(),
    );
  }
}

