import 'package:flutter/material.dart';


class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1000;
}


extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet => screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;
}


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
          return (tablet ?? desktop)(context); 
        }
        return desktop(context);
      },
    );
  }
}


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