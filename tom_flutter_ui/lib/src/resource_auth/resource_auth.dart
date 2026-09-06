/// Resource resolution — turning names into Flutter objects.
///
/// Tom widgets store *names* in their resources — `"mRed"`, `"#FF5733"`,
/// `"mSave"` — never live Flutter objects. That is what lets a resource
/// bundle be data: loaded from a file, edited without a rebuild, and shared
/// with tooling that has no Flutter binding. This unit is the layer that
/// resolves those names, plus the environment and platform facts a
/// resolution may depend on.
///
/// Read in this order:
/// - [TomUIColors] — colour names to `Color`.
/// - [TomUIIcons] — icon names to `IconData`.
/// - [TomConfigProvider] — the configuration the two resolve against,
///   including the current [TomConfigEnvironment] and [TomConfigPlatform].
///
/// Applications extend the two catalogues by registering a
/// [TomUIColorAdapter] or [TomUIIconAdapter] rather than by editing them.
///
/// Prose: `doc/resource_auth.md`.
library;

// not-exported: tom_colors_generated.dart — 355 raw `Color` constants scraped
// from the Flutter SDK, wrapped by `tom_colors.dart`. The catalogue is the
// public surface; the table behind it is an implementation detail an
// application extends by registering a `TomUIColorAdapter`, never by naming a
// constant. Exporting it would also breach the package's namespacing rule,
// since the constants carry no `Tom` prefix.
// not-exported: tom_icons_generated.dart — the same, for the 10147 `IconData`
// constants behind `tom_icons.dart`.

export 'tom_colors.dart';
export 'tom_config_provider.dart';
export 'tom_icons.dart';
