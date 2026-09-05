import 'package:flutter/material.dart';

// Single source of truth for screen-size cutoffs =====
// Change these numbers once, and every page that uses them updates together.
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1000;
}

// Whole-screen checks — use these for "is the app in mobile mode" =====
// decisions like AppShell's sidebar vs hamburger menu.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet => screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;
}

// Area-specific layout switching — use this INSIDE a page when you
// want a particular section (not the whole screen) to adapt to however
// much space it's actually been given (e.g. inside a card, a column, a
// split-panel layout where the available width isn't the full screen). =====
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context) desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < Breakpoints.mobile) {
          return mobile(context);
        }
        if (width < Breakpoints.tablet) {
          return (tablet ?? desktop)(context); // tablet layout not given? fall back to desktop
        }
        return desktop(context);
      },
    );
  }
}

// Pick a plain value (not a widget) based on screen width — handy for
// things like column counts, padding, or font sizes that change per size
// without needing a full ResponsiveBuilder. =====
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  required T desktop,
}) {
  if (context.isMobile) return mobile;
  if (context.isTablet) return tablet ?? desktop;
  return desktop;
}