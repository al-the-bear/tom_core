import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../groups/tom_ui_group.dart';
import '../resource_auth/tom_resources.dart';
import '../widgets/labels/tom_labels.dart';

/// Static helpers for construction-time resource resolution.
///
/// These methods resolve resources at widget construction time,
/// taking a pre-resolved full path. The path should be computed once
/// in the widget constructor using [resolvePath].
///
/// Example:
/// ```dart
/// class TomSnackBarAction extends SnackBarAction {
///   final String? _path;
///
///   TomSnackBarAction({
///     String? tomId,
///     TomScope? scope,
///     String? label,
///     ...
///   }) : _path = TomCtr.resolvePath(tomId, scope),
///        super(
///          label: label ?? TomCtr.text('$_path.label'),
///        );
/// }
/// ```
class TomCtr {
  TomCtr._();

  // ===========================================================================
  // Path Resolution (called once in constructor)
  // ===========================================================================

  /// Builds the full canonical path from scope and tomId.
  ///
  /// Call this once in the constructor and store the result.
  /// Returns `<scopePath>.<tomId>` or just `tomId` if scope path is empty.
  /// Returns `null` if tomId is null.
  static String? resolvePath(String? tomId, [TomScope? scope]) {
    if (tomId == null) return null;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    if (scopePath.isNotEmpty) {
      return '$scopePath.$tomId';
    }
    return tomId;
  }

  // ===========================================================================
  // Text Resolution
  // ===========================================================================

  /// Resolves text from the full path.
  ///
  /// Returns resolved text, or empty string if path is null.
  static String text(String? path) {
    if (path == null) return '';
    return TomUIResources.resolveText(path, '');
  }

  /// Resolves text from the full path, returning null if no resource.
  static String? textOrNull(String? path) {
    if (path == null) return null;
    if (!TomUIResources.resourceExists(path, '')) return null;
    return TomUIResources.resolveText(path, '');
  }

  // ===========================================================================
  // Color Resolution
  // ===========================================================================

  /// Resolves a color from the full path.
  static Color? color(String? path) {
    if (path == null) return null;
    return TomUIResources.resolveColor(path, '');
  }

  // ===========================================================================
  // Numeric Resolution
  // ===========================================================================

  /// Resolves a double from the full path.
  static double? doubleVal(String? path) {
    if (path == null) return null;
    return TomUIResources.resolveDouble(path, '');
  }

  /// Resolves an int from the full path.
  static int? intVal(String? path) {
    if (path == null) return null;
    return TomUIResources.resolveInt(path, '');
  }

  // ===========================================================================
  // EdgeInsets Resolution
  // ===========================================================================

  /// Resolves EdgeInsets from the full path.
  static EdgeInsets? edgeInsets(String? path) {
    if (path == null) return null;
    return TomUIResources.resolveEdgeInsets(path, '');
  }

  // ===========================================================================
  // Default Widget Creation
  // ===========================================================================

  /// Creates a default TomText widget for a Widget parameter.
  ///
  /// The [tomId] should be the **relative** widget identifier (not the full
  /// canonical path). For example, pass `'$parentTomId.child'` not the full
  /// path with scope prefix. TomText will resolve the scope path itself.
  ///
  /// Returns `null` if [tomId] is null.
  ///
  /// Example:
  /// ```dart
  /// // For a snackbar with tomId 'saveSuccess', create child content:
  /// TomCtr.defaultText('saveSuccess.content', scope, tomGroup)
  /// // TomText will look up: <scopePath>.saveSuccess.content.label
  /// ```
  static TomText? defaultText(
    String? tomId, [
    TomScope? scope,
    TomUIGroup? tomGroup,
  ]) {
    if (tomId == null) return null;
    return TomText(
      tomId: tomId,
      scope: scope,
      tomGroup: tomGroup,
    );
  }

  /// Creates a default TomText widget, or falls back to a placeholder.
  ///
  /// Unlike [defaultText], this never returns null — returns a `SizedBox.shrink()`
  /// if [tomId] is null.
  ///
  /// See [defaultText] for parameter details.
  static Widget defaultTextOrEmpty(
    String? tomId, [
    TomScope? scope,
    TomUIGroup? tomGroup,
  ]) {
    if (tomId == null) return const SizedBox.shrink();
    return TomText(
      tomId: tomId,
      scope: scope,
      tomGroup: tomGroup,
    );
  }

  /// Helper for building a child tomId from parent tomId.
  ///
  /// Returns `'$tomId.$suffix'` if tomId is not null, otherwise null.
  /// Use this when passing tomId to [defaultText] or [defaultTextOrEmpty].
  static String? childTomId(String? tomId, String suffix) {
    return tomId != null ? '$tomId.$suffix' : null;
  }
}
