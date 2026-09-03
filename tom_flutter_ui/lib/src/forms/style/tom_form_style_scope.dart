library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../resource_auth/tom_colors.dart';
import 'form_style_enums.dart';
import 'tom_breakpoint.dart';
import 'tom_color_tokens.dart';
import 'tom_form_style.dart';
import 'tom_theme_spec.dart';

// ---------------------------------------------------------------------------
// Deferred color/style holders — store raw strings at parse time, resolve
// tokens against a live ColorScheme at build time.
// ---------------------------------------------------------------------------

/// A TextStyle where the color may be a `cs.*` token resolved at runtime.
class _OverlayTextStyle {
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final double? letterSpacing;
  final FontStyle? fontStyle;
  // Hex "#RRGGBB" or alpha-first "#AARRGGBB", named "mRed", or "cs.primary".
  final String? colorRaw;

  const _OverlayTextStyle({
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.letterSpacing,
    this.fontStyle,
    this.colorRaw,
  });

  bool get isEmpty =>
      fontSize == null &&
      fontWeight == null &&
      fontFamily == null &&
      letterSpacing == null &&
      fontStyle == null &&
      colorRaw == null;

  TextStyle? resolve(ColorScheme cs) {
    if (isEmpty) return null;
    final color = colorRaw == null
        ? null
        : resolveAnyColor(colorRaw!, cs, TomUIColors.resolveColor);
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      color: color,
    );
  }

  static _OverlayTextStyle? fromResources(String block, String suffix) {
    final key = suffix.isEmpty ? block : '$block.$suffix';
    final fontSize = TomCtr.doubleVal(key, 'fontSize');
    final fontWeight = _parseFontWeight(TomCtr.textOrNull(key, 'fontWeight'));
    final fontFamily = TomCtr.textOrNull(key, 'fontFamily');
    final letterSpacing = TomCtr.doubleVal(key, 'letterSpacing');
    final fontStyleRaw = TomCtr.textOrNull(key, 'fontStyle');
    final fontStyle = fontStyleRaw == null
        ? null
        : (fontStyleRaw == 'italic' ? FontStyle.italic : FontStyle.normal);
    final colorRaw = TomCtr.textOrNull(key, 'color');

    final ts = _OverlayTextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      colorRaw: colorRaw,
    );
    return ts.isEmpty ? null : ts;
  }
}

/// An InputBorder where the stroke color may be a `cs.*` token.
class _OverlayBorder {
  final String kind;
  final double width;
  final String? colorRaw;
  final double radius;

  const _OverlayBorder({
    required this.kind,
    required this.width,
    this.colorRaw,
    required this.radius,
  });

  InputBorder resolve(ColorScheme cs) {
    final color = colorRaw == null
        ? Colors.black
        : (resolveAnyColor(colorRaw!, cs, TomUIColors.resolveColor) ??
              Colors.black);
    final side = BorderSide(color: color, width: width);
    switch (kind.toLowerCase()) {
      case 'none':
        return InputBorder.none;
      case 'underline':
        return UnderlineInputBorder(borderSide: side);
      default:
        return OutlineInputBorder(
          borderSide: side,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        );
    }
  }

  static _OverlayBorder? fromResources(String block, String suffix) {
    final key = suffix.isEmpty ? block : '$block.$suffix';
    final kind = TomCtr.textOrNull(key, 'kind');
    if (kind == null) return null;
    return _OverlayBorder(
      kind: kind,
      width: TomCtr.doubleVal(key, 'width') ?? 1.0,
      colorRaw: TomCtr.textOrNull(key, 'color'),
      radius: TomCtr.doubleVal(key, 'radius') ?? 4.0,
    );
  }
}

// ---------------------------------------------------------------------------
// Cached overlay — precomputed once per (provider, path) and shared across
// every TomFormStyleScope instance that resolves to the same path.
// ---------------------------------------------------------------------------

class _StyleOverlay {
  final LabelPlacement? labelPlacement;
  final ErrorPlacement? errorPlacement;
  final DescriptionPlacement? descriptionPlacement;
  final ActionIconPlacement? actionIconPlacement;
  final RequiredIndicator? requiredIndicator;
  final RequiredIndicator? requiredIndicatorOnHint;
  final RequiredIndicator? requiredIndicatorOnDescription;
  final double? labelFieldGap;
  final double? errorFieldGap;
  final double? descriptionFieldGap;
  final double? borderRadius;
  final double? borderWidth;
  final double? focusedBorderWidth;
  final EdgeInsets? fieldContentPadding;
  final bool? errorBorderEnabled;
  final bool? errorIconEnabled;
  // Borders and text styles are stored as deferred objects so that
  // cs.* color tokens can be resolved against a live ColorScheme at
  // build time rather than at parse / cache time.
  final _OverlayBorder? fieldBorder;
  final _OverlayBorder? focusedBorder;
  final _OverlayBorder? errorBorder;
  final _OverlayTextStyle? inputStyle;
  final _OverlayTextStyle? labelStyle;
  final _OverlayTextStyle? hintStyle;
  final _OverlayTextStyle? errorStyle;
  final _OverlayTextStyle? descriptionStyle;
  final FontWeight? hintFontWeight;
  final bool hintFontWeightSet;
  final double? hintOpacity;
  final bool hintOpacitySet;

  const _StyleOverlay({
    this.labelPlacement,
    this.errorPlacement,
    this.descriptionPlacement,
    this.actionIconPlacement,
    this.requiredIndicator,
    this.requiredIndicatorOnHint,
    this.requiredIndicatorOnDescription,
    this.labelFieldGap,
    this.errorFieldGap,
    this.descriptionFieldGap,
    this.borderRadius,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fieldContentPadding,
    this.errorBorderEnabled,
    this.errorIconEnabled,
    this.fieldBorder,
    this.focusedBorder,
    this.errorBorder,
    this.inputStyle,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.descriptionStyle,
    this.hintFontWeight,
    this.hintFontWeightSet = false,
    this.hintOpacity,
    this.hintOpacitySet = false,
  });

  bool get isEmpty =>
      labelPlacement == null &&
      errorPlacement == null &&
      descriptionPlacement == null &&
      actionIconPlacement == null &&
      requiredIndicator == null &&
      requiredIndicatorOnHint == null &&
      requiredIndicatorOnDescription == null &&
      labelFieldGap == null &&
      errorFieldGap == null &&
      descriptionFieldGap == null &&
      borderRadius == null &&
      borderWidth == null &&
      focusedBorderWidth == null &&
      fieldContentPadding == null &&
      errorBorderEnabled == null &&
      errorIconEnabled == null &&
      fieldBorder == null &&
      focusedBorder == null &&
      errorBorder == null &&
      (inputStyle?.isEmpty ?? true) &&
      (labelStyle?.isEmpty ?? true) &&
      (hintStyle?.isEmpty ?? true) &&
      (errorStyle?.isEmpty ?? true) &&
      (descriptionStyle?.isEmpty ?? true) &&
      !hintFontWeightSet &&
      !hintOpacitySet;

  /// Applies the overlay to [base], resolving any `cs.*` color tokens
  /// against [cs]. Pass [cs] from `Theme.of(context).colorScheme`.
  TomFormStyle apply(TomFormStyle base, ColorScheme cs) {
    if (isEmpty) return base;
    return base.copyWith(
      defaults: base.defaults.copyWith(
        labelPlacement: labelPlacement ?? base.defaults.labelPlacement,
        errorPlacement: errorPlacement ?? base.defaults.errorPlacement,
        descriptionPlacement:
            descriptionPlacement ?? base.defaults.descriptionPlacement,
        actionIconPlacement:
            actionIconPlacement ?? base.defaults.actionIconPlacement,
        requiredIndicator: requiredIndicator ?? base.defaults.requiredIndicator,
        requiredIndicatorOnHint:
            requiredIndicatorOnHint ?? base.defaults.requiredIndicatorOnHint,
        requiredIndicatorOnDescription:
            requiredIndicatorOnDescription ??
            base.defaults.requiredIndicatorOnDescription,
        labelFieldGap: labelFieldGap ?? base.defaults.labelFieldGap,
        errorFieldGap: errorFieldGap ?? base.defaults.errorFieldGap,
        descriptionFieldGap:
            descriptionFieldGap ?? base.defaults.descriptionFieldGap,
        borderRadius: borderRadius ?? base.defaults.borderRadius,
        borderWidth: borderWidth ?? base.defaults.borderWidth,
        focusedBorderWidth:
            focusedBorderWidth ?? base.defaults.focusedBorderWidth,
        fieldContentPadding:
            fieldContentPadding ?? base.defaults.fieldContentPadding,
        errorBorderEnabled:
            errorBorderEnabled ?? base.defaults.errorBorderEnabled,
        errorIconEnabled: errorIconEnabled ?? base.defaults.errorIconEnabled,
        fieldBorder: fieldBorder?.resolve(cs) ?? base.defaults.fieldBorder,
        focusedBorder:
            focusedBorder?.resolve(cs) ?? base.defaults.focusedBorder,
        errorBorder: errorBorder?.resolve(cs) ?? base.defaults.errorBorder,
        inputStyle: inputStyle?.resolve(cs) ?? base.defaults.inputStyle,
        labelStyle: labelStyle?.resolve(cs) ?? base.defaults.labelStyle,
        hintStyle: hintStyle?.resolve(cs) ?? base.defaults.hintStyle,
        errorStyle: errorStyle?.resolve(cs) ?? base.defaults.errorStyle,
        descriptionStyle:
            descriptionStyle?.resolve(cs) ?? base.defaults.descriptionStyle,
        hintFontWeight: hintFontWeight ?? base.defaults.hintFontWeight,
        hintFontWeightSet: hintFontWeightSet,
        hintOpacity: hintOpacity ?? base.defaults.hintOpacity,
        hintOpacitySet: hintOpacitySet,
      ),
    );
  }

  /// Parses all style keys from [block], storing raw color strings so
  /// `cs.*` tokens can be resolved against a live [ColorScheme] at build
  /// time. Non-token colors (hex, named) are also stored as raw strings
  /// and resolved at the same time via [TomUIColors].
  static _StyleOverlay fromResources(String block) {
    final hintWeightRaw = TomCtr.textOrNull(block, 'hintFontWeight');
    final hintOpacityRaw = TomCtr.doubleVal(block, 'hintOpacity');
    return _StyleOverlay(
      labelPlacement: _parseEnum(
        TomCtr.textOrNull(block, 'labelPlacement'),
        LabelPlacement.values,
      ),
      errorPlacement: _parseEnum(
        TomCtr.textOrNull(block, 'errorPlacement'),
        ErrorPlacement.values,
      ),
      descriptionPlacement: _parseEnum(
        TomCtr.textOrNull(block, 'descriptionPlacement'),
        DescriptionPlacement.values,
      ),
      actionIconPlacement: _parseEnum(
        TomCtr.textOrNull(block, 'actionIconPlacement'),
        ActionIconPlacement.values,
      ),
      requiredIndicator: _parseEnum(
        TomCtr.textOrNull(block, 'requiredIndicator'),
        RequiredIndicator.values,
      ),
      requiredIndicatorOnHint: _parseEnum(
        TomCtr.textOrNull(block, 'requiredIndicatorOnHint'),
        RequiredIndicator.values,
      ),
      requiredIndicatorOnDescription: _parseEnum(
        TomCtr.textOrNull(block, 'requiredIndicatorOnDescription'),
        RequiredIndicator.values,
      ),
      labelFieldGap: TomCtr.doubleVal(block, 'labelFieldGap'),
      errorFieldGap: TomCtr.doubleVal(block, 'errorFieldGap'),
      descriptionFieldGap: TomCtr.doubleVal(block, 'descriptionFieldGap'),
      borderRadius: TomCtr.doubleVal(block, 'borderRadius'),
      borderWidth: TomCtr.doubleVal(block, 'borderWidth'),
      focusedBorderWidth: TomCtr.doubleVal(block, 'focusedBorderWidth'),
      fieldContentPadding: TomCtr.edgeInsets(block, 'fieldContentPadding'),
      errorBorderEnabled: TomCtr.boolVal(block, 'errorBorderEnabled'),
      errorIconEnabled: TomCtr.boolVal(block, 'errorIconEnabled'),
      // Borders and text styles use deferred types that store the raw color
      // string (hex, named, or cs.*) for resolution at apply() time.
      fieldBorder: _OverlayBorder.fromResources(block, 'fieldBorder'),
      focusedBorder: _OverlayBorder.fromResources(block, 'focusedBorder'),
      errorBorder: _OverlayBorder.fromResources(block, 'errorBorder'),
      inputStyle: _OverlayTextStyle.fromResources(block, 'inputStyle'),
      labelStyle: _OverlayTextStyle.fromResources(block, 'labelStyle'),
      hintStyle: _OverlayTextStyle.fromResources(block, 'hintStyle'),
      errorStyle: _OverlayTextStyle.fromResources(block, 'errorStyle'),
      descriptionStyle: _OverlayTextStyle.fromResources(
        block,
        'descriptionStyle',
      ),
      hintFontWeight: _parseFontWeight(hintWeightRaw),
      hintFontWeightSet: hintWeightRaw != null,
      hintOpacity: hintOpacityRaw,
      hintOpacitySet: hintOpacityRaw != null,
    );
  }
}

class _BpEntry {
  final String? name;
  final double? literalMinWidth;
  final _StyleOverlay overlay;
  final TomThemeSpec? themeSpec;

  const _BpEntry({
    this.name,
    this.literalMinWidth,
    required this.overlay,
    this.themeSpec,
  });

  double get minWidth {
    if (name != null) {
      return TomBreakpoint.resolve(name!) ?? 0;
    }
    return literalMinWidth ?? 0;
  }
}

/// Pre-parsed pack for a single resolved resource path.
class _ResourceOverlay {
  final _StyleOverlay base;
  final List<_BpEntry> bpEntries;
  final TomThemeSpec? themeSpec;
  const _ResourceOverlay({
    required this.base,
    required this.bpEntries,
    required this.themeSpec,
  });

  static _ResourceOverlay parse(String path) {
    final base = _StyleOverlay.fromResources(path);
    final themeSpec = TomThemeSpec.fromResources(path, subKey: 'theme');
    final entries = <_BpEntry>[];

    for (final name in TomBreakpoint.names) {
      final block = '$path.@bp.$name';
      final overlay = _StyleOverlay.fromResources(block);
      final ts = TomThemeSpec.fromResources(block, subKey: 'theme');
      if (!overlay.isEmpty || ts != null) {
        entries.add(_BpEntry(name: name, overlay: overlay, themeSpec: ts));
      }
    }

    const ladder = <int>[
      0,
      240,
      320,
      360,
      400,
      480,
      540,
      600,
      640,
      720,
      768,
      840,
      900,
      960,
      1024,
      1152,
      1200,
      1280,
      1366,
      1440,
      1536,
      1600,
      1920,
      2560,
    ];
    for (final w in ladder) {
      final block = '$path.@bp.$w';
      final overlay = _StyleOverlay.fromResources(block);
      final ts = TomThemeSpec.fromResources(block, subKey: 'theme');
      if (!overlay.isEmpty || ts != null) {
        entries.add(
          _BpEntry(
            literalMinWidth: w.toDouble(),
            overlay: overlay,
            themeSpec: ts,
          ),
        );
      }
    }

    return _ResourceOverlay(
      base: base,
      bpEntries: entries,
      themeSpec: themeSpec,
    );
  }
}

/// Per-provider cache of parsed overlays. Uses [Expando] so the provider
/// instance retains no strong reference from the cache — when the resource
/// provider is replaced and goes out of use, its overlay entries go with
/// it. Callers that swap a provider *in place* (mutating its map) should
/// call [TomFormStyleScope.invalidateResourceCache] to flush.
final Expando<Map<String, _ResourceOverlay>> _cachePerProvider =
    Expando<Map<String, _ResourceOverlay>>('tomFormStyleScope');

_ResourceOverlay _getOrParse(String path) {
  final provider = TomTextResourceProvider.getAppResources();
  final perPath = _cachePerProvider[provider] ??= <String, _ResourceOverlay>{};
  return perPath[path] ??= _ResourceOverlay.parse(path);
}

// ---------------------------------------------------------------------------
// TomFormStyleScope
// ---------------------------------------------------------------------------

/// Provides a [TomFormStyle] plus the current available width to descendant
/// fields via an `InheritedWidget`, and optionally wraps its [child] in a
/// [Theme] derived from a [ThemeData] / [TomThemeSpec] / resources.
///
/// # Style resolution (precedence low → high)
///
/// 1. Programmatic [style]
/// 2. Programmatic [styleBpOverrides] — highest `minWidth <= width` wins
/// 3. Resource base at `{path}.*` (when [tomId] is set)
/// 4. Resource breakpoint at `{path}.@bp.{minWidth|name}.*`
///
/// # Theme resolution (precedence low → high)
///
/// 1. Programmatic [theme]
/// 2. Programmatic [themeBpOverrides]
/// 3. [themeSpec] → `toThemeData(themeSpecBase)` where `themeSpecBase`
///    is [themeSpecTheme] (if set) or the **ambient** `Theme.of(context)`
///    — so unset spec fields inherit the app's current component themes,
///    theme extensions, etc.
/// 4. [themeSpecBpOverrides]
/// 5. Resource `{path}.theme.*` → `toThemeData(themeSpecBase)`
/// 6. Resource `{path}.@bp.{key}.theme.*` → `toThemeData(themeSpecBase)`
///
/// If nothing produces a theme, the child is returned without a `Theme`
/// wrapper (ambient wins).
///
/// # Caching
///
/// Resource parsing happens **once per (provider, tomId+scope)** via a
/// static cache. Rebuilds of this widget are pure apply-to-base calls with
/// no resource I/O. Call [invalidateResourceCache] after mutating the
/// resource map in place.
class TomFormStyleScope extends StatelessWidget {
  /// Optional Tom identifier. When non-null, the scope reads overrides
  /// from resources rooted at `TomCtr.resolvePath(tomId, scope)`.
  final String? tomId;

  /// Optional explicit [TomScope] to override the ambient one.
  final TomScope? scope;

  /// Programmatic base style. When `null`, the scope still wraps the
  /// subtree so that theme / themeSpec / breakpoint overrides reach
  /// descendants — form-style defaults fall through to the nearest
  /// outer scope (or to [TomFormStyle.material3] when none exists).
  ///
  /// Passing `null` is the intended way to use this widget purely as a
  /// breakpoint-aware theme/themeData injector without re-declaring a
  /// form style.
  final TomFormStyle? style;

  /// Scope-level breakpoint variants of the programmatic style.
  final List<(double, TomFormStyle)> styleBpOverrides;

  /// Programmatic [ThemeData]. Applied when resources don't supply one.
  final ThemeData? theme;

  /// Breakpoint variants of [theme].
  final List<(double, ThemeData)> themeBpOverrides;

  /// Programmatic [TomThemeSpec]. Its `toThemeData` is called with
  /// [themeSpecTheme] (if set) or the ambient `Theme.of(context)` as the
  /// base — so unset fields inherit upstream component themes / extensions.
  final TomThemeSpec? themeSpec;

  /// Breakpoint variants of [themeSpec].
  final List<(double, TomThemeSpec)> themeSpecBpOverrides;

  /// Base [ThemeData] handed to every `TomThemeSpec.toThemeData(base)` call
  /// (programmatic or resource-driven). When null, the ambient
  /// `Theme.of(context)` is used — so by default a spec patches the app's
  /// current theme rather than reinventing one from scratch.
  final ThemeData? themeSpecTheme;

  final Widget child;

  const TomFormStyleScope({
    super.key,
    this.tomId,
    this.scope,
    this.style,
    this.styleBpOverrides = const [],
    this.theme,
    this.themeBpOverrides = const [],
    this.themeSpec,
    this.themeSpecBpOverrides = const [],
    this.themeSpecTheme,
    required this.child,
  });

  /// Returns the nearest scope's resolved style, or [TomFormStyle.material3]
  /// when no scope is found.
  static TomFormStyle of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_TomFormStyleInheritedScope>();
    return inherited?.style ?? TomFormStyle.material3;
  }

  /// Returns the width captured by the nearest enclosing scope.
  static double widthOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_TomFormStyleInheritedScope>();
    if (inherited != null) return inherited.width;
    return MediaQuery.sizeOf(context).width;
  }

  /// Forgets every cached resource parse for the current provider.
  /// Call after mutating the resource map in place; installing a fresh
  /// provider instance doesn't need this (a new provider gets its own
  /// cache slot via [Expando]).
  static void invalidateResourceCache() {
    final provider = TomTextResourceProvider.getAppResources();
    _cachePerProvider[provider] = null;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPath = TomCtr.resolvePath(tomId, scope);
    final pack = resolvedPath == null ? null : _getOrParse(resolvedPath);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // --- Theme ---
        // Resolve theme first so we can use its ColorScheme when applying
        // style overlays — cs.* tokens in the JSON resolve against it.
        _BpEntry? matchingBp;
        if (pack != null) {
          matchingBp = _matchBp(pack.bpEntries, width);
        }
        final themeData = _resolveTheme(context, width, pack, matchingBp);

        // Use the resolved theme's colorscheme for cs.* token resolution,
        // falling back to the ambient theme when no override is active.
        final cs = themeData?.colorScheme ?? Theme.of(context).colorScheme;

        // --- Style ---
        var resolved = _pickProgrammaticStyle(context, width);
        if (pack != null) {
          resolved = pack.base.apply(resolved, cs);
          if (matchingBp != null) {
            resolved = matchingBp.overlay.apply(resolved, cs);
          }
        }

        // Apply withTheme so every style property that is still at its
        // canonical origin (never set by the programmatic base or the
        // overlay) inherits font family, size, and colour from the active
        // theme. Explicitly-configured values (JSON overlay, preset, Dart
        // code) are never touched — withTheme's preservation rule handles
        // that. This means: nothing configured = full theme derivation;
        // something configured = that property stays, rest is theme-derived.
        final activeTheme = themeData ?? Theme.of(context);
        resolved = resolved.withTheme(activeTheme);

        // Always wrap in Theme so the widget tree structure stays stable
        // across breakpoint crossings. If we conditionally added/removed
        // the Theme widget, Flutter would tear down and rebuild the entire
        // subtree (including StatefulWidgets like TextField/Dropdown) each
        // time the user dragged across a breakpoint, losing internal state
        // and causing a visible "flash" back to the initial render.
        // When no bp theme is active we reuse the ambient theme; the extra
        // Theme widget is effectively a no-op in that case.
        final effectiveTheme = themeData ?? Theme.of(context);
        return Theme(
          data: effectiveTheme,
          child: _TomFormStyleInheritedScope(
            style: resolved,
            width: width,
            child: child,
          ),
        );
      },
    );
  }

  // --- Style resolution helpers --------------------------------------------

  TomFormStyle _pickProgrammaticStyle(BuildContext context, double width) {
    // When no programmatic base style is configured, fall back to the
    // enclosing scope's style — that way this widget can be used as a
    // pure theme / themeSpec / breakpoint injector without re-declaring
    // the form-style layer. TomFormStyleScope.of() returns the
    // material3 defaults when there is no enclosing scope.
    final TomFormStyle baseStyle = style ?? TomFormStyleScope.of(context);
    if (styleBpOverrides.isEmpty) return baseStyle;
    TomFormStyle current = baseStyle;
    double best = double.negativeInfinity;
    for (final entry in styleBpOverrides) {
      final minW = entry.$1;
      if (minW <= width && minW >= best) {
        best = minW;
        current = entry.$2;
      }
    }
    return current;
  }

  _BpEntry? _matchBp(List<_BpEntry> entries, double width) {
    _BpEntry? best;
    double bestW = double.negativeInfinity;
    for (final e in entries) {
      final w = e.minWidth;
      if (w <= width && w >= bestW) {
        bestW = w;
        best = e;
      }
    }
    return best;
  }

  // --- Theme resolution helpers -------------------------------------------

  ThemeData? _resolveTheme(
    BuildContext context,
    double width,
    _ResourceOverlay? pack,
    _BpEntry? matchingBp,
  ) {
    // Resource-driven theme wins over programmatic (resources are closer
    // to the user's declarative intent) — see doc on precedence.
    if (pack != null) {
      final bpSpec = matchingBp?.themeSpec;
      final baseSpec = pack.themeSpec;
      if (bpSpec != null || baseSpec != null) {
        final ThemeData baseData = themeSpecTheme ?? Theme.of(context);
        ThemeData current = baseData;
        if (baseSpec != null) current = baseSpec.toThemeData(current);
        if (bpSpec != null) current = bpSpec.toThemeData(current);
        return current;
      }
    }

    // Programmatic themeSpec breakpoint variants.
    final bpThemeSpec = _pickBp<TomThemeSpec>(themeSpecBpOverrides, width);
    if (bpThemeSpec != null) {
      return bpThemeSpec.toThemeData(themeSpecTheme ?? Theme.of(context));
    }

    // Programmatic theme breakpoint variants.
    final bpTheme = _pickBp<ThemeData>(themeBpOverrides, width);
    if (bpTheme != null) return bpTheme;

    // Programmatic themeSpec (base).
    if (themeSpec != null) {
      return themeSpec!.toThemeData(themeSpecTheme ?? Theme.of(context));
    }

    // Programmatic theme (base).
    return theme;
  }

  static T? _pickBp<T>(List<(double, T)> list, double width) {
    if (list.isEmpty) return null;
    T? picked;
    double best = double.negativeInfinity;
    for (final entry in list) {
      final minW = entry.$1;
      if (minW <= width && minW >= best) {
        best = minW;
        picked = entry.$2;
      }
    }
    return picked;
  }
}

class _TomFormStyleInheritedScope extends InheritedWidget {
  final TomFormStyle style;
  final double width;

  const _TomFormStyleInheritedScope({
    required this.style,
    required this.width,
    required super.child,
  });

  @override
  bool updateShouldNotify(_TomFormStyleInheritedScope oldWidget) =>
      style != oldWidget.style || width != oldWidget.width;
}

// ---------------------------------------------------------------------------
// Shared parsers
// ---------------------------------------------------------------------------

E? _parseEnum<E extends Enum>(String? raw, List<E> values) {
  if (raw == null) return null;
  final lower = raw.trim().toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == lower) return v;
  }
  return null;
}

FontWeight? _parseFontWeight(String? raw) {
  if (raw == null) return null;
  switch (raw.trim().toLowerCase()) {
    case 'w100':
    case 'thin':
      return FontWeight.w100;
    case 'w200':
    case 'extralight':
      return FontWeight.w200;
    case 'w300':
    case 'light':
      return FontWeight.w300;
    case 'w400':
    case 'normal':
    case 'regular':
      return FontWeight.w400;
    case 'w500':
    case 'medium':
      return FontWeight.w500;
    case 'w600':
    case 'semibold':
      return FontWeight.w600;
    case 'w700':
    case 'bold':
      return FontWeight.w700;
    case 'w800':
    case 'extrabold':
      return FontWeight.w800;
    case 'w900':
    case 'black':
      return FontWeight.w900;
    default:
      return null;
  }
}
