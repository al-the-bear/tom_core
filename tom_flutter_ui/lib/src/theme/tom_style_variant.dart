/// Semantic style variants for Tom UI widgets.
///
/// Style variants express the semantic role of a widget in a screen region.
/// They are resolved to concrete Flutter styles (e.g., [ButtonStyle]) via
/// [TomVariantMap] in the nearest [TomThemeScope].
///
/// Variants are a Tom concept — Flutter provides the underlying styling
/// engine, but has no built-in notion of "this button is the primary
/// action". Tom bridges this gap.
enum TomStyleVariant {
  /// Main action — one per screen region. Typically a filled, prominent button.
  primary,

  /// Supporting action. Typically outlined or tonal.
  secondary,

  /// Tertiary or utility action. Typically text-only, subtle.
  auxiliary,

  /// Dangerous action (delete, discard). Typically red/warning color.
  destructive,
}
