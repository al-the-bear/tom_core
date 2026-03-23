import 'package:flutter/widgets.dart';

import 'tom_group.dart';

/// Global registry for widget groups.
///
/// Groups are created on-demand when widgets register. The registry provides
/// lookup methods to find groups and widgets within groups.
///
/// ```dart
/// // Get or create a group
/// final group = TomGroups.of('shippingPanel');
///
/// // Find a widget in a group
/// final widget = TomGroups.findWidget('shippingPanel', 'street');
///
/// // Iterate all widgets in a group
/// for (final widget in TomGroups.widgetsIn('shippingPanel')) {
///   print(widget.tomId);
/// }
/// ```
class TomGroups {
  TomGroups._();

  static final Map<String, TomGroup> _groups = {};

  /// Gets or creates a group with the given [groupId].
  ///
  /// Groups are created lazily when first accessed.
  static TomGroup of(String groupId) {
    return _groups.putIfAbsent(groupId, () => TomGroup(groupId));
  }

  /// Gets an existing group, or `null` if it doesn't exist.
  static TomGroup? get(String groupId) => _groups[groupId];

  /// Whether a group with the given [groupId] exists.
  static bool exists(String groupId) => _groups.containsKey(groupId);

  /// Finds a widget by [tomId] within a group.
  ///
  /// Uses duck typing to check for `tomId` property. Returns `null` if the
  /// group doesn't exist or the widget isn't found.
  static Widget? findWidget(String groupId, String tomId) {
    final group = _groups[groupId];
    if (group == null) return null;
    for (final widget in group.members) {
      // Use dynamic to access tomId without importing TomWidgetMixin
      if ((widget as dynamic).tomId == tomId) return widget;
    }
    return null;
  }

  /// All widgets currently registered in a group.
  ///
  /// Returns an empty iterable if the group doesn't exist.
  static Iterable<Widget> widgetsIn(String groupId) {
    return _groups[groupId]?.members ?? const [];
  }

  /// All registered group IDs.
  static Iterable<String> get allGroupIds => _groups.keys;

  /// Removes a group from the registry.
  ///
  /// The group's members are NOT unregistered — this should only be called
  /// after all members have been disposed.
  static void remove(String groupId) => _groups.remove(groupId);

  /// Clears all groups from the registry.
  ///
  /// Intended for testing only.
  static void reset() => _groups.clear();
}
