/// Spacing scale — multiples of 4 with named steps. Never use literal
/// padding values; compose from these steps so rhythm stays consistent.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;
}

/// Corner radii used across cards, buttons, inputs and sheets.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double pill = 999;
}

/// Elevation ("soft, controlled shadows") — levels used by themed classes.
abstract final class AppElevation {
  static const double flat = 0;
  static const double resting = 1;
  static const double raised = 3;
}

/// Icon sizes.
abstract final class AppIconSize {
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
}

/// Motion durations; keep motion purposeful and quick.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration screen = Duration(milliseconds: 240);
}

/// Accessibility floor for interactive controls.
abstract final class TouchTarget {
  static const double minInteractive = 48;
}
