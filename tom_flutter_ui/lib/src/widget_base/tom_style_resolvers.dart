import 'dart:ui';

import 'package:flutter/material.dart';

import '../resource_auth/tom_colors.dart';
import '../resource_auth/tom_resources.dart';

/// Phase 3: Complex style resolution helpers for Tom UI widgets.
///
/// Provides resolution of complex Flutter objects (TextStyle, ButtonStyle,
/// InputDecoration) from JSON resource maps.
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
    final map = TomUIResources.resolveMap(basePath, suffix);
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
    final map = TomUIResources.resolveMap(basePath, suffix);
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
      labelText: map['labelText'] as String?,
      hintText: map['hintText'] as String?,
      helperText: map['helperText'] as String?,
      errorText: map['errorText'] as String?,
      counterText: map['counterText'] as String?,
      prefixText: map['prefixText'] as String?,
      suffixText: map['suffixText'] as String?,
      fillColor: _parseColor(map['fillColor']),
      focusColor: _parseColor(map['focusColor']),
      hoverColor: _parseColor(map['hoverColor']),
      iconColor: _parseColor(map['iconColor']),
      prefixIconColor: _parseColor(map['prefixIconColor']),
      suffixIconColor: _parseColor(map['suffixIconColor']),
      filled: map['filled'] as bool?,
      isDense: map['isDense'] as bool?,
      isCollapsed: map['isCollapsed'] as bool? ?? false,
      contentPadding: _parseEdgeInsets(map['contentPadding']),
      labelStyle: parseTextStyle(map['labelStyle'] as Map<String, dynamic>?),
      hintStyle: parseTextStyle(map['hintStyle'] as Map<String, dynamic>?),
      helperStyle: parseTextStyle(map['helperStyle'] as Map<String, dynamic>?),
      errorStyle: parseTextStyle(map['errorStyle'] as Map<String, dynamic>?),
      counterStyle:
          parseTextStyle(map['counterStyle'] as Map<String, dynamic>?),
      prefixStyle: parseTextStyle(map['prefixStyle'] as Map<String, dynamic>?),
      suffixStyle: parseTextStyle(map['suffixStyle'] as Map<String, dynamic>?),
    );
  }

  /// Resolves an [InputDecoration] from resources at [basePath].[suffix].
  static InputDecoration? resolveInputDecoration(
      String basePath, String suffix) {
    final map = TomUIResources.resolveMap(basePath, suffix);
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
    final map = TomUIResources.resolveMap(basePath, suffix);
    return parseMenuStyle(map);
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
    if (value == null) return null;
    final style = parseTextStyle(value as Map<String, dynamic>);
    if (style == null) return null;
    return WidgetStatePropertyAll<TextStyle?>(style);
  }
}
