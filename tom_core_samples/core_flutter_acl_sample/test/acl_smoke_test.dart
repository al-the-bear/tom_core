// Smoke tests: every ACL capability group builds and pumps without throwing.
//
// These guard the most common breakages — an ACL snippet whose `child` throws
// at build time, or a group that references an ACL API that no longer exists.
// Each test pumps a real [GroupScreen] inside a MaterialApp at a wide viewport
// so the responsive side-by-side cell layout is exercised too.

import 'package:core_flutter_acl_sample/acl_app.dart';
import 'package:core_flutter_acl_sample/common/showcase_section.dart';
import 'package:core_flutter_acl_sample/common/chrome_texts.dart';
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

  group('every ACL group builds', () {
    for (final group in aclGroups) {
      testWidgets('group "${group.id}" renders its cells', (tester) async {
        await pumpGroup(tester, group);

        // The group's title appears in the AppBar.
        expect(find.text(group.title), findsWidgets);
        // No exception was thrown while building the cells.
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('home screen lists every ACL group', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AclApp());
    await tester.pump();

    for (final group in aclGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });
}
