import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_breakpoint.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_scope.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_color_tokens.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_theme_spec.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';

/// Pump a [TomFormStyleScope] at a given physical width and return the
/// resolved style observed via [TomFormStyleScope.of] from a descendant
/// context. Uses a [MediaQuery] to drive the LayoutBuilder's maxWidth.
Future<TomFormStyle> _resolve(
  WidgetTester tester, {
  required double width,
  required TomFormStyle style,
  List<(double, TomFormStyle)> styleBpOverrides = const [],
  String? tomId,
}) async {
  // Expand the test viewport so large widths aren't clamped by the
  // default 800x600 surface.
  tester.view.physicalSize = Size(width + 200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  late TomFormStyle observed;
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: TomFormStyleScope(
            tomId: tomId,
            style: style,
            styleBpOverrides: styleBpOverrides,
            child: Builder(
              builder: (ctx) {
                observed = TomFormStyleScope.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return observed;
}

void main() {
  setUpAll(() {
    // Hex colour parsing (e.g. "#00897B") uses AllColorsAdapter.
    TomUIColors.adapter = AllColorsAdapter();
  });

  group('TomFormStyleScope — programmatic styleBpOverrides', () {
    testWidgets('picks highest minWidth <= width', (tester) async {
      const base = TomFormStyle();
      const narrow = TomFormStyle(
          defaults: TomFieldStyle(labelFieldGap: 2));
      const wide = TomFormStyle(
          defaults: TomFieldStyle(labelFieldGap: 16));

      final atNarrow = await _resolve(
        tester,
        width: 300,
        style: base,
        styleBpOverrides: const [(600, narrow), (1024, wide)],
      );
      expect(atNarrow.defaults.labelFieldGap, base.defaults.labelFieldGap);

      final atMid = await _resolve(
        tester,
        width: 700,
        style: base,
        styleBpOverrides: const [(600, narrow), (1024, wide)],
      );
      expect(atMid.defaults.labelFieldGap, 2);

      final atWide = await _resolve(
        tester,
        width: 1200,
        style: base,
        styleBpOverrides: const [(600, narrow), (1024, wide)],
      );
      expect(atWide.defaults.labelFieldGap, 16);
    });
  });

  group('TomFormStyleScope — resource overlay', () {
    setUp(() {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'myForm': {
            'labelPlacement': 'floating',
            'labelFieldGap': 6,
            'hintFontWeight': 'w700',
            'hintOpacity': 0.5,
            'fieldContentPadding': {
              'left': 14,
              'top': 10,
              'right': 14,
              'bottom': 10,
            },
            'fieldBorder': {
              'kind': 'outline',
              'width': 1,
              'color': '#9E9E9E',
              'radius': 8,
            },
            'labelStyle': {'fontSize': 13, 'color': '#4527A0'},
            'inputStyle': {'fontSize': 14},
            '@bp': {
              '600': {
                'labelPlacement': 'above',
                'labelFieldGap': 10,
                'inputStyle': {'fontSize': 16},
              },
              '1024': {
                'labelPlacement': 'inline',
                'labelFieldGap': 14,
              },
            },
          },
        }),
      );
    });

    testWidgets('reads every supported base-level property', (tester) async {
      final resolved = await _resolve(
        tester,
        width: 400,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(resolved.defaults.labelPlacement, LabelPlacement.floating);
      expect(resolved.defaults.labelFieldGap, 6);
      expect(resolved.defaults.hintFontWeight, FontWeight.w700);
      expect(resolved.defaults.hintOpacity, 0.5);
      expect(resolved.defaults.fieldContentPadding,
          const EdgeInsets.fromLTRB(14, 10, 14, 10));
      expect(resolved.defaults.fieldBorder, isA<OutlineInputBorder>());
      expect(resolved.defaults.labelStyle?.fontSize, 13);
      expect(resolved.defaults.inputStyle?.fontSize, 14);
    });

    testWidgets('@bp 600 overrides the base when width >= 600',
        (tester) async {
      final resolved = await _resolve(
        tester,
        width: 700,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(resolved.defaults.labelPlacement, LabelPlacement.above);
      expect(resolved.defaults.labelFieldGap, 10);
      expect(resolved.defaults.inputStyle?.fontSize, 16);
      // Non-overridden base values survive.
      expect(resolved.defaults.hintOpacity, 0.5);
    });

    testWidgets('@bp 1024 wins over @bp 600 when width >= 1024',
        (tester) async {
      final resolved = await _resolve(
        tester,
        width: 1280,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(resolved.defaults.labelPlacement, LabelPlacement.inline);
      expect(resolved.defaults.labelFieldGap, 14);
    });
  });

  group('TomFormStyleScope — named breakpoints', () {
    setUp(() {
      // Reset TomBreakpoint to defaults before each test.
      TomBreakpoint.mobile = 600;
      TomBreakpoint.tablet = 900;
      TomBreakpoint.desktop = 1200;

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'myForm': {
            'labelFieldGap': 2,
            '@bp': {
              'mobile': {'labelFieldGap': 4},
              'tablet': {'labelFieldGap': 8},
              'desktop': {'labelFieldGap': 16},
            },
          },
        }),
      );
    });

    testWidgets('resolves mobile/tablet/desktop via TomBreakpoint',
        (tester) async {
      final atNarrow = await _resolve(
        tester,
        width: 400,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(atNarrow.defaults.labelFieldGap, 2);

      final atMobile = await _resolve(
        tester,
        width: 700,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(atMobile.defaults.labelFieldGap, 4);

      final atTablet = await _resolve(
        tester,
        width: 1000,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(atTablet.defaults.labelFieldGap, 8);

      final atDesktop = await _resolve(
        tester,
        width: 1400,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(atDesktop.defaults.labelFieldGap, 16);
    });

    testWidgets('retuning TomBreakpoint flows through without cache bust',
        (tester) async {
      // Push tablet up to 1500; width=1000 should no longer reach tablet
      // (falls back to mobile) — the cached entry's minWidth is
      // re-resolved at query time.
      TomBreakpoint.tablet = 1500;

      final atOneK = await _resolve(
        tester,
        width: 1000,
        style: const TomFormStyle(),
        tomId: 'myForm',
      );
      expect(atOneK.defaults.labelFieldGap, 4); // mobile, not tablet

      TomBreakpoint.tablet = 900;
    });
  });

  group('TomFormStyleScope — theme', () {
    testWidgets('programmatic theme wraps child in Theme', (tester) async {
      ThemeData? seenTheme;
      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScope(
            style: const TomFormStyle(),
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF00FF)),
              useMaterial3: true,
            ),
            child: Builder(
              builder: (ctx) {
                seenTheme = Theme.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(
        seenTheme!.colorScheme.primary,
        isNot(const Color(0xFF6750A4)), // default M3 primary
      );
    });

    testWidgets('themeSpec inherits component themes from ambient base',
        (tester) async {
      // Custom cardTheme on the ambient theme — the spec should NOT wipe it.
      final customCard = CardThemeData(elevation: 42, margin: EdgeInsets.zero);
      final ambient = ThemeData(
        useMaterial3: true,
        cardTheme: customCard,
      );
      final spec = TomThemeSpec(seed: const Color(0xFFFF00FF));

      ThemeData? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ambient,
          home: TomFormStyleScope(
            style: const TomFormStyle(),
            themeSpec: spec,
            child: Builder(
              builder: (ctx) {
                seen = Theme.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen!.cardTheme.elevation, 42,
          reason: 'ambient component themes must survive spec application');
    });

    testWidgets('themeSpecTheme overrides ambient as the base', (tester) async {
      final specBase = ThemeData(
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 7),
      );
      ThemeData? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            cardTheme: const CardThemeData(elevation: 99),
          ),
          home: TomFormStyleScope(
            style: const TomFormStyle(),
            themeSpecTheme: specBase,
            themeSpec: const TomThemeSpec(seed: Color(0xFFFF00FF)),
            child: Builder(
              builder: (ctx) {
                seen = Theme.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen!.cardTheme.elevation, 7,
          reason: 'themeSpecTheme should shadow the ambient Material theme');
    });

    testWidgets('themeSpec from resources materialises into theme',
        (tester) async {
      TomFormStyleScope.invalidateResourceCache();
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'myForm': {
            'theme': {
              'seed': '#00897B', // teal — distinct from default M3 purple
              'brightness': 'light',
            },
          },
        }),
      );

      ThemeData? seenTheme;
      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScope(
            tomId: 'myForm',
            style: const TomFormStyle(),
            child: Builder(
              builder: (ctx) {
                seenTheme = Theme.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final expectedPrimary = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00897B),
      ).primary;
      expect(seenTheme!.colorScheme.primary, expectedPrimary);
    });
  });

  group('TomFormStyleScope — cache', () {
    testWidgets('resource reads happen once per tomId across every build',
        (tester) async {
      int readCount = 0;
      TomTextResourceProvider.setAppResourceProvider(
        _CountingProvider(
          map: <String, dynamic>{
            'myForm': {'labelFieldGap': 6},
          },
          onRead: () => readCount++,
        ),
      );
      TomFormStyleScope.invalidateResourceCache();

      Widget build(double width) => MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: TomFormStyleScope(
                  tomId: 'myForm',
                  style: const TomFormStyle(),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          );
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(build(500));
      final afterInit = readCount;
      expect(afterInit, greaterThan(0));

      // Rebuild several times with different-instance scopes at different
      // widths — cache is keyed by (provider, path), so no new reads.
      for (final w in [600.0, 700.0, 800.0, 900.0]) {
        await tester.pumpWidget(build(w));
      }
      expect(readCount, afterInit,
          reason: 'cache should serve every follow-up scope with same tomId');
    });

  group('TomColorTokens — cs.* resolution', () {
    test('resolves primary, onSurface, error, outline', () {
      final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));
      expect(resolveColorSchemeToken('cs.primary', cs), cs.primary);
      expect(resolveColorSchemeToken('cs.onSurface', cs), cs.onSurface);
      expect(resolveColorSchemeToken('cs.error', cs), cs.error);
      expect(resolveColorSchemeToken('cs.outline', cs), cs.outline);
    });

    test('case-insensitive and normalises camelCase', () {
      final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1));
      expect(
        resolveColorSchemeToken('cs.onSurfaceVariant', cs),
        cs.onSurfaceVariant,
      );
      expect(
        resolveColorSchemeToken('CS.ONSURFACEVARIANT', cs),
        cs.onSurfaceVariant,
      );
      expect(
        resolveColorSchemeToken('cs.on_surface_variant', cs),
        cs.onSurfaceVariant,
      );
    });

    test('returns null for unknown token', () {
      final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1));
      expect(resolveColorSchemeToken('cs.nope', cs), isNull);
    });

    test('isColorSchemeToken detects prefix', () {
      expect(isColorSchemeToken('cs.primary'), isTrue);
      expect(isColorSchemeToken('CS.primary'), isTrue);
      expect(isColorSchemeToken('#FF0000'), isFalse);
      expect(isColorSchemeToken('mRed'), isFalse);
    });
  });

  group('TomFormStyleScope — cs.* tokens in resource overlay', () {
    testWidgets('labelStyle color resolves to active cs.primary',
        (tester) async {
      TomFormStyleScope.invalidateResourceCache();
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'myForm': {
            'labelStyle': {'fontSize': 14, 'color': 'cs.primary'},
            'focusedBorder': {
              'kind': 'outline',
              'width': 2,
              'color': 'cs.primary'
            },
          },
        }),
      );

      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));

      TomFormStyle? resolvedStyle;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme, useMaterial3: true),
          home: TomFormStyleScope(
            tomId: 'myForm',
            style: const TomFormStyle(),
            child: Builder(
              builder: (ctx) {
                resolvedStyle = TomFormStyleScope.of(ctx);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolvedStyle!.defaults.labelStyle?.color, scheme.primary);
      final focused = resolvedStyle!.defaults.focusedBorder;
      expect(focused, isA<OutlineInputBorder>());
      final side = (focused! as OutlineInputBorder).borderSide;
      expect(side.color, scheme.primary);
    });

    testWidgets('tokens re-resolve when theme changes between breakpoints',
        (tester) async {
      TomFormStyleScope.invalidateResourceCache();
      final purple =
          ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1));
      final teal = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));

      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'myForm': {
            'labelStyle': {'color': 'cs.primary'},
            '@bp': {
              '600': {
                'labelStyle': {'color': 'cs.primary'},
                'theme': {'seed': '#00897B'},
              },
            },
          },
        }),
      );

      late TomFormStyle styleAt300, styleAt700;
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Future<TomFormStyle> probe(WidgetTester t, double w) async {
        TomFormStyle? s;
        t.view.physicalSize = Size(w + 200, 2000);
        t.view.devicePixelRatio = 1.0;
        await t.pumpWidget(MaterialApp(
          theme: ThemeData(colorScheme: purple, useMaterial3: true),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: w,
              child: TomFormStyleScope(
                tomId: 'myForm',
                style: const TomFormStyle(),
                child: Builder(builder: (ctx) {
                  s = TomFormStyleScope.of(ctx);
                  return const SizedBox.shrink();
                }),
              ),
            ),
          ),
        ));
        return s!;
      }

      styleAt300 = await probe(tester, 300);
      styleAt700 = await probe(tester, 700);
      addTearDown(tester.view.resetPhysicalSize);

      // At 300: no bp, theme = purple → cs.primary = purple.primary
      expect(styleAt300.defaults.labelStyle?.color, purple.primary);
      // At 700: @bp.600 active, theme spec = teal → cs.primary = teal.primary
      expect(styleAt700.defaults.labelStyle?.color, teal.primary);
    });
  });

    testWidgets(
        'invalidateResourceCache reparses on next scope instantiation',
        (tester) async {
      int readCount = 0;
      TomTextResourceProvider.setAppResourceProvider(
        _CountingProvider(
          map: <String, dynamic>{
            'myForm': {'labelFieldGap': 6},
          },
          onRead: () => readCount++,
        ),
      );
      TomFormStyleScope.invalidateResourceCache();

      Widget build() => const MaterialApp(
            home: TomFormStyleScope(
              tomId: 'myForm',
              style: TomFormStyle(),
              child: SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(build());
      final afterFirst = readCount;

      TomFormStyleScope.invalidateResourceCache();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(build());
      expect(readCount, greaterThan(afterFirst));
    });
  });
}

/// Test helper — counts how many times `getTextOrNull` is called.
class _CountingProvider extends TomTextResourceProvider {
  final void Function() onRead;

  _CountingProvider({
    required Map<String, dynamic> map,
    required this.onRead,
  }) : super.from(map);

  @override
  String? getTextOrNull(String s) {
    onRead();
    return super.getTextOrNull(s);
  }

  @override
  Object? getObjectOrNull(String s) {
    onRead();
    return super.getObjectOrNull(s);
  }
}
