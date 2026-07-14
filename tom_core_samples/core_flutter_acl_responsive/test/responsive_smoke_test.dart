// Smoke tests: every responsive group screen builds and pumps at phone,
// tablet and desktop widths without throwing.
//
// These guard the most common showcase breakages — a bound form whose field
// throws at build time, a group referencing an API that no longer exists, or a
// responsive primitive that crashes at a particular width tier. Each group is
// pumped at three viewport widths so both the side-by-side and stacked cell
// regimes (and the per-tier style/layout resolutions) are exercised. Reflection
// is initialized once in setUpAll because the forms bind reflected entities.

import 'package:core_flutter_acl_responsive/common/showcase_section.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/showcase_app.dart';
import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // Mirror main(): install an empty provider so any singleton probe resolves.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  /// Pumps a group screen at [width] and returns any captured render errors.
  ///
  /// Several cells pin a preview to a fixed width (e.g. a 600px adaptive-sizing
  /// row, a 900px form-factor row) to show a width regime; rendered inside the
  /// narrow preview column of the showcase harness those can overflow by a few
  /// pixels. That is a harness artifact, not a defect in the mechanism under
  /// test — so the render errors are captured here and the caller asserts that
  /// none of them are anything other than a benign overflow. Mirrors the
  /// overflow-tolerant pattern in the verified `tom_flutter_form_test` demos.
  Future<List<FlutterErrorDetails>> pumpGroupAt(
    WidgetTester tester,
    ShowcaseGroup group,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: group)),
    );
    await tester.pump();
    return captured;
  }

  bool isOverflow(FlutterErrorDetails d) =>
      d.exception.toString().contains('overflowed');

  // One phone, one tablet, one desktop width — the three form-factor tiers.
  const widths = <(String, double)>[
    ('phone', 400),
    ('tablet', 800),
    ('desktop', 1200),
  ];

  group('every responsive group builds at each width tier', () {
    for (final group in responsiveGroups) {
      for (final (tier, width) in widths) {
        testWidgets('group "${group.id}" renders at $tier ($width)',
            (tester) async {
          final errors = await pumpGroupAt(tester, group, width);

          // The group's title appears in the AppBar.
          expect(find.text(group.title), findsWidgets);
          // The only tolerated render errors are benign preview overflows; any
          // other exception means a cell failed to build.
          final unexpected = errors.where((d) => !isOverflow(d)).toList();
          expect(unexpected, isEmpty,
              reason: 'group ${group.id} threw a non-overflow error: '
                  '${unexpected.map((d) => d.exception).join("; ")}');
        });
      }
    }
  });

  testWidgets('home screen lists every group', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResponsiveApp());
    await tester.pump();

    for (final group in responsiveGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });
}
