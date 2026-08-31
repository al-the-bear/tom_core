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

  // The README's chrome paragraph makes a claim about the source by
  // *enumeration*, which is the one shape of claim that a new file silently
  // falsifies: adding a seventh chrome class does not touch the README, so the
  // list quietly becomes "some of" while still reading as "all of". That is not
  // hypothetical — the list stood at four while the source had six, and the two
  // it had dropped were the app shell, the single most load-bearing case for a
  // paragraph whose whole point is that no raw widget survives.
  //
  // Checked one way only. Forward — every declared class is named — is exact.
  // The inverse would have to tolerate the names that are deliberately *not*
  // classes here (`MaterialApp`, `StatelessWidget`, `Column`, `Container`, all
  // cited as counter-examples), and an exclusion list for those would go stale
  // in the same way the enumeration did.
  test('the README names every chrome class that extends TomStatelessWidget',
      () {
    final readme = File('README.md');
    expect(readme.existsSync(), isTrue,
        reason: 'tests must run from the package root');

    // Anchored on the two phrases the claim cannot be made without, rather than
    // on a line number or heading. Requiring exactly one match is what keeps
    // the anchor honest: a second such paragraph would mean the claim had been
    // duplicated, and half of it could then drift unchecked.
    final claims = readme
        .readAsStringSync()
        .split('\n\n')
        .where((p) => p.contains('derive from') &&
            p.contains('`TomStatelessWidget`'))
        .toList();
    expect(claims, hasLength(1),
        reason: 'the README must state the chrome base-class claim in exactly '
            'one paragraph');
    final claim = claims.single;

    final declared = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match
          in RegExp(r'^class (\w+) extends TomStatelessWidget\b', multiLine: true)
              .allMatches(entity.readAsStringSync())) {
        declared[match.group(1)!] = entity.path;
      }
    }

    // A guard against the check passing vacuously — a moved directory or a
    // renamed base class would otherwise leave nothing to assert.
    expect(declared, hasLength(greaterThanOrEqualTo(6)),
        reason: 'expected the showcase chrome to still be built from '
            'TomStatelessWidget subclasses; found ${declared.length}');

    declared.forEach((name, path) {
      expect(claim, contains('`$name`'),
          reason: '$path declares $name, which extends TomStatelessWidget, but '
              'the README paragraph listing the chrome classes does not name '
              'it — the list reads as exhaustive and is not');
    });

    // The other half of the same sentence: "no raw StatelessWidget". Stated in
    // the README as a fact about the whole package, so it is checked there.
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      expect(
          RegExp(r'^class \w+ extends State(?:less|ful)Widget\b',
                  multiLine: true)
              .hasMatch(entity.readAsStringSync()),
          isFalse,
          reason: '${entity.path} declares a raw Flutter widget subclass; the '
              'README claims the package has none');
    }
  });
}
