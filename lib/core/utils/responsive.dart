import 'package:flutter/material.dart';
import '../constants/breakpoints.dart';

/// Responsive layout helper for VitalShield AI.
/// Provides device type detection and responsive value selection.
class Responsive {
  Responsive._();

  /// Check if current width is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < Breakpoints.mobile;

  /// Check if current width is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.mobile && width < Breakpoints.desktop;
  }

  /// Check if current width is desktop
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

  /// Check if current width is wide desktop
  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.wideDesktop;

  /// Returns a value based on the current device type
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }

  /// Returns the current device width
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Returns the current device height
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;
}
