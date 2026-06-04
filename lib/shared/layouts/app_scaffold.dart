import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../navigation/sidebar.dart';
import '../../navigation/bottom_nav.dart';
import '../../core/theme/app_colors.dart';

/// Responsive scaffold that wraps all main app screens.
/// Desktop/Tablet: Sidebar + content area.
/// Mobile: Content area + bottom navigation.
/// Uses static background — no animated gradients on main app screens.
class AppScaffold extends StatelessWidget {
  final Widget child;
  final String currentPath;
  final bool showWellness;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentPath,
    this.showWellness = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar for desktop/tablet
          if (!isMobile)
            Sidebar(
              currentPath: currentPath,
              showWellness: showWellness,
            ),

          // Main content
          Expanded(
            child: Column(
              children: [
                Expanded(child: child),

                // Bottom nav for mobile only
                if (isMobile)
                  BottomNav(currentPath: currentPath),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
