import 'package:material_ui/material_ui.dart';

/// Breakpoints and helpers so every screen works on phones, tablets and
/// desktop, in portrait and landscape.
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static bool isMobile(BuildContext c) =>
      MediaQuery.sizeOf(c).width < mobileMax;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= tabletMax;
  static bool isLandscape(BuildContext c) =>
      MediaQuery.orientationOf(c) == Orientation.landscape;

  /// A phone held sideways: wide but not tall.
  static bool isShort(BuildContext c) => MediaQuery.sizeOf(c).height < 480;

  /// Scales a size with the screen's shortest side (360 = 1.0), clamped.
  static double scale(BuildContext c, double v) {
    final s = (MediaQuery.sizeOf(c).shortestSide / 360).clamp(0.85, 1.35);
    return v * s;
  }

  /// Centers [child] and limits its width on wide screens.
  static Widget constrained(
    Widget child, {
    double maxWidth = 560,
    Alignment alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
