// Smoke tests: every group screen builds and pumps without throwing.
//
// These guard against the most common showcase breakages — a snippet whose
// `child` widget throws at build time, or a group that references an API that
// no longer exists. Each test pumps a real [GroupScreen] inside a MaterialApp
// at a wide viewport so the responsive side-by-side layout is exercised too.

import 'package:core_flutter_ui_showcase/common/showcase_section.dart';
import 'package:core_flutter_ui_showcase/showcase_app.dart';
import 'package:core_flutter_ui_showcase/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUp(() {
    // Mirror main(): install an empty provider so any singleton probe resolves.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  Future<void> pumpGroup(WidgetTester tester, ShowcaseGroup group) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: group)),
    );
    await tester.pump();
  }

  group('every showcase group builds', () {
    for (final group in showcaseGroups) {
      testWidgets('group "${group.id}" renders its cells', (tester) async {
        await pumpGroup(tester, group);

        // The group's title appears in the AppBar.
        expect(find.text(group.title), findsWidgets);
        // No exception was thrown while building the cells.
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('home screen lists every group', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();

    for (final group in showcaseGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });
}
