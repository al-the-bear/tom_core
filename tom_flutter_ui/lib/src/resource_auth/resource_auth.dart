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
///   including the current [TomEnvironment] and [TomPlatform].
///
/// Applications extend the two catalogues by registering a
/// [TomUIColorAdapter] or [TomUIIconAdapter] rather than by editing them.
///
/// Prose: `doc/resource_auth.md`.
library;

export 'tom_colors.dart';
export 'tom_config_provider.dart';
export 'tom_icons.dart';
