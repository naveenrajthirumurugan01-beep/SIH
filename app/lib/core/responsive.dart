import 'package:flutter/material.dart';

/// Screen size breakpoints used throughout the application.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600.0;
  static const double tablet = 1024.0;
}

/// A responsive widget switcher that renders different layouts based on
/// screen width thresholds.
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= Breakpoints.mobile && width < Breakpoints.tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.tablet;

  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.tablet) return desktop;
    if (width >= Breakpoints.mobile) return tablet ?? mobile;
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return desktop;
        } else if (constraints.maxWidth >= Breakpoints.mobile) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Convenience BuildContext extension for checking screen width breakpoints.
extension ResponsiveContext on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) =>
      Responsive.value<T>(
        context: this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
}

/// A reusable responsive grid wrapper that dynamically adjusts its column count
/// based on the available width.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= Breakpoints.tablet
            ? desktopColumns
            : (constraints.maxWidth >= Breakpoints.mobile
                ? tabletColumns
                : mobileColumns);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

/// A reusable responsive padding wrapper that applies breakpoint-appropriate
/// padding (12px mobile, 16px tablet, 24px desktop by default).
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  static EdgeInsetsGeometry defaultPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.tablet) {
      return const EdgeInsets.all(24);
    } else if (width >= Breakpoints.mobile) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.responsiveValue<EdgeInsetsGeometry>(
      mobile: mobilePadding ?? const EdgeInsets.all(12),
      tablet: tabletPadding ?? const EdgeInsets.all(16),
      desktop: desktopPadding ?? const EdgeInsets.all(24),
    );

    return Padding(
      padding: padding,
      child: child,
    );
  }
}
