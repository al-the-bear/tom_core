/// `cupertinoFieldDecoration` is the single surface contract every Cupertino
/// field concrete renders against — eight field files call it and nothing else
/// draws their box. Its whole job is to read things *off the ambient context*
/// (the Cupertino theme's primary colour, the platform brightness) rather than
/// hard-code them, and that is precisely the part a static reading of the
/// function cannot confirm: a version that dropped `resolveFrom` would look
/// identical in source and render the light palette in dark mode.
///
/// So the assertions below are all differential — light against dark, focused
/// against unfocused, supplied fill against the default — because a single
/// snapshot of one colour proves only that some colour came back.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_cupertino_form_style.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Builds the decoration inside a live [CupertinoApp] and hands back both the
/// result and the context it was resolved against, so an expectation can
/// resolve the same dynamic colour the same way.
Future<({BoxDecoration decoration, BuildContext context})> _decorate(
  WidgetTester tester, {
  double borderRadius = 8,
  Color? fillColor,
  bool focused = false,
  Brightness brightness = Brightness.light,
  Color primaryColor = const Color(0xFF00897B),
}) async {
  late BoxDecoration decoration;
  late BuildContext captured;
  await tester.pumpWidget(
    CupertinoApp(
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: primaryColor,
      ),
      home: Builder(
        builder: (context) {
          captured = context;
          decoration = cupertinoFieldDecoration(
            context: context,
            borderRadius: borderRadius,
            fillColor: fillColor,
            focused: focused,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return (decoration: decoration, context: captured);
}

/// The four sides come from `Border.all`, so reading one is reading all.
BorderSide _side(BoxDecoration decoration) =>
    (decoration.border! as Border).top;

void main() {
  // -------------------------------------------------------------------------
  // The fill
  // -------------------------------------------------------------------------

  group('the fill', () {
    testWidgets('is the colour the caller supplied, when it supplies one',
        (tester) async {
      const chosen = Color(0xFFAABBCC);

      final result = await _decorate(tester, fillColor: chosen);

      expect(result.decoration.color, chosen);
    });

    testWidgets('falls back to the system fill when the caller supplies none',
        (tester) async {
      final result = await _decorate(tester);

      expect(
        result.decoration.color,
        CupertinoColors.tertiarySystemFill.resolveFrom(result.context),
      );
    });

    testWidgets('resolves that fallback against the ambient brightness',
        (tester) async {
      // The differential that a missing `resolveFrom` fails: an unresolved
      // dynamic colour is the same object in both modes.
      final light = await _decorate(tester);
      final dark = await _decorate(tester, brightness: Brightness.dark);

      expect(dark.decoration.color, isNot(light.decoration.color));
    });

    testWidgets('a supplied fill is used verbatim in dark mode too',
        (tester) async {
      // The caller's colour is its own business — the fallback resolution
      // must not be applied to it.
      const chosen = Color(0xFFAABBCC);

      final result =
          await _decorate(tester, fillColor: chosen, brightness: Brightness.dark);

      expect(result.decoration.color, chosen);
    });
  });

  // -------------------------------------------------------------------------
  // The corner radius
  // -------------------------------------------------------------------------

  group('the corner radius', () {
    testWidgets('is the one the field style asked for', (tester) async {
      final result = await _decorate(tester, borderRadius: 14);

      expect(result.decoration.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('follows the argument rather than a house default',
        (tester) async {
      final tight = await _decorate(tester, borderRadius: 2);
      final round = await _decorate(tester, borderRadius: 24);

      expect(tight.decoration.borderRadius, BorderRadius.circular(2));
      expect(round.decoration.borderRadius, BorderRadius.circular(24));
    });
  });

  // -------------------------------------------------------------------------
  // Focus
  // -------------------------------------------------------------------------

  group('the border', () {
    testWidgets('is a hairline separator while the field is unfocused',
        (tester) async {
      final result = await _decorate(tester);

      expect(
        _side(result.decoration).color,
        CupertinoColors.separator.resolveFrom(result.context),
      );
      expect(_side(result.decoration).width, 0.5);
    });

    testWidgets('takes the theme\'s primary colour once focused',
        (tester) async {
      const accent = Color(0xFFD81B60);

      final result =
          await _decorate(tester, focused: true, primaryColor: accent);

      expect(_side(result.decoration).color, accent);
    });

    testWidgets('thickens on focus, so the change survives a colour-blind eye',
        (tester) async {
      final resting = await _decorate(tester);
      final focused = await _decorate(tester, focused: true);

      expect(_side(resting.decoration).width, lessThan(
        _side(focused.decoration).width,
      ));
      expect(_side(focused.decoration).width, 1.5);
    });

    testWidgets('resolves the resting separator against the brightness',
        (tester) async {
      final light = await _decorate(tester);
      final dark = await _decorate(tester, brightness: Brightness.dark);

      expect(_side(dark.decoration).color, isNot(_side(light.decoration).color));
    });
  });

  // -------------------------------------------------------------------------
  // Where the theme comes from
  // -------------------------------------------------------------------------

  group('under a Material app', () {
    // Cupertino fields are routinely used inside a Material shell, where
    // there is no CupertinoTheme of their own. `CupertinoTheme.of` derives one
    // from the Material theme, and the focused border has to follow it — a
    // hard-coded `activeBlue` would pass every test above and be wrong here.
    testWidgets('the focused border follows the Material primary colour',
        (tester) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A));
      late BoxDecoration decoration;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) {
              decoration = cupertinoFieldDecoration(
                context: context,
                borderRadius: 8,
                focused: true,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(_side(decoration).color, scheme.primary);
    });
  });
}
