library;

/// Named breakpoint values shared across the form system (and the rest of
/// the app, if you want). App authors can retune the breakpoint ladder once,
/// early at startup, and have every `@bp.mobile` / `@bp.tablet` /
/// `@bp.desktop` resource key and every programmatic reference follow that
/// retuning.
///
/// The thresholds are exposed as **read-only getters** and mutated only
/// through [configure] — a single, named entry point — rather than as
/// free-floating public mutable statics. This keeps the "retune at startup"
/// capability while making every change go through one obvious channel (no
/// accidental `TomBreakpoint.mobile = …` reassignment scattered across the
/// codebase).
///
/// ```dart
/// void main() {
///   TomBreakpoint.configure(mobile: 560, tablet: 960, desktop: 1280);
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
  static double _mobile = 600;
  static double _tablet = 900;
  static double _desktop = 1200;

  /// Minimum width (in logical pixels) at which the layout is considered
  /// "mobile". Default: `600`.
  static double get mobile => _mobile;

  /// Minimum width at which the layout is considered "tablet".
  /// Default: `900`.
  static double get tablet => _tablet;

  /// Minimum width at which the layout is considered "desktop".
  /// Default: `1200`.
  static double get desktop => _desktop;

  /// Retunes the breakpoint ladder. The single supported mutation path —
  /// call once early at startup. Only the thresholds passed (non-`null`) are
  /// changed; the rest keep their current value.
  static void configure({double? mobile, double? tablet, double? desktop}) {
    if (mobile != null) _mobile = mobile;
    if (tablet != null) _tablet = tablet;
    if (desktop != null) _desktop = desktop;
  }

  /// Restores the default ladder (`600` / `900` / `1200`). Intended for tests
  /// so breakpoint state cannot leak between cases.
  static void reset() {
    _mobile = 600;
    _tablet = 900;
    _desktop = 1200;
  }

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
