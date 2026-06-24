import 'package:flutter/material.dart';

import '../resource_auth/tom_colors.dart';
import 'tom_construction_helpers.dart';

/// Phase 3: Complex style resolution helpers for Tom UI widgets.
///
/// Provides resolution of complex Flutter objects (TextStyle, ButtonStyle,
/// InputDecoration, MenuStyle, ShapeBorder, BorderRadius, Decoration,
/// BoxConstraints, AlignmentGeometry, BorderSide, Offset, TableBorder)
/// from JSON resource maps.
///
/// These helpers are separate from [TomNodeBase] because they require
/// Material library imports.
///
/// Usage in widgets:
/// ```dart
/// final style = this.style ?? resolveButtonStyleOrNull(context, 'style');
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
  /// Returns `null` if no map is found or parsing fails.
  static TextStyle? parseTextStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return TextStyle(
      fontSize: _parseDouble(map['fontSize']),
      fontWeight: _parseFontWeight(map['fontWeight']),
      fontStyle: _parseFontStyle(map['fontStyle']),
      color: _parseColor(map['color']),
      backgroundColor: _parseColor(map['backgroundColor']),
      letterSpacing: _parseDouble(map['letterSpacing']),
      wordSpacing: _parseDouble(map['wordSpacing']),
      height: _parseDouble(map['height']),
      decoration: _parseTextDecoration(map['decoration']),
      decorationColor: _parseColor(map['decorationColor']),
      decorationStyle: _parseTextDecorationStyle(map['decorationStyle']),
      overflow: _parseTextOverflow(map['overflow']),
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
  /// Returns `null` if no map is found or parsing fails.
  static ButtonStyle? parseButtonStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return ButtonStyle(
      foregroundColor: _wrapColor(map['foregroundColor']),
      backgroundColor: _wrapColor(map['backgroundColor']),
      overlayColor: _wrapColor(map['overlayColor']),
      shadowColor: _wrapColor(map['shadowColor']),
      surfaceTintColor: _wrapColor(map['surfaceTintColor']),
      elevation: _wrapDouble(map['elevation']),
      padding: _wrapEdgeInsets(map['padding']),
      minimumSize: _wrapSize(map['minimumSize']),
      maximumSize: _wrapSize(map['maximumSize']),
      fixedSize: _wrapSize(map['fixedSize']),
      iconSize: _wrapDouble(map['iconSize']),
      iconColor: _wrapColor(map['iconColor']),
      textStyle: _wrapTextStyle(map['textStyle']),
      tapTargetSize: _parseMaterialTapTargetSize(map['tapTargetSize']),
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
  /// Returns `null` if no map is found or parsing fails.
  static InputDecoration? parseInputDecoration(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return InputDecoration(
      labelText: _asString(map['labelText']),
      hintText: _asString(map['hintText']),
      helperText: _asString(map['helperText']),
      errorText: _asString(map['errorText']),
      counterText: _asString(map['counterText']),
      prefixText: _asString(map['prefixText']),
      suffixText: _asString(map['suffixText']),
      fillColor: _parseColor(map['fillColor']),
      focusColor: _parseColor(map['focusColor']),
      hoverColor: _parseColor(map['hoverColor']),
      iconColor: _parseColor(map['iconColor']),
      prefixIconColor: _parseColor(map['prefixIconColor']),
      suffixIconColor: _parseColor(map['suffixIconColor']),
      filled: _asBool(map['filled']),
      isDense: _asBool(map['isDense']),
      isCollapsed: _asBool(map['isCollapsed']) ?? false,
      contentPadding: _parseEdgeInsets(map['contentPadding']),
      labelStyle: parseTextStyle(_asStringMap(map['labelStyle'])),
      hintStyle: parseTextStyle(_asStringMap(map['hintStyle'])),
      helperStyle: parseTextStyle(_asStringMap(map['helperStyle'])),
      errorStyle: parseTextStyle(_asStringMap(map['errorStyle'])),
      counterStyle: parseTextStyle(_asStringMap(map['counterStyle'])),
      prefixStyle: parseTextStyle(_asStringMap(map['prefixStyle'])),
      suffixStyle: parseTextStyle(_asStringMap(map['suffixStyle'])),
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
  /// Returns `null` if no map is found or parsing fails.
  static MenuStyle? parseMenuStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return MenuStyle(
      backgroundColor: _wrapColor(map['backgroundColor']),
      shadowColor: _wrapColor(map['shadowColor']),
      surfaceTintColor: _wrapColor(map['surfaceTintColor']),
      elevation: _wrapDouble(map['elevation']),
      padding: _wrapEdgeInsets(map['padding']),
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
  /// Returns `null` if no map is found or parsing fails.
  static ShapeBorder? parseShapeBorder(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final type = _asString(map['type'])?.toLowerCase() ?? 'rounded';
    final side = parseBorderSide(_asStringMap(map['side'])) ??
        BorderSide.none;

    switch (type) {
      case 'stadium':
        return StadiumBorder(side: side);
      case 'circle':
        return CircleBorder(side: side);
      case 'beveled':
        return BeveledRectangleBorder(
          borderRadius: parseBorderRadius(map['borderRadius']) ??
              BorderRadius.zero,
          side: side,
        );
      case 'continuous':
        return ContinuousRectangleBorder(
          borderRadius: parseBorderRadius(map['borderRadius']) ??
              BorderRadius.zero,
          side: side,
        );
      case 'rounded':
      default:
        return RoundedRectangleBorder(
          borderRadius: parseBorderRadius(map['borderRadius']) ??
              BorderRadius.zero,
          side: side,
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
  /// Returns `null` if no map is found or parsing fails.
  static BorderSide? parseBorderSide(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return BorderSide(
      color: _parseColor(map['color']) ?? const Color(0xFF000000),
      width: _parseDouble(map['width']) ?? 1.0,
      style: _parseBorderStyle(map['style']),
      strokeAlign: _parseDouble(map['strokeAlign']) ?? BorderSide.strokeAlignInside,
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
  /// Returns `null` if value is null or parsing fails.
  static BorderRadius? parseBorderRadius(dynamic value) {
    if (value == null) return null;

    // Single number = uniform circular
    if (value is num) return BorderRadius.circular(value.toDouble());

    if (value is Map<String, dynamic>) {
      final all = _asNum(value['all']);
      if (all != null) return BorderRadius.circular(all.toDouble());
      return BorderRadius.only(
        topLeft: Radius.circular(
            _asNum(value['topLeft'])?.toDouble() ?? 0),
        topRight: Radius.circular(
            _asNum(value['topRight'])?.toDouble() ?? 0),
        bottomLeft: Radius.circular(
            _asNum(value['bottomLeft'])?.toDouble() ?? 0),
        bottomRight: Radius.circular(
            _asNum(value['bottomRight'])?.toDouble() ?? 0),
      );
    }

    return null;
  }

  /// Resolves a [BorderRadius] from resources at [basePath].[suffix].
  static BorderRadius? resolveBorderRadius(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null) return null;
    // If the map has a simple 'radius' key, treat as uniform
    if (map.containsKey('radius')) {
      return parseBorderRadius(map['radius']);
    }
    return parseBorderRadius(map);
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
  /// Returns `null` if no map is found or parsing fails.
  static Decoration? parseDecoration(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    final shapeStr = _asString(map['shape'])?.toLowerCase() ?? 'rectangle';

    return BoxDecoration(
      color: _parseColor(map['color']),
      borderRadius:
          shapeStr == 'circle' ? null : parseBorderRadius(map['borderRadius']),
      shape: shapeStr == 'circle' ? BoxShape.circle : BoxShape.rectangle,
      border: _parseBoxBorder(map['border']),
      boxShadow: _parseBoxShadowList(map['boxShadow']),
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
  /// Returns `null` if no map is found or parsing fails.
  static BoxConstraints? parseBoxConstraints(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return BoxConstraints(
      minWidth: _parseDouble(map['minWidth']) ?? 0.0,
      maxWidth: _parseDouble(map['maxWidth']) ?? double.infinity,
      minHeight: _parseDouble(map['minHeight']) ?? 0.0,
      maxHeight: _parseDouble(map['maxHeight']) ?? double.infinity,
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
  /// Returns `null` if value is null or parsing fails.
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
  static AlignmentGeometry? resolveAlignment(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null) return null;
    // Support both direct value and nested 'alignment' key
    if (map.containsKey('alignment')) {
      return parseAlignment(map['alignment']);
    }
    return parseAlignment(map);
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
  /// Returns `null` if value is null or parsing fails.
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
  static Offset? resolveOffset(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null) return null;
    return parseOffset(map);
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
  /// Returns `null` if no map is found or parsing fails.
  static TableBorder? parseTableBorder(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    // Shorthand: 'all' applies to every side
    if (map.containsKey('all')) {
      final side =
          parseBorderSide(_asStringMap(map['all'])) ?? BorderSide.none;
      return TableBorder(
        top: side,
        right: side,
        bottom: side,
        left: side,
        horizontalInside: side,
        verticalInside: side,
      );
    }

    return TableBorder(
      top: parseBorderSide(_asStringMap(map['top'])) ?? BorderSide.none,
      right: parseBorderSide(_asStringMap(map['right'])) ?? BorderSide.none,
      bottom: parseBorderSide(_asStringMap(map['bottom'])) ?? BorderSide.none,
      left: parseBorderSide(_asStringMap(map['left'])) ?? BorderSide.none,
      horizontalInside:
          parseBorderSide(_asStringMap(map['horizontalInside'])) ??
              BorderSide.none,
      verticalInside: parseBorderSide(_asStringMap(map['verticalInside'])) ??
          BorderSide.none,
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
  /// Returns `null` if value is null or parsing fails.
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
      final h = _parseDouble(value['horizontal']) ?? 0.0;
      final v = _parseDouble(value['vertical']) ?? 0.0;
      return VisualDensity(horizontal: h, vertical: v);
    }

    return null;
  }

  /// Resolves a [VisualDensity] from resources at [basePath].[suffix].
  static VisualDensity? resolveVisualDensity(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null) return null;
    if (map.containsKey('visualDensity')) {
      return parseVisualDensity(map['visualDensity']);
    }
    return parseVisualDensity(map);
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
  /// Returns `null` if no map is found or parsing fails.
  static IconThemeData? parseIconThemeData(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return IconThemeData(
      color: _parseColor(map['color']),
      opacity: _parseDouble(map['opacity']),
      size: _parseDouble(map['size']),
      fill: _parseDouble(map['fill']),
      weight: _parseDouble(map['weight']),
      grade: _parseDouble(map['grade']),
      opticalSize: _parseDouble(map['opticalSize']),
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
  /// Returns `null` if no map is found or parsing fails.
  static StrutStyle? parseStrutStyle(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;

    return StrutStyle(
      fontFamily: _asString(map['fontFamily']),
      fontFamilyFallback:
          _asList(map['fontFamilyFallback'])?.whereType<String>().toList(),
      fontSize: _parseDouble(map['fontSize']),
      height: _parseDouble(map['height']),
      leading: _parseDouble(map['leading']),
      fontWeight: _parseFontWeight(map['fontWeight']),
      fontStyle: _parseFontStyle(map['fontStyle']),
      forceStrutHeight: _asBool(map['forceStrutHeight']),
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
  /// Returns `null` if no map is found or parsing fails.
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

    return TextHeightBehavior(
      applyHeightToFirstAscent:
          _asBool(map['applyHeightToFirstAscent']) ?? true,
      applyHeightToLastDescent:
          _asBool(map['applyHeightToLastDescent']) ?? true,
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
  /// Returns `null` if value is null or unrecognized.
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
  static ScrollPhysics? resolveScrollPhysics(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null) return null;
    if (map.containsKey('physics')) {
      return parseScrollPhysics(map['physics']);
    }
    return parseScrollPhysics(map['type']);
  }

  // ===========================================================================
  // Private Parsing Helpers
  // ===========================================================================

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

  static FontWeight? _parseFontWeight(dynamic value) {
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

  static BorderStyle _parseBorderStyle(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'none':
          return BorderStyle.none;
        case 'solid':
          return BorderStyle.solid;
      }
    }
    return BorderStyle.solid;
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
    final insets = _parseEdgeInsets(value);
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
