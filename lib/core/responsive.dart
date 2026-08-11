import 'package:flutter/material.dart';

/// Single shared source of breakpoints for the whole app (landing,
/// dashboards, everything) so every screen agrees on what "mobile" means.
class Responsive {
  static const double mobileMax = 768;
  static const double tabletMax = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  static double pagePadding(BuildContext context) {
    if (isMobile(context)) return 20;
    if (isTablet(context)) return 40;
    return 80;
  }

  /// Column count helper for grids (gallery, achievements, statistics).
  static int columns(BuildContext context, {int max = 4}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1000) return max;
    if (w >= 650) return (max - 1).clamp(1, max);
    return max >= 2 ? 2 : 1;
  }
}

/// Convenience widget for the (rarer) cases where mobile vs desktop are
/// structurally different layouts, not just a column-count change.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) =>
      Responsive.isMobile(context) ? mobile : desktop;
}