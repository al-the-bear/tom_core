/// Probes what `buildConvenienceDetector` actually decides, rather than
/// inferring it from reading the branches.
///
/// The facet that needed probing is **height**, because it is the only one
/// whose input can be absent. `AclDeviceContext.height` is `double?`, and the
/// container supplies `null` for it whenever the incoming constraints have
/// unbounded height (`acl_container.dart`, `canExpandVertically ?
/// constraints.maxHeight : null`) — that is, whenever the container
/// shrink-wraps its content, which is the ordinary case inside a `Column`, a
/// `ListView`, or any scrollable.
///
/// The consequence is not obvious from the call site and was documented
/// nowhere: **a variant gated on `height` never activates in a shrink-wrapping
/// container**, and the row silently falls back to its default variant. That
/// is defensible — an unbounded height is not a *short* one, so "activate when
/// the viewport is shorter than 500" should indeed not fire — but a reader who
/// has not been told will read the missing variant as a bug in their own
/// layout.
///
/// So the rule is pinned twice: once on the predicate in isolation, and once
/// through a real render, where the fallback to the default variant is what
/// the author actually sees.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A device context with every facet fixed except the ones a test varies.
///
/// The defaults are deliberately unremarkable — a bounded 800×600 pointer
/// desktop — so that when a detector returns `false` the only candidate
/// explanation is the facet under test.
AclDeviceContext _dc({
  double width = 800,
  double? height = 600,
  AclInputMode inputMode = AclInputMode.pointer,
  AclFormFactor formFactor = AclFormFactor.tablet,
  double accessibilityScale = 1.0,
}) {
  return AclDeviceContext(
    width: width,
    height: height,
    inputMode: inputMode,
    formFactor: formFactor,
    orientation: Orientation.landscape,
    platform: TargetPlatform.linux,
    isWeb: false,
    density: AclDensity.standard,
    textDirection: TextDirection.ltr,
    accessibilityScale: accessibilityScale,
  );
}

/// Pumps a throwaway tree and returns a real `BuildContext`.
///
/// The convenience detector never reads the context or the `Acl?` — but the
/// `AclVariantDetector` signature requires both, and faking a `BuildContext`
/// costs far more than pumping one.
Future<BuildContext> _someContext(WidgetTester tester) async {
  const key = ValueKey('detector-probe-host');
  await tester.pumpWidget(const MaterialApp(home: SizedBox(key: key)));
  return tester.element(find.byKey(key));
}

void main() {
  group('the height facet, probed directly', () {
    testWidgets('matches when the device is shorter than the bound', (
      tester,
    ) async {
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(height: 500)!;
      expect(detector(_dc(height: 400), null, context), isTrue);
    });

    testWidgets('does not match when the device is taller', (tester) async {
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(height: 500)!;
      expect(detector(_dc(height: 600), null, context), isFalse);
    });

    testWidgets('the bound is exclusive — equal height does not match', (
      tester,
    ) async {
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(height: 500)!;
      expect(detector(_dc(height: 500), null, context), isFalse);
    });

    testWidgets('an unknown height does not match, whatever the bound', (
      tester,
    ) async {
      // The case this file exists for. `null` is not treated as "no
      // constraint on this axis" and does not fall back to a default height:
      // it fails the facet outright.
      final context = await _someContext(tester);
      for (final bound in <double>[1, 500, 100000]) {
        final detector = AclDeviceContext.buildConvenienceDetector(
          height: bound,
        )!;
        expect(
          detector(_dc(height: null), null, context),
          isFalse,
          reason: 'height: $bound should not match an unknown device height',
        );
      }
    });

    testWidgets('an unknown height is irrelevant when no height is asked for', (
      tester,
    ) async {
      // Establishes that the veto above comes from the *facet*, not from the
      // context being somehow malformed — the same context matches happily on
      // every other facet.
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(
        formFactor: AclFormFactor.tablet,
      )!;
      expect(detector(_dc(height: null), null, context), isTrue);
    });

    testWidgets('an unknown height vetoes an otherwise matching spec', (
      tester,
    ) async {
      // AND semantics: every other facet agrees, and the detector still
      // returns false. This is the shape of the surprise — the author sees a
      // spec that describes their device exactly, and no variant.
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(
        height: 500,
        formFactor: AclFormFactor.tablet,
        input: AclInputMode.pointer,
      )!;
      expect(detector(_dc(height: null), null, context), isFalse);
    });
  });

  group('the sibling bounds, for contrast', () {
    testWidgets('width is an exclusive upper bound like height', (
      tester,
    ) async {
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(width: 600)!;
      expect(detector(_dc(width: 599), null, context), isTrue);
      expect(detector(_dc(width: 600), null, context), isFalse);
      expect(detector(_dc(width: 601), null, context), isFalse);
    });

    testWidgets('minAccessibilityScale is an inclusive lower bound', (
      tester,
    ) async {
      // The opposite direction and the opposite inclusivity from width/height
      // — worth pinning, because the parameter list gives no hint that the
      // two numeric facets disagree about which way they point.
      final context = await _someContext(tester);
      final detector = AclDeviceContext.buildConvenienceDetector(
        minAccessibilityScale: 1.5,
      )!;
      expect(detector(_dc(accessibilityScale: 1.4), null, context), isFalse);
      expect(detector(_dc(accessibilityScale: 1.5), null, context), isTrue);
      expect(detector(_dc(accessibilityScale: 1.6), null, context), isTrue);
    });
  });

  group('the unknown-height rule, probed through a real render', () {
    // The predicate tests above pin the decision; these pin what an author
    // actually sees, which is a component swap they did not ask for.

    /// A one-row layout whose row holds a height-gated variant component and a
    /// default one. Exactly one of the two survives inline-variant filtering.
    Widget buildHeightGatedRow() {
      return AclBuilder()
          .startVariant(height: 500)
          .append(const Text('SHORT'))
          .endVariant()
          .startVariant()
          .append(const Text('DEFAULT'))
          .endVariant()
          .build();
    }

    testWidgets('a bounded, short container activates the height variant', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: buildHeightGatedRow(),
            ),
          ),
        ),
      );
      expect(find.text('SHORT'), findsOneWidget);
      expect(find.text('DEFAULT'), findsNothing);
    });

    testWidgets('an unbounded container falls back to the default variant', (
      tester,
    ) async {
      // A Column gives its non-flex children unbounded height, so the ACL
      // shrink-wraps and reports `height: null` — even though the rendered
      // result is only a line or two tall, and so "shorter than 500" by any
      // reading an author would apply.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [buildHeightGatedRow()],
              ),
            ),
          ),
        ),
      );
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('SHORT'), findsNothing);
    });
  });
}
