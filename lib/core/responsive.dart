import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wide = 1600;
}

/// Device type enum
enum DeviceType { mobile, tablet, desktop }

/// Responsive utilities for adaptive layouts
class Responsive {
  /// Get current device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return DeviceType.mobile;
    if (width < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Check if current device is mobile
  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  /// Check if current device is tablet
  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  /// Check if current device is desktop
  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  /// Check if we should show sidebar navigation
  static bool showSideNav(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.tablet;

  /// Get content padding based on screen size
  static EdgeInsets getContentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) {
      return const EdgeInsets.all(16);
    } else if (width < Breakpoints.tablet) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  /// Get maximum content width for centering
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.tablet) return double.infinity;
    if (width < Breakpoints.desktop) return 800;
    return 1000;
  }

  /// Get number of grid columns
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return 1;
    if (width < Breakpoints.tablet) return 2;
    if (width < Breakpoints.desktop) return 3;
    return 4;
  }

  /// Get sidebar width
  static double getSidebarWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.wide) return 280;
    if (width >= Breakpoints.desktop) return 240;
    return 220;
  }
}

/// Responsive builder widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = Responsive.getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}

/// Centered content wrapper with max width
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? Responsive.getMaxContentWidth(context),
        ),
        child: Padding(
          padding: padding ?? Responsive.getContentPadding(context),
          child: child,
        ),
      ),
    );
  }
}

