import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../groups/tom_ui_group.dart';
import '../resource_auth/tom_colors.dart';
import '../resource_auth/tom_icons.dart';
import '../widgets/labels/tom_labels.dart';

/// Single entry point for all resource resolution in Tom UI.
///
/// All methods accept an optional [suffix] that is appended to [basePath]
/// with a dot separator. When [suffix] is empty, [basePath] is used as-is.
///
/// Two usage patterns:
/// ```dart
/// // Full pre-resolved path (construction helpers):
/// TomCtr.text('$_path.label')
///
/// // Base path + suffix (widget build methods):
/// TomCtr.textOrNull(basePath, 'label')
/// ```
class TomCtr {
  TomCtr._();

  static TomTextResourceProvider get _provider =>
      TomTextResourceProvider.getAppResources();

  /// Builds a resource key from [basePath] and optional [suffix].
  static String _key(String basePath, String suffix) {
    if (suffix.isEmpty) return basePath;
    return '$basePath.$suffix';
  }

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

  /// Resolves text from resources.
  ///
  /// Returns resolved text, or empty string if [basePath] is null.
  /// If no resource is found, returns the key as a development indicator.
  static String text(String? basePath, [String suffix = '']) {
    if (basePath == null) return '';
    return _provider.getText(_key(basePath, suffix));
  }

  /// Resolves text from resources, returning null if no resource.
  static String? textOrNull(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    return _provider.getTextOrNull(_key(basePath, suffix));
  }

  /// Resolves a required text resource.
  ///
  /// Throws [StateError] if [basePath] is null.
  /// If tomId is set but no resource exists, returns the key for development
  /// visibility.
  static String textOrFail(String? basePath, String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup.',
      );
    }
    final key = _key(basePath, suffix);
    if (!_provider.exists(key) && !_provider.existsObject(key)) {
      return key;
    }
    return _provider.getText(key);
  }

  // ===========================================================================
  // Existence Check
  // ===========================================================================

  /// Whether a resource exists for [basePath] + [suffix].
  static bool exists(String? basePath, [String suffix = '']) {
    if (basePath == null) return false;
    final key = _key(basePath, suffix);
    return _provider.exists(key) || _provider.existsObject(key);
  }

  // ===========================================================================
  // Color Resolution
  // ===========================================================================

  /// Resolves a color from resources.
  ///
  /// The resource value should be a color name (e.g., "mRed", "cSystemBlue")
  /// or hex string (e.g., "#FF5733") that [TomUIColors] can resolve.
  static Color? color(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    if (value == null) return null;
    if (value is String) return TomUIColors.resolveColor(value);
    if (value is int) return Color(value);
    return null;
  }

  /// Resolves a required color from resources.
  ///
  /// Throws [StateError] if [basePath] is null, no resource exists,
  /// or the value cannot be parsed as a color.
  static Color colorOrFail(String? basePath, String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup.',
      );
    }
    final key = _key(basePath, suffix);
    if (!_provider.exists(key) && !_provider.existsObject(key)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a color '
        'resource value at $key.',
      );
    }
    final value = _provider.getObjectOrNull(key);
    if (value == null) {
      throw StateError('Resource $key must be a valid color.');
    }
    Color? result;
    if (value is String) result = TomUIColors.resolveColor(value);
    if (value is int) result = Color(value);
    if (result == null) {
      throw StateError('Resource $key must be a valid color.');
    }
    return result;
  }

  // ===========================================================================
  // Icon Resolution
  // ===========================================================================

  /// Resolves an icon from resources.
  ///
  /// The resource value should be an icon name (e.g., "mAdd", "mSettings")
  /// that [TomUIIcons] can resolve.
  static IconData? icon(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    if (value == null) return null;
    if (value is String) return TomUIIcons.resolveIcon(value);
    return null;
  }

  // ===========================================================================
  // Numeric Resolution
  // ===========================================================================

  /// Resolves a double from resources.
  ///
  /// Accepts double, int, or parseable string values.
  static double? doubleVal(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Resolves a required double from resources.
  ///
  /// Throws [StateError] if [basePath] is null, no resource exists,
  /// or the value is not numeric.
  static double doubleOrFail(String? basePath, String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup.',
      );
    }
    final key = _key(basePath, suffix);
    if (!_provider.exists(key) && !_provider.existsObject(key)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a numeric '
        'resource value at $key.',
      );
    }
    final result = doubleVal(basePath, suffix);
    if (result == null) {
      throw StateError('Resource $key must be numeric.');
    }
    return result;
  }

  /// Resolves an int from resources.
  ///
  /// Accepts int, double (truncated), or parseable string values.
  static int? intVal(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Resolves a required int from resources.
  ///
  /// Throws [StateError] if [basePath] is null, no resource exists,
  /// or the value is not numeric.
  static int intOrFail(String? basePath, String suffix) {
    if (basePath == null) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a tomId for '
        'resource lookup.',
      );
    }
    final key = _key(basePath, suffix);
    if (!_provider.exists(key) && !_provider.existsObject(key)) {
      throw StateError(
        'Tom widget requires either an explicit $suffix or a numeric '
        'resource value at $key.',
      );
    }
    final result = intVal(basePath, suffix);
    if (result == null) {
      throw StateError('Resource $key must be an int.');
    }
    return result;
  }

  // ===========================================================================
  // Bool Resolution
  // ===========================================================================

  /// Resolves a bool from resources.
  ///
  /// Accepts bool values or string "true"/"false".
  static bool? boolVal(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  // ===========================================================================
  // EdgeInsets Resolution
  // ===========================================================================

  /// Resolves EdgeInsets from resources.
  ///
  /// Accepts:
  /// - A single number for uniform insets
  /// - An array \[all\], \[horizontal, vertical\], or \[left, top, right, bottom\]
  /// - A map with keys: "all", "horizontal", "vertical", "left", "top", "right", "bottom"
  static EdgeInsets? edgeInsets(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final value = _provider.getObjectOrNull(_key(basePath, suffix));
    return _parseEdgeInsets(value);
  }

  // ===========================================================================
  // Generic Value Resolution
  // ===========================================================================

  /// Resolves any value from resources.
  static dynamic value(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    return _provider.getObjectOrNull(_key(basePath, suffix));
  }

  /// Resolves a list from resources.
  ///
  /// Returns `null` if no resource found or the resource is not a list.
  static List<dynamic>? list(String? basePath, [String suffix = '']) {
    final v = value(basePath, suffix);
    if (v is List) return v;
    return null;
  }

  /// Resolves a map from resources.
  ///
  /// Returns `null` if no resource found or the resource is not a map.
  static Map<String, dynamic>? map(String? basePath, [String suffix = '']) {
    final v = value(basePath, suffix);
    if (v is Map<String, dynamic>) return v;
    return null;
  }

  // ===========================================================================
  // TextStyle Resolution
  // ===========================================================================

  /// Resolves a [TextStyle] from a sub-tree under [basePath] + [suffix].
  ///
  /// Reads the following keys (all optional):
  /// - `fontSize` (double)
  /// - `fontWeight` (string: "w100".."w900" / "normal" / "bold", or int 100..900)
  /// - `fontFamily` (string)
  /// - `color` (color resolvable via [color])
  /// - `letterSpacing` (double)
  /// - `fontStyle` (string: "normal" | "italic")
  ///
  /// Returns `null` if [basePath] is null or no child key contributes
  /// anything. Missing fields are left unset on the returned [TextStyle].
  static TextStyle? textStyle(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final key = _key(basePath, suffix);
    final fontSize = doubleVal(key, 'fontSize');
    final fontWeight = _parseFontWeight(textOrNull(key, 'fontWeight'));
    final fontFamily = textOrNull(key, 'fontFamily');
    final c = color(key, 'color');
    final letterSpacing = doubleVal(key, 'letterSpacing');
    final fontStyleStr = textOrNull(key, 'fontStyle');
    final fontStyle = fontStyleStr == null
        ? null
        : (fontStyleStr == 'italic' ? FontStyle.italic : FontStyle.normal);

    if (fontSize == null &&
        fontWeight == null &&
        fontFamily == null &&
        c == null &&
        letterSpacing == null &&
        fontStyle == null) {
      return null;
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      color: c,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  // ===========================================================================
  // InputBorder Resolution
  // ===========================================================================

  /// Resolves an [InputBorder] from a sub-tree under [basePath] + [suffix].
  ///
  /// Reads:
  /// - `kind` (string: "outline" | "underline" | "none") — default "outline"
  /// - `width` (double) — default 1.0
  /// - `radius` (double) — default 4.0 (outline only)
  /// - `color` (color resolvable via [color])
  ///
  /// Returns `null` if no `kind` key is present (i.e. nothing to build).
  static InputBorder? inputBorder(String? basePath, [String suffix = '']) {
    if (basePath == null) return null;
    final key = _key(basePath, suffix);
    final kind = textOrNull(key, 'kind');
    if (kind == null) return null;
    final width = doubleVal(key, 'width') ?? 1.0;
    final c = color(key, 'color');
    final side = BorderSide(
      color: c ?? const Color(0xFF000000),
      width: width,
    );
    switch (kind) {
      case 'none':
        return InputBorder.none;
      case 'underline':
        return UnderlineInputBorder(borderSide: side);
      case 'outline':
      default:
        final radius = doubleVal(key, 'radius') ?? 4.0;
        return OutlineInputBorder(
          borderSide: side,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        );
    }
  }

  // ===========================================================================
  // WidgetStateProperty<Color> Resolution
  // ===========================================================================

  /// Resolves a [WidgetStateProperty] of [Color] from resources.
  ///
  /// Reads the flat default color at [basePath] + [suffix], and per-state
  /// overrides at sibling keys `<path>.states.<stateName>`. Recognised state
  /// names: `hovered`, `focused`, `pressed`, `selected`, `disabled`,
  /// `error`, `dragged`, `scrolledUnder`. Missing states fall back to the
  /// default.
  ///
  /// Returns `null` when neither the default nor any state override is
  /// present.
  static WidgetStateProperty<Color>? widgetStateColor(
    String? basePath, [
    String suffix = '',
  ]) {
    if (basePath == null) return null;
    final flatKey = _key(basePath, suffix);
    final defaultColor = color(flatKey);
    final statesMap = <WidgetState, Color>{};
    const stateNames = {
      'hovered': WidgetState.hovered,
      'focused': WidgetState.focused,
      'pressed': WidgetState.pressed,
      'selected': WidgetState.selected,
      'disabled': WidgetState.disabled,
      'error': WidgetState.error,
      'dragged': WidgetState.dragged,
      'scrolledUnder': WidgetState.scrolledUnder,
    };
    for (final entry in stateNames.entries) {
      final c = color('$flatKey.states', entry.key);
      if (c != null) statesMap[entry.value] = c;
    }
    if (defaultColor == null && statesMap.isEmpty) return null;
    return WidgetStateProperty.resolveWith<Color>((states) {
      for (final entry in statesMap.entries) {
        if (states.contains(entry.key)) return entry.value;
      }
      return defaultColor ?? const Color(0xFF000000);
    });
  }

  // ===========================================================================
  // Breakpointed Resolution
  // ===========================================================================

  /// Resolves a breakpointed `(value, overrides)` pair from resources.
  ///
  /// Reads the flat default at [basePath] + [suffix], and an overrides list
  /// at sibling key `<path>.breakpoints`. The overrides are expected to be a
  /// JSON array of `[minWidth, value]` pairs.
  ///
  /// [read] parses a raw value (from the default key or from a breakpoint
  /// pair's second element) into `T`. It receives the raw resource value
  /// (which may be a String, num, bool, Map, or List depending on the
  /// underlying resource). Parsers that cannot interpret a given raw value
  /// should return `null`; such entries are dropped from the overrides list.
  ///
  /// Returns `null` if [basePath] is null or neither the default nor the
  /// breakpoints key is present.
  static (T? value, List<(double, T)> overrides)? breakpointed<T>(
    String? basePath,
    T? Function(dynamic raw) read, [
    String suffix = '',
  ]) {
    if (basePath == null) return null;
    final flatKey = _key(basePath, suffix);
    final rawDefault = _provider.getObjectOrNull(flatKey);
    final rawOverrides = _provider.getObjectOrNull('$flatKey.breakpoints');
    if (rawDefault == null && rawOverrides == null) return null;

    final defaultValue = rawDefault == null ? null : read(rawDefault);
    final overrides = <(double, T)>[];
    if (rawOverrides is List) {
      for (final entry in rawOverrides) {
        if (entry is! List || entry.length < 2) continue;
        final minW = entry[0];
        if (minW is! num) continue;
        final parsed = read(entry[1]);
        if (parsed == null) continue;
        overrides.add((minW.toDouble(), parsed));
      }
      overrides.sort((a, b) => a.$1.compareTo(b.$1));
    }
    return (defaultValue, overrides);
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
  static String? childTomId(String? tomId, String suffix) {
    return tomId != null ? '$tomId.$suffix' : null;
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  static FontWeight? _parseFontWeight(String? value) {
    if (value == null) return null;
    return switch (value) {
      'w100' => FontWeight.w100,
      'w200' => FontWeight.w200,
      'w300' => FontWeight.w300,
      'w400' || 'normal' => FontWeight.w400,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
      'w700' || 'bold' => FontWeight.w700,
      'w800' => FontWeight.w800,
      'w900' => FontWeight.w900,
      _ => null,
    };
  }

  static EdgeInsets? _parseEdgeInsets(dynamic value) {
    if (value == null) return null;

    // Single number = uniform
    if (value is num) return EdgeInsets.all(value.toDouble());

    // Array format
    if (value is List) {
      if (value.length == 1 && value[0] is num) {
        return EdgeInsets.all((value[0] as num).toDouble());
      }
      if (value.length == 2 && value[0] is num && value[1] is num) {
        return EdgeInsets.symmetric(
          horizontal: (value[0] as num).toDouble(),
          vertical: (value[1] as num).toDouble(),
        );
      }
      if (value.length == 4) {
        return EdgeInsets.only(
          left: (value[0] as num?)?.toDouble() ?? 0,
          top: (value[1] as num?)?.toDouble() ?? 0,
          right: (value[2] as num?)?.toDouble() ?? 0,
          bottom: (value[3] as num?)?.toDouble() ?? 0,
        );
      }
    }

    // Map format
    if (value is Map<String, dynamic>) {
      if (value.containsKey('all')) {
        return EdgeInsets.all((value['all'] as num).toDouble());
      }
      return EdgeInsets.only(
        left: (value['left'] as num?)?.toDouble() ??
            (value['horizontal'] as num?)?.toDouble() ??
            0,
        top: (value['top'] as num?)?.toDouble() ??
            (value['vertical'] as num?)?.toDouble() ??
            0,
        right: (value['right'] as num?)?.toDouble() ??
            (value['horizontal'] as num?)?.toDouble() ??
            0,
        bottom: (value['bottom'] as num?)?.toDouble() ??
            (value['vertical'] as num?)?.toDouble() ??
            0,
      );
    }

    return null;
  }
}
