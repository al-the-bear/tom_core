// Smoke tests: every group screen builds, and every cell's live demo is
// visible.
//
// These guard the most common showcase breakages — a bound form whose field
// throws at build time, a group referencing an API that no longer exists, and a
// demo laid out with no area (see `visible_demos.dart` for why "nothing threw"
// does not cover that). Each test pumps a real [GroupScreen] at a wide viewport
// so the responsive side-by-side cell layout is exercised too, and tall enough
// that the lazy list builds every cell, so none escapes the measurement.
// Reflection is initialized once in setUpAll because the forms bind reflected
// entities.

import 'package:core_flutter_form_showcase/common/showcase_section.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:core_flutter_form_showcase/showcase_app.dart';
import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'visible_demos.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // Mirror main(): install the union bundle (chrome + validator messages) so
    // TomCtr.text resolves rather than echoing the key back as a development
    // indicator.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  /// Tall enough for the longest group, so the list builds every cell.
  const viewportHeight = 20000.0;

  Future<void> pumpGroup(WidgetTester tester, ShowcaseGroup group) async {
    tester.view.physicalSize = const Size(1200, viewportHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: GroupScreen(group: group)));
    await tester.pump();
  }

  group('every showcase group builds', () {
    for (final group in showcaseGroups) {
      testWidgets('group "${group.id}" renders its cells visibly', (
        tester,
      ) async {
        await pumpGroup(tester, group);

        // The group's title appears in the AppBar.
        expect(find.text(group.title), findsWidgets);
        // No exception was thrown while building the cells.
        expect(tester.takeException(), isNull);
        // Every cell was built, so every cell is measured below.
        final cellCount = group
            .cells(tester.element(find.byType(GroupScreen)))
            .length;
        expect(
          builtCellCount(),
          cellCount,
          reason: 'raise viewportHeight: the list did not build every cell',
        );
        // Every demo, and every label in it, occupies area.
        final audit = auditDemos();
        expect(audit.faults, isEmpty);
        expect(audit.demosMeasured, cellCount);
      });
    }
  });

  testWidgets('home screen lists every group', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ShowcaseApp());
    await tester.pump();

    for (final group in showcaseGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });
}
