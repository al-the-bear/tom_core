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
/// final iconName = TomUIResources.resolveText('w-saveButton', 'icon');
/// // -> returns "mSave"
///
/// // 2. Get IconData from icon provider
/// final iconData = TomUIIcons.resolveIcon(iconName);
/// // -> returns Icons.save
/// ```
///
/// App startup:
/// ```dart
/// TomUIIcons.adapter = AllIconsAdapter();
/// ```
class TomUIIcons {
  TomUIIcons._();

  static TomUIIconAdapter? _adapter;

  static set adapter(TomUIIconAdapter adapter) => _adapter = adapter;

  /// Resolves an icon by [name].
  ///
  /// Returns `null` if no adapter is set or the icon is not found.
  static IconData? resolveIcon(String name) {
    return _adapter?.resolveIcon(name);
  }

  /// Whether an icon with [name] exists.
  static bool iconExists(String name) {
    return _adapter?.iconExists(name) ?? false;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
}

/// Default adapter using all generated Flutter icons (Material + Cupertino).
///
/// Contains 10,000+ icons from both Material Design and Cupertino icon sets.
/// This is the recommended adapter for most applications.
///
/// Icon naming:
/// - Material: `m<PascalCase>` (e.g., `mAdd`, `mArrowBack`, `mSettings`)
/// - Cupertino: `c<PascalCase>` (e.g., `cShare`, `cBook`, `cLeftChevron`)
class AllIconsAdapter implements TomUIIconAdapter {
  /// Custom icons registered at runtime.
  static final Map<String, IconData> _customIcons = {};

  @override
  IconData? resolveIcon(String name) {
    return _customIcons[name] ?? GeneratedIcons.resolve(name);
  }

  @override
  bool iconExists(String name) {
    return _customIcons.containsKey(name) || GeneratedIcons.exists(name);
  }

  /// Registers additional custom icons.
  ///
  /// Use this to add app-specific icons or override existing ones.
  static void registerIcons(Map<String, IconData> icons) {
    _customIcons.addAll(icons);
  }

  /// Clears all custom registered icons.
  static void clearCustomIcons() {
    _customIcons.clear();
  }
}

/// Adapter that only includes Material icons.
///
/// Use this for smaller bundle size if you don't need Cupertino icons.
class MaterialOnlyAdapter implements TomUIIconAdapter {
  @override
  IconData? resolveIcon(String name) {
    return GeneratedIcons.materialIcons[name];
  }

  @override
  bool iconExists(String name) {
    return GeneratedIcons.materialIcons.containsKey(name);
  }
}

/// Adapter that only includes Cupertino icons.
///
/// Use this for iOS-focused apps that only need Cupertino icons.
class CupertinoOnlyAdapter implements TomUIIconAdapter {
  @override
  IconData? resolveIcon(String name) {
    return GeneratedIcons.cupertinoIcons[name];
  }

  @override
  bool iconExists(String name) {
    return GeneratedIcons.cupertinoIcons.containsKey(name);
  }
}
