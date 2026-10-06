// Smoke tests: every ACL capability group builds, and every cell's live demo
// is visible.
//
// These guard the most common breakages — an ACL snippet whose `child` throws
// at build time, a group that references an ACL API that no longer exists, and
// a demo the engine lays out with no area (see `visible_demos.dart` for why
// "nothing threw" does not cover that). Each test pumps a real [GroupScreen]
// inside a MaterialApp at a wide viewport so the responsive side-by-side cell
// layout is exercised too, and tall enough that the lazy list builds every
// cell, so none escapes the measurement.

import 'package:core_flutter_acl_sample/acl_app.dart';
import 'package:core_flutter_acl_sample/common/showcase_section.dart';
import 'package:core_flutter_acl_sample/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'visible_demos.dart';

void main() {
  setUp(() {
    // Mirror main(): install the chrome bundle so TomCtr.text resolves rather
    // than echoing the key back as a development indicator.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
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

  group('every ACL group builds', () {
    for (final group in aclGroups) {
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

  testWidgets('home screen lists every ACL group', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AclApp());
    await tester.pump();

    for (final group in aclGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });
}
