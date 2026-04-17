library;

/// Named breakpoint values shared across the form system (and the rest of
/// the app, if you want). The three fields are mutable so app authors can
/// retune the breakpoint ladder once, early at startup, and have every
/// `@bp.mobile` / `@bp.tablet` / `@bp.desktop` resource key and every
/// programmatic reference follow that retuning.
///
/// ```dart
/// void main() {
///   TomBreakpoint.mobile = 560;   // optional retune
///   TomBreakpoint.tablet = 960;
///   TomBreakpoint.desktop = 1280;
///   runApp(...);
/// }
/// ```
///
/// In resources, both numeric keys and named keys are accepted side-by-
/// side:
///
/// ```jsonc
/// "@bp": {
///   "mobile":  { ... },   //  → TomBreakpoint.mobile
///   "tablet":  { ... },   //  → TomBreakpoint.tablet
///   "desktop": { ... },   //  → TomBreakpoint.desktop
///   "1600":    { ... }    //  literal
/// }
/// ```
///
/// The highest `minWidth <= available width` wins; named and literal
/// entries compete in the same pool after name resolution.
class TomBreakpoint {
  /// Minimum width (in logical pixels) at which the layout is considered
  /// "mobile". Default: `600`.
  static double mobile = 600;

  /// Minimum width at which the layout is considered "tablet".
  /// Default: `900`.
  static double tablet = 900;

  /// Minimum width at which the layout is considered "desktop".
  /// Default: `1200`.
  static double desktop = 1200;

  /// Resolves a named key to its current numeric breakpoint value. Returns
  /// `null` for unrecognised names, which callers should treat as "skip
  /// this entry".
  static double? resolve(String name) {
    switch (name.toLowerCase()) {
      case 'mobile':
        return mobile;
      case 'tablet':
        return tablet;
      case 'desktop':
        return desktop;
      default:
        return null;
    }
  }

  /// The canonical list of named breakpoints, in ascending-default order.
  /// Used by the resource overlay to know which named keys to probe.
  static const List<String> names = ['mobile', 'tablet', 'desktop'];
}
