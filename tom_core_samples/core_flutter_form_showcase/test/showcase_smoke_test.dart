// Smoke tests: every group screen builds and pumps without throwing.
//
// These guard the most common showcase breakages — a bound form whose field
// throws at build time, or a group referencing an API that no longer exists.
// Each test pumps a real [GroupScreen] at a wide viewport so the responsive
// side-by-side cell layout is exercised too. Reflection is initialized once in
// setUpAll because the forms bind reflected entities.

import 'package:core_flutter_form_showcase/common/showcase_section.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:core_flutter_form_showcase/showcase_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    // Mirror main(): install an empty provider so any singleton probe resolves.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
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
