import 'package:flutter/material.dart';

import '../resource_auth/tom_colors.dart';
import 'tom_construction_helpers.dart';

/// Complex style resolution helpers for Tom UI widgets.
///
/// Provides resolution of complex Flutter objects (TextStyle, ButtonStyle,
/// InputDecoration, MenuStyle, ShapeBorder, BorderRadius, Decoration,
/// BoxConstraints, AlignmentGeometry, BorderSide, Offset, TableBorder)
/// from JSON resource maps.
///
/// Separate from [TomCtr] because of what it takes in, not what it imports.
/// Both classes import the Material library — `tom_construction_helpers.dart`
/// opens with that import too, and [TomCtr] returns `TextStyle`, `InputBorder`
/// and `WidgetStateProperty` — so imports could never have told them apart.
///
/// The boundary is the resource provider. [TomCtr] is the one place that reads
/// it, turning a `basePath` + `suffix` key into a raw value; this class turns
/// an already-decoded value into a composite Flutter object. It is the
/// *provider* dependency that runs one way, not the reference between the two
/// classes — the seventeen `resolve…` members below each make exactly one
/// `TomCtr` call and hand the result to the matching `parse…`, while no
/// `parse…` names [TomCtr] at all. That asymmetry, and not a one-way import,
/// is what lets the parsing half be tested with no resources installed.
///
/// Nineteen parsers live here; seventeen have their `resolve…` partner in this
/// class, and [parseEdgeInsets] and [parseFontWeight] are resolved by
/// [TomCtr.edgeInsets] and [TomCtr.textStyle] instead — long-established entry
/// points with call sites throughout the widget layer, so their resource route
/// stays where callers already find it. What must not return is the
/// alternative [TomCtr] used to take: a private copy of each parser, kept in
/// step by hand and already drifted apart by the time it was noticed.
///
/// Which accessor a resolver reads through follows from its parser's own
/// signature. Twelve parsers take a `Map<String, dynamic>?`, so their resolvers
/// read `TomCtr.map`. Seven take a bare `dynamic`, because a radius may be a
/// number, an alignment a name and a font weight either — [parseBorderRadius],
/// [parseAlignment], [parseOffset], [parseVisualDensity], [parseScrollPhysics]
/// and the two [TomCtr] resolves. Those read the raw value, or the scalar and
/// list forms would be documented and unreachable from a resource. Four of the
/// five with resolvers here additionally unwrap a map that carries the value
/// under the property's own name.
///
/// A new helper therefore belongs here when it assembles a Flutter object out
/// of a decoded value, and in [TomCtr] when it reaches the provider for one —
/// and in exactly one of the two, never both.
///
/// Every `parse…` returns `null` when the input contributed nothing — absent,
/// empty, or holding only keys and values it cannot use — and an object only
/// when at least one key was read. There is no third outcome — an unusable
/// entry is skipped rather than raised, so one mistyped value in a resource
/// bundle never takes down a widget build.
///
/// That distinction is what makes `parse…(map) ?? fallback` work. A map full
/// of typos yields no object, so the fallback runs; were a default-constructed
/// one returned instead, it would render plausibly — `TextStyle()` inherits
/// from the ambient theme — and the mistake would go unreported.
///
/// Usage in widgets:
/// ```dart
/// final style =
///     this.style ?? TomStyleResolvers.resolveButtonStyle(basePath, 'style');
/// ```
class TomStyleResolvers {
  TomStyleResolvers._();

  // ===========================================================================
  // TextStyle Resolution
  // ===========================================================================

  /// Resolves a [TextStyle] from a resource map.
  ///
  /// The resource map can contain:
  /// - `fontSize` (double): Font size in logical pixels
  /// - `fontWeight` (String): "normal", "bold", "w100"-"w900"
  /// - `fontStyle` (String): "normal", "italic"
  /// - `color` (String): Color name or hex value
  /// - `backgroundColor` (String): Color name or hex value
  /// - `letterSpacing` (double): Letter spacing
  /// - `wordSpacing` (double): Word spacing
  /// - `height` (double): Line height multiplier
  /// - `decoration` (String): "none", "underline", "overline", "lineThrough"
  /// - `decorationColor` (String): Color name or hex value
  /// - `decorationStyle` (String): "solid", "double", "dotted", "dashed", "wavy"
  /// - `overflow` (String): "clip", "fade", "ellipsis", "visible"
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static TextStyle? parseTextStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final fontSize = _parseDouble(map['fontSize']);
    final fontWeight = parseFontWeight(map['fontWeight']);
    final fontStyle = _parseFontStyle(map['fontStyle']);
    final color = _parseColor(map['color']);
    final backgroundColor = _parseColor(map['backgroundColor']);
    final letterSpacing = _parseDouble(map['letterSpacing']);
    final wordSpacing = _parseDouble(map['wordSpacing']);
    final height = _parseDouble(map['height']);
    final decoration = _parseTextDecoration(map['decoration']);
    final decorationColor = _parseColor(map['decorationColor']);
    final decorationStyle = _parseTextDecorationStyle(map['decorationStyle']);
    final overflow = _parseTextOverflow(map['overflow']);

    if (_nothingContributed([
      fontSize,
      fontWeight,
      fontStyle,
      color,
      backgroundColor,
      letterSpacing,
      wordSpacing,
      height,
      decoration,
      decorationColor,
      decorationStyle,
      overflow,
    ])) {
      return null;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      backgroundColor: backgroundColor,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      overflow: overflow,
    );
  }

  /// Resolves a [TextStyle] from resources at [basePath].[suffix].
  static TextStyle? resolveTextStyle(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseTextStyle(map);
  }

  // ===========================================================================
  // ButtonStyle Resolution
  // ===========================================================================

  /// Resolves a [ButtonStyle] from a resource map.
  ///
  /// The resource map can contain:
  /// - `foregroundColor` (String): Color name or hex value
  /// - `backgroundColor` (String): Color name or hex value
  /// - `overlayColor` (String): Color name or hex value
  /// - `shadowColor` (String): Color name or hex value
  /// - `surfaceTintColor` (String): Color name or hex value
  /// - `elevation` (double): Elevation value
  /// - `padding` (EdgeInsets format): Padding specification
  /// - `minimumSize` (Map): {width: double, height: double}
  /// - `maximumSize` (Map): {width: double, height: double}
  /// - `fixedSize` (Map): {width: double, height: double}
  /// - `iconSize` (double): Icon size
  /// - `iconColor` (String): Color name or hex value
  /// - `textStyle` (Map): TextStyle specification
  /// - `tapTargetSize` (String): "padded", "shrinkWrap"
  ///
  /// All color properties are wrapped in [WidgetStatePropertyAll] for simplicity.
  /// For state-dependent colors, use explicit [ButtonStyle] in code.
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static ButtonStyle? parseButtonStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final foregroundColor = _wrapColor(map['foregroundColor']);
    final backgroundColor = _wrapColor(map['backgroundColor']);
    final overlayColor = _wrapColor(map['overlayColor']);
    final shadowColor = _wrapColor(map['shadowColor']);
    final surfaceTintColor = _wrapColor(map['surfaceTintColor']);
    final elevation = _wrapDouble(map['elevation']);
    final padding = _wrapEdgeInsets(map['padding']);
    final minimumSize = _wrapSize(map['minimumSize']);
    final maximumSize = _wrapSize(map['maximumSize']);
    final fixedSize = _wrapSize(map['fixedSize']);
    final iconSize = _wrapDouble(map['iconSize']);
    final iconColor = _wrapColor(map['iconColor']);
    final textStyle = _wrapTextStyle(map['textStyle']);
    final tapTargetSize = _parseMaterialTapTargetSize(map['tapTargetSize']);

    if (_nothingContributed([
      foregroundColor,
      backgroundColor,
      overlayColor,
      shadowColor,
      surfaceTintColor,
      elevation,
      padding,
      minimumSize,
      maximumSize,
      fixedSize,
      iconSize,
      iconColor,
      textStyle,
      tapTargetSize,
    ])) {
      return null;
    }

    return ButtonStyle(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      overlayColor: overlayColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      padding: padding,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      fixedSize: fixedSize,
      iconSize: iconSize,
      iconColor: iconColor,
      textStyle: textStyle,
      tapTargetSize: tapTargetSize,
    );
  }

  /// Resolves a [ButtonStyle] from resources at [basePath].[suffix].
  static ButtonStyle? resolveButtonStyle(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseButtonStyle(map);
  }

  // ===========================================================================
  // InputDecoration Resolution
  // ===========================================================================

  /// Resolves an [InputDecoration] from a resource map.
  ///
  /// The resource map can contain:
  /// - `labelText` (String): Label text
  /// - `hintText` (String): Hint text
  /// - `helperText` (String): Helper text
  /// - `errorText` (String): Error text
  /// - `counterText` (String): Counter text
  /// - `prefixText` (String): Prefix text
  /// - `suffixText` (String): Suffix text
  /// - `fillColor` (String): Color name or hex value
  /// - `focusColor` (String): Color name or hex value
  /// - `hoverColor` (String): Color name or hex value
  /// - `iconColor` (String): Color name or hex value
  /// - `prefixIconColor` (String): Color name or hex value
  /// - `suffixIconColor` (String): Color name or hex value
  /// - `filled` (bool): Whether decoration is filled
  /// - `isDense` (bool): Whether decoration is dense
  /// - `isCollapsed` (bool): Whether decoration is collapsed
  /// - `contentPadding` (EdgeInsets format): Content padding
  /// - `labelStyle` (Map): TextStyle specification
  /// - `hintStyle` (Map): TextStyle specification
  /// - `helperStyle` (Map): TextStyle specification
  /// - `errorStyle` (Map): TextStyle specification
  /// - `counterStyle` (Map): TextStyle specification
  /// - `prefixStyle` (Map): TextStyle specification
  /// - `suffixStyle` (Map): TextStyle specification
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static InputDecoration? parseInputDecoration(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final labelText = _asString(map['labelText']);
    final hintText = _asString(map['hintText']);
    final helperText = _asString(map['helperText']);
    final errorText = _asString(map['errorText']);
    final counterText = _asString(map['counterText']);
    final prefixText = _asString(map['prefixText']);
    final suffixText = _asString(map['suffixText']);
    final fillColor = _parseColor(map['fillColor']);
    final focusColor = _parseColor(map['focusColor']);
    final hoverColor = _parseColor(map['hoverColor']);
    final iconColor = _parseColor(map['iconColor']);
    final prefixIconColor = _parseColor(map['prefixIconColor']);
    final suffixIconColor = _parseColor(map['suffixIconColor']);
    final filled = _asBool(map['filled']);
    final isDense = _asBool(map['isDense']);
    final isCollapsed = _asBool(map['isCollapsed']);
    final contentPadding = parseEdgeInsets(map['contentPadding']);
    final labelStyle = parseTextStyle(_asStringMap(map['labelStyle']));
    final hintStyle = parseTextStyle(_asStringMap(map['hintStyle']));
    final helperStyle = parseTextStyle(_asStringMap(map['helperStyle']));
    final errorStyle = parseTextStyle(_asStringMap(map['errorStyle']));
    final counterStyle = parseTextStyle(_asStringMap(map['counterStyle']));
    final prefixStyle = parseTextStyle(_asStringMap(map['prefixStyle']));
    final suffixStyle = parseTextStyle(_asStringMap(map['suffixStyle']));

    if (_nothingContributed([
      labelText,
      hintText,
      helperText,
      errorText,
      counterText,
      prefixText,
      suffixText,
      fillColor,
      focusColor,
      hoverColor,
      iconColor,
      prefixIconColor,
      suffixIconColor,
      filled,
      isDense,
      isCollapsed,
      contentPadding,
      labelStyle,
      hintStyle,
      helperStyle,
      errorStyle,
      counterStyle,
      prefixStyle,
      suffixStyle,
    ])) {
      return null;
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      counterText: counterText,
      prefixText: prefixText,
      suffixText: suffixText,
      fillColor: fillColor,
      focusColor: focusColor,
      hoverColor: hoverColor,
      iconColor: iconColor,
      prefixIconColor: prefixIconColor,
      suffixIconColor: suffixIconColor,
      filled: filled,
      isDense: isDense,
      isCollapsed: isCollapsed ?? false,
      contentPadding: contentPadding,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      helperStyle: helperStyle,
      errorStyle: errorStyle,
      counterStyle: counterStyle,
      prefixStyle: prefixStyle,
      suffixStyle: suffixStyle,
    );
  }

  /// Resolves an [InputDecoration] from resources at [basePath].[suffix].
  static InputDecoration? resolveInputDecoration(
      String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseInputDecoration(map);
  }

  // ===========================================================================
  // MenuStyle Resolution
  // ===========================================================================

  /// Resolves a [MenuStyle] from a resource map.
  ///
  /// The resource map can contain:
  /// - `backgroundColor` (String): Color name or hex value
  /// - `shadowColor` (String): Color name or hex value
  /// - `surfaceTintColor` (String): Color name or hex value
  /// - `elevation` (double): Elevation value
  /// - `padding` (EdgeInsets format): Padding specification
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static MenuStyle? parseMenuStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final backgroundColor = _wrapColor(map['backgroundColor']);
    final shadowColor = _wrapColor(map['shadowColor']);
    final surfaceTintColor = _wrapColor(map['surfaceTintColor']);
    final elevation = _wrapDouble(map['elevation']);
    final padding = _wrapEdgeInsets(map['padding']);

    if (_nothingContributed([
      backgroundColor,
      shadowColor,
      surfaceTintColor,
      elevation,
      padding,
    ])) {
      return null;
    }

    return MenuStyle(
      backgroundColor: backgroundColor,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      elevation: elevation,
      padding: padding,
    );
  }

  /// Resolves a [MenuStyle] from resources at [basePath].[suffix].
  static MenuStyle? resolveMenuStyle(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseMenuStyle(map);
  }

  // ===========================================================================
  // ShapeBorder Resolution
  // ===========================================================================

  /// Resolves a [ShapeBorder] from a resource map.
  ///
  /// The resource map can contain:
  /// - `type` (String): "rounded", "beveled", "stadium", "circle",
  ///   "continuous" (defaults to "rounded")
  /// - `borderRadius` (dynamic): BorderRadius specification
  /// - `side` (Map): BorderSide specification
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static ShapeBorder? parseShapeBorder(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    // An unrecognised name contributes nothing, exactly like an unrecognised
    // key: reading it as `rounded` would turn a typo into a real shape.
    const shapes = {'rounded', 'stadium', 'circle', 'beveled', 'continuous'};
    final name = _asString(map['type'])?.toLowerCase();
    final type = shapes.contains(name) ? name : null;
    final side = parseBorderSide(_asStringMap(map['side']));
    final borderRadius = parseBorderRadius(map['borderRadius']);

    if (_nothingContributed([type, side, borderRadius])) return null;

    final resolvedSide = side ?? BorderSide.none;
    final resolvedRadius = borderRadius ?? BorderRadius.zero;

    switch (type) {
      case 'stadium':
        return StadiumBorder(side: resolvedSide);
      case 'circle':
        return CircleBorder(side: resolvedSide);
      case 'beveled':
        return BeveledRectangleBorder(
          borderRadius: resolvedRadius,
          side: resolvedSide,
        );
      case 'continuous':
        return ContinuousRectangleBorder(
          borderRadius: resolvedRadius,
          side: resolvedSide,
        );
      case 'rounded':
      default:
        return RoundedRectangleBorder(
          borderRadius: resolvedRadius,
          side: resolvedSide,
        );
    }
  }

  /// Resolves a [ShapeBorder] from resources at [basePath].[suffix].
  static ShapeBorder? resolveShapeBorder(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseShapeBorder(map);
  }

  // ===========================================================================
  // BorderSide Resolution
  // ===========================================================================

  /// Resolves a [BorderSide] from a resource map.
  ///
  /// The resource map can contain:
  /// - `color` (String): Color name or hex value
  /// - `width` (double): Border width (default 1.0)
  /// - `style` (String): "solid" or "none"
  /// - `strokeAlign` (double): -1.0 (inside), 0.0 (center), 1.0 (outside)
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static BorderSide? parseBorderSide(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final color = _parseColor(map['color']);
    final width = _parseDouble(map['width']);
    final style = _parseBorderStyle(map['style']);
    final strokeAlign = _parseDouble(map['strokeAlign']);

    if (_nothingContributed([color, width, style, strokeAlign])) return null;

    return BorderSide(
      color: color ?? const Color(0xFF000000),
      width: width ?? 1.0,
      style: style ?? BorderStyle.solid,
      strokeAlign: strokeAlign ?? BorderSide.strokeAlignInside,
    );
  }

  /// Resolves a [BorderSide] from resources at [basePath].[suffix].
  static BorderSide? resolveBorderSide(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseBorderSide(map);
  }

  // ===========================================================================
  // BorderRadius Resolution
  // ===========================================================================

  /// Resolves a [BorderRadius] from a dynamic value.
  ///
  /// Supported formats:
  /// - Single number: uniform circular radius
  /// - Map with `topLeft`, `topRight`, `bottomLeft`, `bottomRight` (each a
  ///   number for circular radius)
  /// - Map with `all` (number for uniform circular radius)
  ///
  /// Returns `null` if the value is absent, or is a form or a map out of which
  /// nothing usable can be read — never a default-constructed object.
  static BorderRadius? parseBorderRadius(dynamic value) {
    if (value == null) return null;

    // Single number = uniform circular
    if (value is num) return BorderRadius.circular(value.toDouble());

    if (value is Map<String, dynamic>) {
      final all = _asNum(value['all']);
      if (all != null) return BorderRadius.circular(all.toDouble());

      final topLeft = _asNum(value['topLeft'])?.toDouble();
      final topRight = _asNum(value['topRight'])?.toDouble();
      final bottomLeft = _asNum(value['bottomLeft'])?.toDouble();
      final bottomRight = _asNum(value['bottomRight'])?.toDouble();

      if (_nothingContributed([topLeft, topRight, bottomLeft, bottomRight])) {
        return null;
      }

      return BorderRadius.only(
        topLeft: Radius.circular(topLeft ?? 0),
        topRight: Radius.circular(topRight ?? 0),
        bottomLeft: Radius.circular(bottomLeft ?? 0),
        bottomRight: Radius.circular(bottomRight ?? 0),
      );
    }

    return null;
  }

  /// Resolves a [BorderRadius] from resources at [basePath].[suffix].
  ///
  /// The resource may hold any form [parseBorderRadius] accepts — including a
  /// bare number — or a map carrying one of them under a `radius` key.
  static BorderRadius? resolveBorderRadius(String basePath, String suffix) {
    final value = TomCtr.value(basePath, suffix);
    // A map may carry the radius under its own name, so that a resource can
    // group it with siblings; anything else goes to the parser as it stands,
    // which is what makes the documented `radius: 8` form reachable.
    if (value is Map<String, dynamic> && value.containsKey('radius')) {
      return parseBorderRadius(value['radius']);
    }
    return parseBorderRadius(value);
  }

  // ===========================================================================
  // Decoration Resolution
  // ===========================================================================

  /// Resolves a [Decoration] (specifically [BoxDecoration]) from a resource map.
  ///
  /// The resource map can contain:
  /// - `color` (String): Color name or hex value
  /// - `borderRadius` (dynamic): BorderRadius specification
  /// - `border` (Map): Border specification with `color`, `width`
  /// - `boxShadow` (List): List of shadow maps with `color`, `blurRadius`,
  ///   `spreadRadius`, `offset`
  /// - `shape` (String): "rectangle" or "circle" (default "rectangle")
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static Decoration? parseDecoration(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    // As in `parseShapeBorder`: only a name Flutter knows counts as given.
    const shapes = {'rectangle', 'circle'};
    final shapeName = _asString(map['shape'])?.toLowerCase();
    final shape = shapes.contains(shapeName) ? shapeName : null;
    final isCircle = shape == 'circle';

    final color = _parseColor(map['color']);
    final borderRadius =
        isCircle ? null : parseBorderRadius(map['borderRadius']);
    final border = _parseBoxBorder(map['border']);
    final boxShadow = _parseBoxShadowList(map['boxShadow']);

    if (_nothingContributed([shape, color, borderRadius, border, boxShadow])) {
      return null;
    }

    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      border: border,
      boxShadow: boxShadow,
    );
  }

  /// Resolves a [Decoration] from resources at [basePath].[suffix].
  static Decoration? resolveDecoration(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseDecoration(map);
  }

  // ===========================================================================
  // BoxConstraints Resolution
  // ===========================================================================

  /// Resolves [BoxConstraints] from a resource map.
  ///
  /// The resource map can contain:
  /// - `minWidth` (double): Minimum width (default 0.0)
  /// - `maxWidth` (double): Maximum width (default infinity)
  /// - `minHeight` (double): Minimum height (default 0.0)
  /// - `maxHeight` (double): Maximum height (default infinity)
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static BoxConstraints? parseBoxConstraints(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final minWidth = _parseDouble(map['minWidth']);
    final maxWidth = _parseDouble(map['maxWidth']);
    final minHeight = _parseDouble(map['minHeight']);
    final maxHeight = _parseDouble(map['maxHeight']);

    if (_nothingContributed([minWidth, maxWidth, minHeight, maxHeight])) {
      return null;
    }

    return BoxConstraints(
      minWidth: minWidth ?? 0.0,
      maxWidth: maxWidth ?? double.infinity,
      minHeight: minHeight ?? 0.0,
      maxHeight: maxHeight ?? double.infinity,
    );
  }

  /// Resolves [BoxConstraints] from resources at [basePath].[suffix].
  static BoxConstraints? resolveBoxConstraints(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseBoxConstraints(map);
  }

  // ===========================================================================
  // AlignmentGeometry Resolution
  // ===========================================================================

  /// Resolves an [AlignmentGeometry] from a dynamic value.
  ///
  /// Supported formats:
  /// - String: named alignment ("topLeft", "center", "bottomRight", etc.)
  /// - Map: {x: double, y: double} for custom alignment
  ///
  /// Returns `null` if the value is absent, or is a form or a map out of which
  /// nothing usable can be read — never a default-constructed object.
  static AlignmentGeometry? parseAlignment(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'topleft':
        case 'top_left':
          return Alignment.topLeft;
        case 'topcenter':
        case 'top_center':
          return Alignment.topCenter;
        case 'topright':
        case 'top_right':
          return Alignment.topRight;
        case 'centerleft':
        case 'center_left':
          return Alignment.centerLeft;
        case 'center':
          return Alignment.center;
        case 'centerright':
        case 'center_right':
          return Alignment.centerRight;
        case 'bottomleft':
        case 'bottom_left':
          return Alignment.bottomLeft;
        case 'bottomcenter':
        case 'bottom_center':
          return Alignment.bottomCenter;
        case 'bottomright':
        case 'bottom_right':
          return Alignment.bottomRight;
      }
    }

    if (value is Map<String, dynamic>) {
      final x = _parseDouble(value['x']);
      final y = _parseDouble(value['y']);
      if (x != null && y != null) return Alignment(x, y);
    }

    return null;
  }

  /// Resolves an [AlignmentGeometry] from resources at [basePath].[suffix].
  ///
  /// The resource may hold any form [parseAlignment] accepts — including a
  /// name such as `topLeft` — or a map carrying one of them under an
  /// `alignment` key.
  static AlignmentGeometry? resolveAlignment(String basePath, String suffix) {
    final value = TomCtr.value(basePath, suffix);
    if (value is Map<String, dynamic> && value.containsKey('alignment')) {
      return parseAlignment(value['alignment']);
    }
    return parseAlignment(value);
  }

  // ===========================================================================
  // Offset Resolution
  // ===========================================================================

  /// Resolves an [Offset] from a dynamic value.
  ///
  /// Supported formats:
  /// - Map: {dx: double, dy: double} or {x: double, y: double}
  /// - List: [dx, dy]
  ///
  /// Returns `null` if the value is absent, or is a form or a map out of which
  /// nothing usable can be read — never a default-constructed object.
  static Offset? parseOffset(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      final dx = _parseDouble(value['dx'] ?? value['x']);
      final dy = _parseDouble(value['dy'] ?? value['y']);
      if (dx != null && dy != null) return Offset(dx, dy);
    }

    if (value is List && value.length == 2) {
      final dx = _parseDouble(value[0]);
      final dy = _parseDouble(value[1]);
      if (dx != null && dy != null) return Offset(dx, dy);
    }

    return null;
  }

  /// Resolves an [Offset] from resources at [basePath].[suffix].
  ///
  /// The resource may hold any form [parseOffset] accepts — including a
  /// two-element list such as `[3, 4]`. Alone among the five raw-value
  /// resolvers it unwraps no key, because `{dx, dy}` is already one of those
  /// forms rather than a wrapper around one.
  static Offset? resolveOffset(String basePath, String suffix) {
    return parseOffset(TomCtr.value(basePath, suffix));
  }

  // ===========================================================================
  // TableBorder Resolution
  // ===========================================================================

  /// Resolves a [TableBorder] from a resource map.
  ///
  /// The resource map can contain:
  /// - `top`, `right`, `bottom`, `left` (Map): BorderSide specifications
  /// - `horizontalInside`, `verticalInside` (Map): BorderSide specifications
  /// - `all` (Map): Uniform BorderSide for all sides
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static TableBorder? parseTableBorder(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    // Shorthand: 'all' applies to every side
    final all = parseBorderSide(_asStringMap(map['all']));
    if (all != null) {
      return TableBorder(
        top: all,
        right: all,
        bottom: all,
        left: all,
        horizontalInside: all,
        verticalInside: all,
      );
    }

    final top = parseBorderSide(_asStringMap(map['top']));
    final right = parseBorderSide(_asStringMap(map['right']));
    final bottom = parseBorderSide(_asStringMap(map['bottom']));
    final left = parseBorderSide(_asStringMap(map['left']));
    final horizontalInside =
        parseBorderSide(_asStringMap(map['horizontalInside']));
    final verticalInside =
        parseBorderSide(_asStringMap(map['verticalInside']));

    if (_nothingContributed(
        [top, right, bottom, left, horizontalInside, verticalInside])) {
      return null;
    }

    return TableBorder(
      top: top ?? BorderSide.none,
      right: right ?? BorderSide.none,
      bottom: bottom ?? BorderSide.none,
      left: left ?? BorderSide.none,
      horizontalInside: horizontalInside ?? BorderSide.none,
      verticalInside: verticalInside ?? BorderSide.none,
    );
  }

  /// Resolves a [TableBorder] from resources at [basePath].[suffix].
  static TableBorder? resolveTableBorder(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseTableBorder(map);
  }

  // ===========================================================================
  // VisualDensity Resolution
  // ===========================================================================

  /// Resolves a [VisualDensity] from a resource map or string.
  ///
  /// Supported formats:
  /// - String: "comfortable", "compact", "standard", "adaptivePlatformDensity"
  /// - Map: {horizontal: double, vertical: double}
  ///
  /// Returns `null` if the value is absent, or is a form or a map out of which
  /// nothing usable can be read — never a default-constructed object.
  static VisualDensity? parseVisualDensity(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'comfortable':
          return VisualDensity.comfortable;
        case 'compact':
          return VisualDensity.compact;
        case 'standard':
          return VisualDensity.standard;
        case 'adaptiveplatformdensity':
          return VisualDensity.adaptivePlatformDensity;
      }
      return null;
    }

    if (value is Map<String, dynamic>) {
      final h = _parseDouble(value['horizontal']);
      final v = _parseDouble(value['vertical']);
      if (_nothingContributed([h, v])) return null;
      return VisualDensity(horizontal: h ?? 0.0, vertical: v ?? 0.0);
    }

    return null;
  }

  /// Resolves a [VisualDensity] from resources at [basePath].[suffix].
  ///
  /// The resource may hold any form [parseVisualDensity] accepts — including a
  /// name such as `compact` — or a map carrying one of them under a
  /// `visualDensity` key.
  static VisualDensity? resolveVisualDensity(String basePath, String suffix) {
    final value = TomCtr.value(basePath, suffix);
    if (value is Map<String, dynamic> && value.containsKey('visualDensity')) {
      return parseVisualDensity(value['visualDensity']);
    }
    return parseVisualDensity(value);
  }

  // ===========================================================================
  // IconThemeData Resolution
  // ===========================================================================

  /// Resolves an [IconThemeData] from a resource map.
  ///
  /// The resource map can contain:
  /// - `color` (String): Color name or hex value
  /// - `opacity` (double): Opacity value (0.0 - 1.0)
  /// - `size` (double): Icon size in logical pixels
  /// - `fill` (double): Fill value (0.0 - 1.0)
  /// - `weight` (double): Icon weight
  /// - `grade` (double): Icon grade
  /// - `opticalSize` (double): Optical size
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static IconThemeData? parseIconThemeData(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final color = _parseColor(map['color']);
    final opacity = _parseDouble(map['opacity']);
    final size = _parseDouble(map['size']);
    final fill = _parseDouble(map['fill']);
    final weight = _parseDouble(map['weight']);
    final grade = _parseDouble(map['grade']);
    final opticalSize = _parseDouble(map['opticalSize']);

    if (_nothingContributed(
        [color, opacity, size, fill, weight, grade, opticalSize])) {
      return null;
    }

    return IconThemeData(
      color: color,
      opacity: opacity,
      size: size,
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
    );
  }

  /// Resolves an [IconThemeData] from resources at [basePath].[suffix].
  static IconThemeData? resolveIconThemeData(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseIconThemeData(map);
  }

  // ===========================================================================
  // StrutStyle Resolution
  // ===========================================================================

  /// Resolves a [StrutStyle] from a resource map.
  ///
  /// The resource map can contain:
  /// - `fontFamily` (String): Font family name
  /// - `fontFamilyFallback` (`List<String>`): Fallback font families
  /// - `fontSize` (double): Font size in logical pixels
  /// - `height` (double): Line height multiplier
  /// - `leading` (double): Leading distribution
  /// - `fontWeight` (String): "normal", "bold", "w100"-"w900"
  /// - `fontStyle` (String): "normal", "italic"
  /// - `forceStrutHeight` (bool): Whether to force strut height
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static StrutStyle? parseStrutStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final fontFamily = _asString(map['fontFamily']);
    final fontFamilyFallback =
        _asList(map['fontFamilyFallback'])?.whereType<String>().toList();
    final fontSize = _parseDouble(map['fontSize']);
    final height = _parseDouble(map['height']);
    final leading = _parseDouble(map['leading']);
    final fontWeight = parseFontWeight(map['fontWeight']);
    final fontStyle = _parseFontStyle(map['fontStyle']);
    final forceStrutHeight = _asBool(map['forceStrutHeight']);

    if (_nothingContributed([
      fontFamily,
      fontFamilyFallback,
      fontSize,
      height,
      leading,
      fontWeight,
      fontStyle,
      forceStrutHeight,
    ])) {
      return null;
    }

    return StrutStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      height: height,
      leading: leading,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      forceStrutHeight: forceStrutHeight,
    );
  }

  /// Resolves a [StrutStyle] from resources at [basePath].[suffix].
  static StrutStyle? resolveStrutStyle(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseStrutStyle(map);
  }

  // ===========================================================================
  // TextHeightBehavior Resolution
  // ===========================================================================

  /// Resolves a [TextHeightBehavior] from a resource map or string.
  ///
  /// The resource map can contain:
  /// - `applyHeightToFirstAscent` (bool): Apply height to first ascent (default true)
  /// - `applyHeightToLastDescent` (bool): Apply height to last descent (default true)
  /// - `leadingDistribution` (String): "proportional" or "even"
  ///
  /// Returns `null` if the map is absent, empty, or contains no key this
  /// parser can use — never a default-constructed object.
  static TextHeightBehavior? parseTextHeightBehavior(
      Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    TextLeadingDistribution? leadingDistribution;
    final ld = _asString(map['leadingDistribution']);
    if (ld != null) {
      switch (ld.toLowerCase()) {
        case 'proportional':
          leadingDistribution = TextLeadingDistribution.proportional;
          break;
        case 'even':
          leadingDistribution = TextLeadingDistribution.even;
          break;
      }
    }

    final applyHeightToFirstAscent = _asBool(map['applyHeightToFirstAscent']);
    final applyHeightToLastDescent = _asBool(map['applyHeightToLastDescent']);

    if (_nothingContributed([
      applyHeightToFirstAscent,
      applyHeightToLastDescent,
      leadingDistribution,
    ])) {
      return null;
    }

    return TextHeightBehavior(
      applyHeightToFirstAscent: applyHeightToFirstAscent ?? true,
      applyHeightToLastDescent: applyHeightToLastDescent ?? true,
      leadingDistribution:
          leadingDistribution ?? TextLeadingDistribution.proportional,
    );
  }

  /// Resolves a [TextHeightBehavior] from resources at [basePath].[suffix].
  static TextHeightBehavior? resolveTextHeightBehavior(
      String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    return parseTextHeightBehavior(map);
  }

  // ===========================================================================
  // ScrollPhysics Resolution
  // ===========================================================================

  /// Resolves a [ScrollPhysics] from a string name.
  ///
  /// Supported values:
  /// - "bouncing" / "bouncingScroll": [BouncingScrollPhysics]
  /// - "clamping" / "clampingScroll": [ClampingScrollPhysics]
  /// - "never" / "neverScrollable": [NeverScrollableScrollPhysics]
  /// - "always" / "alwaysScrollable": [AlwaysScrollableScrollPhysics]
  /// - "page": [PageScrollPhysics]
  /// - "fixedExtent": [FixedExtentScrollPhysics]
  ///
  /// Returns `null` if the value is absent or names no physics this parser
  /// knows.
  static ScrollPhysics? parseScrollPhysics(dynamic value) {
    if (value == null) return null;

    final name = (value is String) ? value : (value is Map<String, dynamic>)
        ? _asString(value['type'])
        : null;
    if (name == null) return null;

    switch (name.toLowerCase()) {
      case 'bouncing':
      case 'bouncingscroll':
        return const BouncingScrollPhysics();
      case 'clamping':
      case 'clampingscroll':
        return const ClampingScrollPhysics();
      case 'never':
      case 'neverscrollable':
        return const NeverScrollableScrollPhysics();
      case 'always':
      case 'alwaysscrollable':
        return const AlwaysScrollableScrollPhysics();
      case 'page':
        return const PageScrollPhysics();
      case 'fixedextent':
        return const FixedExtentScrollPhysics();
    }
    return null;
  }

  /// Resolves a [ScrollPhysics] from resources at [basePath].[suffix].
  ///
  /// The resource may hold any form [parseScrollPhysics] accepts — including a
  /// name such as `bouncing` — or a map carrying one of them under a `physics`
  /// key.
  static ScrollPhysics? resolveScrollPhysics(String basePath, String suffix) {
    final value = TomCtr.value(basePath, suffix);
    if (value is Map<String, dynamic> && value.containsKey('physics')) {
      return parseScrollPhysics(value['physics']);
    }
    // The `{type: …}` form needs no unwrapping here: [parseScrollPhysics]
    // reads that key itself, so handing it the map covers both.
    return parseScrollPhysics(value);
  }

  // ===========================================================================
  // Parsers whose resolver lives in TomCtr
  // ===========================================================================
  //
  // These two are public for the same reason the seventeen above are: something
  // outside this class reads the resource and needs the parsing half. The
  // difference is only where that reader sits — `TomCtr.edgeInsets` and
  // `TomCtr.textStyle` are long-established entry points with call sites across
  // every widget file, so their resource route stays in `TomCtr` rather than
  // moving here as an eighteenth `resolve…`.
  //
  // What must not happen is the alternative `TomCtr` used to take: its own
  // private copy of each. `style_resolvers_layering_test.dart` fails if any
  // name is declared in both classes.

  /// Parses [EdgeInsets] from a decoded resource value.
  ///
  /// Accepts a number for uniform insets; a list of `[all]`,
  /// `[horizontal, vertical]` or `[left, top, right, bottom]`; or a map with an
  /// `all` key, or any of `horizontal` / `vertical` / `left` / `top` / `right`
  /// / `bottom`, where a side falls back to its axis and then to zero.
  ///
  /// Returns `null` if the value is absent or is a form out of which nothing
  /// usable can be read — never a default-constructed object.
  ///
  /// [TomCtr.edgeInsets] is the resource route to this parser.
  static EdgeInsets? parseEdgeInsets(dynamic value) {
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
          left: _asNum(value[0])?.toDouble() ?? 0,
          top: _asNum(value[1])?.toDouble() ?? 0,
          right: _asNum(value[2])?.toDouble() ?? 0,
          bottom: _asNum(value[3])?.toDouble() ?? 0,
        );
      }
    }

    // Map format
    if (value is Map<String, dynamic>) {
      final all = _asNum(value['all']);
      if (all != null) return EdgeInsets.all(all.toDouble());
      return EdgeInsets.only(
        left: _asNum(value['left'])?.toDouble() ??
            _asNum(value['horizontal'])?.toDouble() ??
            0,
        top: _asNum(value['top'])?.toDouble() ??
            _asNum(value['vertical'])?.toDouble() ??
            0,
        right: _asNum(value['right'])?.toDouble() ??
            _asNum(value['horizontal'])?.toDouble() ??
            0,
        bottom: _asNum(value['bottom'])?.toDouble() ??
            _asNum(value['vertical'])?.toDouble() ??
            0,
      );
    }

    return null;
  }

  /// Parses a [FontWeight] from a decoded resource value.
  ///
  /// Accepts the names `normal` and `bold` and `w100`…`w900` in any case, and
  /// the integers `100`…`900`.
  ///
  /// Returns `null` if the value is absent or names no weight this parser
  /// knows.
  ///
  /// [TomCtr.textStyle] is the resource route to this parser; the map route is
  /// [parseTextStyle]'s `fontWeight` key.
  static FontWeight? parseFontWeight(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'normal':
          return FontWeight.normal;
        case 'bold':
          return FontWeight.bold;
        case 'w100':
          return FontWeight.w100;
        case 'w200':
          return FontWeight.w200;
        case 'w300':
          return FontWeight.w300;
        case 'w400':
          return FontWeight.w400;
        case 'w500':
          return FontWeight.w500;
        case 'w600':
          return FontWeight.w600;
        case 'w700':
          return FontWeight.w700;
        case 'w800':
          return FontWeight.w800;
        case 'w900':
          return FontWeight.w900;
      }
    }
    if (value is int) {
      switch (value) {
        case 100:
          return FontWeight.w100;
        case 200:
          return FontWeight.w200;
        case 300:
          return FontWeight.w300;
        case 400:
          return FontWeight.w400;
        case 500:
          return FontWeight.w500;
        case 600:
          return FontWeight.w600;
        case 700:
          return FontWeight.w700;
        case 800:
          return FontWeight.w800;
        case 900:
          return FontWeight.w900;
      }
    }
    return null;
  }

  // ===========================================================================
  // Private Parsing Helpers
  // ===========================================================================

  /// Whether a map yielded nothing a parser could use.
  ///
  /// Pass the parsed values, not the raw map entries: every helper in this
  /// class returns `null` for a key that is absent, unrecognised *or* present
  /// with an unusable value, so an all-`null` list means the map contributed
  /// nothing however it came to be wrong. Checking raw key presence instead
  /// would let `{'fontSize': 'large'}` through as "specified".
  ///
  /// A parser that returned its object anyway would hand back one built
  /// entirely from Flutter's defaults, which the caller cannot tell from a
  /// deliberate style — [TomCtr.textStyle] answers the same question the same
  /// way for the resource-tree half of the module.
  static bool _nothingContributed(List<Object?> values) =>
      values.every((value) => value == null);

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // ===========================================================================
  // Tolerant type guards (bug §77)
  // ===========================================================================
  //
  // The resolvers advertise a tolerant contract (doc/widget_base.md): a
  // present-but-wrong-type config entry is skipped (treated as absent) rather
  // than throwing a CastError. These guards return null for a wrong-type value
  // instead of casting unchecked — the genuine mirror of the nullable `as num?`
  // array path and the `_parseDouble` / `_parseColor` helpers above. Resource
  // maps are typically loaded from config, so one mistyped entry must not take
  // down the whole widget build.

  static String? _asString(dynamic value) => value is String ? value : null;

  static bool? _asBool(dynamic value) => value is bool ? value : null;

  static num? _asNum(dynamic value) => value is num ? value : null;

  static Map<String, dynamic>? _asStringMap(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  static List<dynamic>? _asList(dynamic value) => value is List ? value : null;

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String) return TomUIColors.resolveColor(value);
    if (value is int) return Color(value);
    return null;
  }

  static FontStyle? _parseFontStyle(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'normal':
          return FontStyle.normal;
        case 'italic':
          return FontStyle.italic;
      }
    }
    return null;
  }

  static TextDecoration? _parseTextDecoration(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'none':
          return TextDecoration.none;
        case 'underline':
          return TextDecoration.underline;
        case 'overline':
          return TextDecoration.overline;
        case 'linethrough':
        case 'line-through':
        case 'strikethrough':
          return TextDecoration.lineThrough;
      }
    }
    return null;
  }

  static TextDecorationStyle? _parseTextDecorationStyle(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'solid':
          return TextDecorationStyle.solid;
        case 'double':
          return TextDecorationStyle.double;
        case 'dotted':
          return TextDecorationStyle.dotted;
        case 'dashed':
          return TextDecorationStyle.dashed;
        case 'wavy':
          return TextDecorationStyle.wavy;
      }
    }
    return null;
  }

  static TextOverflow? _parseTextOverflow(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'clip':
          return TextOverflow.clip;
        case 'fade':
          return TextOverflow.fade;
        case 'ellipsis':
          return TextOverflow.ellipsis;
        case 'visible':
          return TextOverflow.visible;
      }
    }
    return null;
  }

  static MaterialTapTargetSize? _parseMaterialTapTargetSize(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'padded':
          return MaterialTapTargetSize.padded;
        case 'shrinkwrap':
        case 'shrink_wrap':
          return MaterialTapTargetSize.shrinkWrap;
      }
    }
    return null;
  }

  /// Nullable like every other helper here, so [_nothingContributed] can see
  /// that an absent or unrecognised `style` contributed nothing. The caller
  /// applies Flutter's own `BorderStyle.solid` default.
  static BorderStyle? _parseBorderStyle(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'none':
          return BorderStyle.none;
        case 'solid':
          return BorderStyle.solid;
      }
    }
    return null;
  }

  static BoxBorder? _parseBoxBorder(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      // Shorthand: uniform border
      if (value.containsKey('color') || value.containsKey('width')) {
        final side = parseBorderSide(value) ?? BorderSide.none;
        return Border.fromBorderSide(side);
      }
      // Per-side borders
      return Border(
        top: parseBorderSide(_asStringMap(value['top'])) ?? BorderSide.none,
        right:
            parseBorderSide(_asStringMap(value['right'])) ?? BorderSide.none,
        bottom:
            parseBorderSide(_asStringMap(value['bottom'])) ?? BorderSide.none,
        left: parseBorderSide(_asStringMap(value['left'])) ?? BorderSide.none,
      );
    }
    return null;
  }

  static List<BoxShadow>? _parseBoxShadowList(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    return value
        .whereType<Map<String, dynamic>>()
        .map((shadow) => BoxShadow(
              color: _parseColor(shadow['color']) ??
                  const Color(0xFF000000),
              blurRadius: _parseDouble(shadow['blurRadius']) ?? 0.0,
              spreadRadius: _parseDouble(shadow['spreadRadius']) ?? 0.0,
              offset: parseOffset(shadow['offset']) ?? Offset.zero,
            ))
        .toList();
  }

  static Size? _parseSize(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final width = _parseDouble(value['width']) ?? double.infinity;
      final height = _parseDouble(value['height']) ?? double.infinity;
      return Size(width, height);
    }
    return null;
  }

  // ===========================================================================
  // WidgetStatePropertyAll Wrappers
  // ===========================================================================

  static WidgetStateProperty<Color?>? _wrapColor(dynamic value) {
    final color = _parseColor(value);
    if (color == null) return null;
    return WidgetStatePropertyAll<Color?>(color);
  }

  static WidgetStateProperty<double?>? _wrapDouble(dynamic value) {
    final val = _parseDouble(value);
    if (val == null) return null;
    return WidgetStatePropertyAll<double?>(val);
  }

  static WidgetStateProperty<EdgeInsetsGeometry?>? _wrapEdgeInsets(
      dynamic value) {
    final insets = parseEdgeInsets(value);
    if (insets == null) return null;
    return WidgetStatePropertyAll<EdgeInsetsGeometry?>(insets);
  }

  static WidgetStateProperty<Size?>? _wrapSize(dynamic value) {
    final size = _parseSize(value);
    if (size == null) return null;
    return WidgetStatePropertyAll<Size?>(size);
  }

  static WidgetStateProperty<TextStyle?>? _wrapTextStyle(dynamic value) {
    final style = parseTextStyle(_asStringMap(value));
    if (style == null) return null;
    return WidgetStatePropertyAll<TextStyle?>(style);
  }
}
