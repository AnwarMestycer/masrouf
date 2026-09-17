/// A 4pt spacing scale.
///
/// Named steps rather than raw numbers so density can be tuned in one place, and
/// so `const` padding values are shared instances instead of one allocation per
/// widget build.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Comfortably reachable one-handed; also the Material minimum touch target.
  static const double minTouchTarget = 48;

  /// Corner radii.
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusPill = 999;
}
