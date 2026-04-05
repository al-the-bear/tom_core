import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resource_auth/tom_auth_state.dart';
import '../resource_auth/tom_resources.dart';
import '../theme/tom_theme.dart';
import '../widget_base/tom_authorizable.dart';
import 'tom_ui_group.dart';

/// Mixin for Tom widgets that extend Flutter widgets directly.
///
/// This mixin provides the Tom UI concerns (ID, group, authorization, resources)
/// to widgets that extend their Flutter originals:
///
/// ```dart
/// class TomTab extends Tab with TomWidgetMixin {
///   TomTab({required this.tomId, this.tomGroup, ...});
///
///   @override
///   final String tomId;
///
///   @override
///   final TomUIGroup? tomGroup;
/// }
/// ```
///
/// The mixin provides:
/// - [tomId] — abstract, must be implemented
/// - [tomGroup] — optional group membership (TomUIGroup object)
/// - [resolveFullPath] — canonical path via [TomScope]
/// - [getAuth] — authorization state lookup
/// - [getText] — text resource lookup
/// - [checkHidden] — returns `SizedBox.shrink()` if hidden
/// - [applyReadonly] — applies readonly styling
/// - Group registration hooks for StatefulWidgets
///
/// Implements [TomAuthorizable] for type-safe group registration.
mixin TomWidgetMixin on Widget implements TomAuthorizable {
  /// The local widget ID (without prefix).
  ///
  /// This is combined with parent scope IDs to create the canonical path.
  /// Can be null for drop-in Flutter compatibility.
  @override
  String? get tomId;

  /// Optional group membership.
  ///
  /// When set, the widget registers with the group on mount using weak
  /// references. Groups are created manually and passed directly.
  @override
  TomUIGroup? get tomGroup => null;

  /// Resolves the full canonical path including scope path.
  ///
  /// Uses [TomScope.current] to build the path.
  /// Returns null if tomId is null.
  String? resolveFullPath() {
    if (tomId == null) return null;
    final scopePath = TomScope.current.getScopePath();
    if (scopePath.isNotEmpty) {
      return '$scopePath.$tomId';
    }
    return tomId;
  }

  /// Gets authorization state for this widget.
  TomAuthState getAuth() {
    final path = resolveFullPath();
    if (path == null) return TomAuthState.fullAccess;
    return TomUIAuthorization.resolveAuth(path);
  }

  /// Gets a text resource for this widget.
  ///
  /// Resolves `<canonical-path>.<suffix>` from [TomUIResources].
  String getText(String suffix) {
    final path = resolveFullPath();
    if (path == null) return '';
    return TomUIResources.resolveText(path, suffix);
  }

  /// Returns `SizedBox.shrink()` if authorization says hidden, `null` otherwise.
  ///
  /// Call at the start of `build()` methods:
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   final hidden = checkHidden();
  ///   if (hidden != null) return hidden;
  ///   // ... normal build
  /// }
  /// ```
  Widget? checkHidden() {
    if (!getAuth().visible) return const SizedBox.shrink();
    return null;
  }

  /// Wraps [child] in readonly style if authorization says readonly.
  ///
  /// The readonly style is resolved from [TomThemeScope].
  Widget applyReadonly(BuildContext context, Widget child) {
    if (getAuth().readonly) {
      final style = TomThemeScope.readonlyStyleOf(context);
      return style.apply(child);
    }
    return child;
  }

  /// Registers this widget with its group.
  ///
  /// For **StatefulWidgets**, call from `State.initState()`:
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   widget.registerWithGroup();
  /// }
  /// ```
  ///
  /// For **StatelessWidgets**, registration is handled by calling this
  /// in a wrapper or during build tracking.
  void registerWithGroup() {
    tomGroup?.register(this);
  }

  /// Unregisters this widget from its group.
  ///
  /// For **StatefulWidgets**, call from `State.dispose()`:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   widget.unregisterFromGroup();
  ///   super.dispose();
  /// }
  /// ```
  ///
  /// Note: This is optional since groups use weak references.
  void unregisterFromGroup() {
    tomGroup?.unregister(this);
  }

  /// Debug description for this widget.
  String get debugLabel {
    final parts = <String>['id: $tomId'];
    if (tomGroup != null) parts.add('group: ${tomGroup!.groupId}');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }

  // ===========================================================================
  // Typed Resource Resolution
  // ===========================================================================

  /// Resolves a color from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No color resource exists for this suffix
  /// - The color name cannot be resolved to a [Color]
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  Color? resolveColorOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomUIResources.resolveColor(basePath, suffix);
  }

  /// Resolves a double from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  double? resolveDoubleOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomUIResources.resolveDouble(basePath, suffix);
  }

  /// Resolves a required double from resources relative to this widget's canonical path.
  ///
  /// Throws [StateError] if:
  /// - This widget has no [tomId] (resource lookup is impossible)
  /// - No resource exists for this suffix
  /// - The value exists but is not numeric
  double resolveDoubleOrFail(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup. Widget: $runtimeType',
      );
    }
    if (!TomUIResources.resourceExists(basePath, suffix)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a numeric '
        'resource value at $basePath.$suffix. Widget: $runtimeType',
      );
    }
    final value = TomUIResources.resolveDouble(basePath, suffix);
    if (value == null) {
      throw StateError(
        'Resource $basePath.$suffix must be numeric for widget $runtimeType.',
      );
    }
    return value;
  }

  /// Resolves an int from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not numeric
  int? resolveIntOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomUIResources.resolveInt(basePath, suffix);
  }

  /// Resolves a bool from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The value is not boolean-like
  bool? resolveBoolOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomUIResources.resolveBool(basePath, suffix);
  }

  /// Resolves edge insets from resources relative to this widget's canonical path.
  ///
  /// Returns `null` if:
  /// - This widget has no [tomId]
  /// - No resource exists for this suffix
  /// - The format is not recognized
  ///
  /// Accepts various formats in the JSON resource:
  /// - A single number for uniform insets
  /// - An array [all], [horizontal, vertical], or [left, top, right, bottom]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  EdgeInsets? resolveEdgeInsetsOrNull(String suffix) {
    final basePath = resolveFullPath();
    if (basePath == null) return null;
    return TomUIResources.resolveEdgeInsets(basePath, suffix);
  }
}
