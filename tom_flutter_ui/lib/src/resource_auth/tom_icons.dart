import 'package:flutter/widgets.dart';

import 'tom_icons_generated.dart';

/// Adapter that resolves icons by name.
///
/// Icon names are retrieved from text resources (e.g., `w-saveButton.icon`
/// returns "mSave"), then resolved to actual [IconData] via this adapter.
///
/// Icon naming convention:
/// - Material icons: `m<PascalCaseName>` (e.g., `mAdd`, `mArrowBack`)
/// - Cupertino icons: `c<PascalCaseName>` (e.g., `cShare`, `cLeftChevron`)
///
/// The original Flutter snake_case names are converted to PascalCase.
/// Example: `arrow_back` -> `mArrowBack`, `left_chevron` -> `cLeftChevron`
abstract class TomUIIconAdapter {
  /// Resolves an icon by [name].
  ///
  /// Returns `null` if no icon is registered for that name.
  IconData? resolveIcon(String name);

  /// Whether an icon with [name] exists.
  bool iconExists(String name);
}

/// Global icon provider singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets resolve
/// icons by first getting the icon name from text resources, then looking
/// up the actual [IconData] through this provider.
///
/// Usage flow:
/// ```dart
/// // 1. Get icon name from resources
/// final iconName = TomCtr.text('w-saveButton', 'icon');
/// // -> returns "mSave"
///
/// // 2. Get IconData from icon provider
/// final iconData = TomUIIcons.resolveIcon(iconName);
/// // -> returns Icons.save
/// ```
///
/// App startup:
/// ```dart
/// TomUIIcons.adapter = TomAllIconsAdapter();
/// ```
class TomUIIcons {
  TomUIIcons._();

  /// The installed icon adapter, or `null` when none is installed.
  ///
  /// Readable so that a diagnostics screen or a startup assertion can ask
  /// what is wired, and so that code installing an adapter for one operation
  /// can put the previous one back:
  ///
  /// ```dart
  /// final saved = TomUIIcons.adapter;
  /// TomUIIcons.adapter = TomMaterialOnlyIconAdapter();
  /// // ...
  /// TomUIIcons.adapter = saved;
  /// ```
  ///
  /// Assigning `null` is what makes that restore total: it uninstalls without
  /// touching the registrations, which [reset] would also clear. [reset]
  /// remains the teardown hook for tests; this is the narrower tool.
  static TomUIIconAdapter? adapter;

  /// Resolves an icon by [name].
  ///
  /// Returns `null` if no adapter is set or the icon is not found.
  static IconData? resolveIcon(String name) {
    return adapter?.resolveIcon(name);
  }

  /// Whether an icon with [name] exists.
  static bool iconExists(String name) {
    return adapter?.iconExists(name) ?? false;
  }

  /// Drops the adapter **and** every custom registration.
  ///
  /// Intended for testing only. This is the whole hygiene hook: after it the
  /// module holds no state, so a suite needs nothing else in its `tearDown`.
  /// Clearing the registrations is the point — they live in a module-wide,
  /// process-global registry, so an override left behind by one test would
  /// silently change an icon in every later test rather than failing.
  ///
  /// To drop registrations while keeping the installed adapter, use
  /// [TomAllIconsAdapter.clearCustomIcons].
  static void reset() {
    adapter = null;
    _customIcons.clear();
  }
}

/// Icons registered at runtime, shared by every adapter in this module.
///
/// Module-level rather than a static on one adapter: registration and
/// resolution have to agree no matter which adapter is installed. An app that
/// registers its brand icons and then switches to [TomMaterialOnlyIconAdapter] for
/// bundle size — the one documented reason to switch — must not lose them,
/// and losing them would be silent: every registered name would simply
/// resolve to `null` and render nothing.
final Map<String, IconData> _customIcons = {};

/// Resolves registered icons first, then the adapter's own family table.
///
/// The precedence is stated once here rather than in each adapter, so
/// "registrations win" cannot hold for one adapter and not another.
abstract class _RegistryFirstIconAdapter implements TomUIIconAdapter {
  @override
  IconData? resolveIcon(String name) =>
      _customIcons[name] ?? resolveInFamily(name);

  @override
  bool iconExists(String name) =>
      _customIcons.containsKey(name) || existsInFamily(name);

  /// Resolves [name] against the adapter's own icon table, ignoring
  /// registrations.
  IconData? resolveInFamily(String name);

  /// Whether [name] is in the adapter's own table, ignoring registrations.
  bool existsInFamily(String name);
}

/// Default adapter using all generated Flutter icons (Material + Cupertino).
///
/// Contains 10,000+ icons from both Material Design and Cupertino icon sets.
/// This is the recommended adapter for most applications.
///
/// Icon naming:
/// - Material: `m<PascalCase>` (e.g., `mAdd`, `mArrowBack`, `mSettings`)
/// - Cupertino: `c<PascalCase>` (e.g., `cShare`, `cBook`, `cLeftChevron`)
class TomAllIconsAdapter extends _RegistryFirstIconAdapter {
  @override
  IconData? resolveInFamily(String name) => GeneratedIcons.resolve(name);

  @override
  bool existsInFamily(String name) => GeneratedIcons.exists(name);

  /// Registers additional custom icons for **every** adapter in this module.
  ///
  /// Use this to add app-specific icons or override existing ones. The
  /// registry is module-wide, so a name registered here also resolves through
  /// [TomMaterialOnlyIconAdapter] and [TomCupertinoOnlyIconAdapter]; registrations take
  /// precedence over the built-in tables in all three.
  /// [TomUIIcons.reset] clears them along with the adapter.
  static void registerIcons(Map<String, IconData> icons) {
    _customIcons.addAll(icons);
  }

  /// Clears all custom registered icons, for every adapter in this module,
  /// keeping the installed adapter.
  ///
  /// A test tearing down the whole module wants [TomUIIcons.reset] instead.
  static void clearCustomIcons() {
    _customIcons.clear();
  }
}

/// Adapter that only includes Material icons.
///
/// Use this for smaller bundle size if you don't need Cupertino icons.
/// Icons registered through [TomAllIconsAdapter.registerIcons] still resolve —
/// the registry is module-wide — but the Cupertino table stays out.
class TomMaterialOnlyIconAdapter extends _RegistryFirstIconAdapter {
  @override
  IconData? resolveInFamily(String name) => GeneratedIcons.materialIcons[name];

  @override
  bool existsInFamily(String name) =>
      GeneratedIcons.materialIcons.containsKey(name);
}

/// Adapter that only includes Cupertino icons.
///
/// Use this for iOS-focused apps that only need Cupertino icons.
/// Icons registered through [TomAllIconsAdapter.registerIcons] still resolve —
/// the registry is module-wide — but the Material table stays out.
class TomCupertinoOnlyIconAdapter extends _RegistryFirstIconAdapter {
  @override
  IconData? resolveInFamily(String name) => GeneratedIcons.cupertinoIcons[name];

  @override
  bool existsInFamily(String name) =>
      GeneratedIcons.cupertinoIcons.containsKey(name);
}
