// Smoke tests: every group screen builds and pumps without throwing.
//
// These guard against the most common showcase breakages — a snippet whose
// `child` widget throws at build time, or a group that references an API that
// no longer exists. Each test pumps a real [GroupScreen] inside a MaterialApp
// at a wide viewport so the responsive side-by-side layout is exercised too.
//
// The last test guards the other half of the same promise. The README opens its
// group list with "Each group below maps to one file in `lib/groups/` and one
// screen in the app" — so the index has an app side, asserted by pumping, and a
// document side, asserted by reading.

import 'dart:io';

import 'package:core_flutter_ui_showcase/common/showcase_section.dart';
import 'package:core_flutter_ui_showcase/showcase_app.dart';
import 'package:core_flutter_ui_showcase/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUp(() {
    // Mirror main(): install the chrome bundle so TomCtr.text resolves rather
    // than echoing the key back as a development indicator.
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

    await tester.pumpWidget(ShowcaseApp());
    await tester.pump();

    for (final group in showcaseGroups) {
      expect(find.text(group.title), findsOneWidget);
    }
  });

  // A reader matching the README's sections against the running app has only
  // the heading to go on, so a heading that names no screen sends them looking
  // for something that does not exist. Pairing each section with the file it
  // cites — rather than just checking the set of names — also catches two
  // sections swapping headings, which reads as correct from either end.
  test('the README documents every group under its real title', () {
    final readme = File('README.md');
    expect(readme.existsSync(), isTrue,
        reason: 'tests must run from the package root');

    final sections = <String, String>{};
    for (final match in RegExp(r'^### (.+?) — `(groups/\w+\.dart)`$',
            multiLine: true)
        .allMatches(readme.readAsStringSync())) {
      sections[match.group(2)!] = match.group(1)!;
    }

    expect(sections, hasLength(showcaseGroups.length),
        reason: 'the README must document each of the '
            '${showcaseGroups.length} groups in exactly one "### <title> — '
            '`groups/<file>.dart`" section');

    sections.forEach((path, heading) {
      final file = File('lib/$path');
      expect(file.existsSync(), isTrue,
          reason: 'README section "$heading" cites $path, which does not exist');
      expect(file.readAsStringSync(), contains("title: '$heading',"),
          reason: 'README section "$heading" cites $path, but that group does '
              'not declare that title — the app bar and home index show the '
              'declared one, so a reader matching the README against the '
              'running app finds no such screen');
    });
  });
}
