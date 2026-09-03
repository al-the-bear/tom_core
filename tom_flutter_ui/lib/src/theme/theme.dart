/// Theming — the two things Flutter's own theming has no concept of.
///
/// Tom does not replace `ThemeData`; colours, typography and component
/// themes stay Flutter's. This unit adds only what a Tom application needs
/// on top: a visual treatment for the withheld authorization states (`read`
/// and `disabled`), which Flutter models per-widget at best, and semantic
/// button variants, so a screen can ask for a *destructive* button rather
/// than naming a colour.
///
/// Read in this order:
/// - [TomTheme] — the theme object, reached through [TomThemeScope].
/// - [TomStateStyle] — how a withheld state is painted.
/// - [TomButtonVariants] — the semantic button roles.
///
/// Prose: `doc/theme.md`.
library;

export 'tom_state_style.dart';
export 'tom_style_variants.dart';
export 'tom_theme.dart';
