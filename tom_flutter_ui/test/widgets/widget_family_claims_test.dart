import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'widget_census.dart';

// tccf1: what the kit's documents may claim about widget families.
//
// Four documents said, without qualification, that *every* widget in the kit
// extends a family base and therefore reports its family. It was never true:
// seventeen wrappers extend a Flutter widget directly and mix in
// `TomWidgetMixin`, and nine types under `widgets/` are not widgets at all.
// The claim rotted the way unqualified claims do — silently, and in the one
// place where it was checkable: `doc/widgets.md` listed `TomAppBar` as a
// representative of the `container` family while `TomAppBar` had no `family`
// getter, and listed `TomSliverList` under `sliver` while it extends
// `TomContainerBase`.
//
// The counts below are therefore asserted from the source rather than trusted
// from the prose, and the catalogue is checked against the class declarations
// it names. A document that quotes a number this file does not agree with is
// wrong, and this file is what says so.

/// A row of the family catalogue in `doc/widgets.md`: base, then the
/// representative widget names it claims report that family.
final _catalogueRow = RegExp(
  r'^\|\s*`(\w+)`\s*\|\s*`(Tom\w+Base)`\s*\|\s*([^|]+)\|',
  multiLine: true,
);

/// A sentence that states the size of the widget kit.
///
/// Three digits, then up to three filler words, then a noun that means "the
/// widget kit". Two digits is deliberately not matched: "18 widgets have
/// wrapping problems" and "20 branch bases" are *subset* counts, true of a
/// part rather than of the whole, and every kit-wide total worth guarding —
/// 299, 290, 273 — happens to be three digits. The small kit-wide numbers are
/// not left unguarded either; they are pinned by name above (`tccf1-02` fixes
/// 20, `tccf1-03` fixes 17, `tccf1-04` fixes 9).
final _censusClaim = RegExp(
  r'(\d{3})(\+?)\s+(?:(?:[A-Za-z-]+|\d+)\s+){0,3}'
  r'(?:wrappers|widgets|widget classes|Tom types|types)',
);

/// Every document and source comment in the package that could make a claim.
Iterable<File> _prose() sync* {
  for (final dir in const ['doc', 'lib', 'test', 'example']) {
    yield* Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        // Generated reflection files are megabytes of literals in which
        // three-digit runs occur by coincidence; nobody reads them and nobody
        // edits them, so they make no claims.
        .where((f) => !f.path.endsWith('.reflection.dart'))
        .where((f) => f.path.endsWith('.md') || f.path.endsWith('.dart'));
  }
  yield File('CHANGELOG.md');
  yield File('README.md');
}

void main() {
  final classes = widgetKitClasses();
  final bases = familyBases();
  String? parentOf(String name) => parentIn(classes[name]);

  group('tccf1: the family census the documents quote', () {
    test('tccf1-01: widgets/ declares 299 Tom types', () {
      expect(classes.length, 299);
    });

    test('tccf1-02: 273 of them extend one of the 20 family bases', () {
      expect(bases.length, 20);
      final extenders =
          classes.keys.where((n) => bases.contains(parentOf(n))).toList();
      expect(extenders.length, 273);
    });

    test('tccf1-03: 17 widgets mix TomWidgetMixin instead of a family base',
        () {
      final mixers = classes.entries
          .where((e) => !bases.contains(parentOf(e.key)))
          .where((e) => e.value.contains('TomWidgetMixin'))
          .map((e) => e.key)
          .toSet();
      expect(mixers, mixinSurfaceWidgets);
    });

    test('tccf1-04: the remaining 9 types are not widgets at all', () {
      final rest = classes.keys
          .where((n) => !bases.contains(parentOf(n)))
          .where((n) => !classes[n]!.contains('TomWidgetMixin'))
          .toSet();
      expect(rest, nonWidgetTypes);
    });

    test('tccf1-05: every family-base extender reaches TomFamilyBase directly',
        () {
      // No widget extends `TomFamilyBase`, `TomPolicyNodeBase` or
      // `TomNodeBase` itself: the family tag always comes from a branch base,
      // which is what makes "the row's base" a complete answer.
      final direct = classes.keys.where((n) => const [
            'TomFamilyBase',
            'TomPolicyNodeBase',
            'TomNodeBase',
          ].contains(parentOf(n)));
      expect(direct, isEmpty);
    });
  });

  group('tccf1: the family catalogue names only widgets that report its family',
      () {
    final doc = File('doc/widgets.md').readAsStringSync();
    final rows = _catalogueRow.allMatches(doc).toList();

    test('tccf1-06: the catalogue has one row per family base', () {
      expect(rows.length, bases.length);
      expect(rows.map((m) => m.group(2)!).toSet(), bases);
    });

    test('tccf1-07: every representative extends the base its row claims', () {
      final wrong = <String>[];
      for (final row in rows) {
        final base = row.group(2)!;
        for (final m in RegExp(r'`(Tom\w+)`').allMatches(row.group(3)!)) {
          final name = m.group(1)!;
          if (!classes.containsKey(name)) {
            wrong.add('$name (row $base): not declared under widgets/');
          } else if (parentOf(name) != base) {
            wrong.add('$name (row $base): extends ${parentOf(name)}');
          }
        }
      }
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });
  });

  group('tccf1: TomAppBar is a container-family policy node', () {
    tearDown(TomAuthorization.reset);

    test('tccf1-08: it reports the family its catalogue row claims', () {
      final bar = TomAppBar(tomId: 'bar', titleText: 'Title');
      expect(bar.family, TomWidgetFamily.container);
      expect(bar.isFamily(TomWidgetFamily.container), isTrue);
      expect(bar.families, {TomWidgetFamily.container});
    });

    testWidgets('tccf1-09: a none TomAppBar renders nothing', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'bar': TomAuthState.none});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(appBar: TomAppBar(tomId: 'bar', titleText: 'Title')),
      ));
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('tccf1-10: a full TomAppBar renders its title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(appBar: TomAppBar(tomId: 'bar', titleText: 'Title')),
      ));
      expect(find.text('Title'), findsOneWidget);
    });
  });

  // The family census above answers "what is this widget for". These two
  // answer "what does it look like", which the module readme spent a release
  // getting wrong: it told the reader each widget "renders Material or
  // Cupertino per the ambient family". Nothing in the kit has ever done that,
  // and `family` is not a design language — so the sentence was false twice
  // over, in a document a reader consults precisely because they do not yet
  // know which of the two they get.
  group('tccf1: the kit does not choose a design language', () {
    test('tccf1-11: no wrapper reads the platform to decide how to render', () {
      // These four are the ways a Flutter widget picks a design language at
      // runtime. `.adaptive(` is the one worth naming: `Switch.adaptive` and
      // `CircularProgressIndicator.adaptive` are Flutter's own opt-in, and a
      // wrapper delegating to one would make the readme's claim true again
      // without anyone editing the readme.
      final probes = RegExp(r'defaultTargetPlatform|Platform\.is|'
          r'CupertinoUserInterfaceLevel|\.adaptive\(');
      final faults = <String>[];
      final files = Directory('lib/src/widgets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (probes.hasMatch(lines[i])) {
            faults.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(faults, isEmpty,
          reason: 'a wrapper now varies its rendering by platform, so '
              'lib/src/widgets/readme.md is wrong to say the design language '
              'is the call site\'s choice: $faults');
    });

    test('tccf1-12: the readme states the Cupertino census source gives', () {
      final cupertino = classes.keys.where((c) => c.startsWith('TomCupertino'));
      // A "sibling" is the same name without the Cupertino infix — the only
      // pairing a call site can use without consulting a table. It is also the
      // claim that is easy to over-generalise: two thirds of these wrappers
      // cover a control Material has no equivalent for, so a blanket
      // `Tom*` / `TomCupertino*` pairing would be a second false claim
      // replacing the first.
      final paired = cupertino
          .where((c) => classes.containsKey('Tom${c.substring(12)}'))
          .toList();
      expect(cupertino, hasLength(35));
      expect(paired, hasLength(11));

      final readme = File('lib/src/widgets/readme.md').readAsStringSync();
      expect(readme, contains('${cupertino.length} of the wrappers'));
      expect(readme, contains('only ${paired.length} have'));
      expect(readme, isNot(contains('ambient family')));
    });
  });

  group('tccf1: the kit ships no deprecated surface', () {
    test('tccf1-13: no public type under widgets/ carries @Deprecated', () {
      // `TomMaterialButton` and `TomButtonBar` sat behind a "wrapped for
      // migration of existing codebases" banner. There were no existing
      // codebases: nothing in tom_core is published. A deprecation marker is a
      // promise about a transition, and with nobody transitioning the two
      // wrappers only inflated the census every document quotes — while
      // `doc/widgets.md` catalogued the button family without ever saying two
      // of its members were on the way out.
      //
      // The rule for an unpublished kit is therefore simply: delete it now.
      // Deprecating instead defers a free removal until it is expensive.
      final faults = <String>[];
      final files = Directory('lib/src/widgets')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('@Deprecated')) {
            faults.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(faults, isEmpty,
          reason: 'nothing in this package is published, so a deprecated type '
              'has no migration to support — delete it instead: $faults');
    });
  });

  // The group above pins what the *family* catalogue may say. This one pins
  // the plainer claim that turned out to rot faster: how big the kit is.
  //
  // Deleting two wrappers left six documents quoting 292, 275 and 301 — an
  // example header, a CHANGELOG entry, two design documents and two test
  // preambles — and nothing failed, because the only census guard in the
  // package (`tccf1-12`) reads exactly one file. A count is the cheapest thing
  // in a document to get wrong: it is a fact about code, written in prose,
  // that no compiler and no reader can check. So it is checked here, for every
  // document at once, against the scan.
  group('tccf1: no document quotes a census the source disagrees with', () {
    final extenders =
        classes.keys.where((n) => bases.contains(parentOf(n))).length;
    // Derived, so the guard cannot itself go stale: adding a widget moves the
    // permitted values with it, and the documents that quoted the old ones
    // fail until they are updated.
    final census = <int>{
      classes.length,
      classes.length - nonWidgetTypes.length,
      extenders,
    };

    test('tccf1-14: every three-digit kit count is one the scan produces', () {
      final faults = <String>[];
      for (final file in _prose()) {
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          for (final m in _censusClaim.allMatches(lines[i])) {
            final where = '${file.path}:${i + 1}: "${m.group(0)}"';
            if (!census.contains(int.parse(m.group(1)!))) {
              faults.add('$where — the kit is $census');
            } else if (m.group(2)!.isNotEmpty) {
              // The implementation-status list hedged the wrapped-widget count
              // with a trailing `+`, which read as caution and was wrong by
              // nine. A hedge on a number the suite counts exactly is not
              // caution; it is a licence never to recount.
              faults.add('$where — a counted census does not take a "+"');
            }
          }
        }
      }
      expect(faults, isEmpty, reason: faults.join('\n'));
    });

    test('tccf1-15: the wrapped-per-family table totals the widget count', () {
      // The one census claim `tccf1-14` cannot read: a markdown table cell is
      // a bare number with no noun beside it. It is also the claim most likely
      // to be edited carelessly, because correcting it means finding *which*
      // family row lost a widget — so the row sum is asserted too, and a
      // totals row patched without its rows fails.
      final doc = File('doc/tom_ui_flutter_widgets.md').readAsStringSync();
      final rows = RegExp(r'^\|\s*\*\*([^*]+)\*\*\s*\|\s*\*{0,2}(\d+)\*{0,2}',
              multiLine: true)
          .allMatches(doc)
          .toList();
      final totals = rows.where((m) => m.group(1)!.trim() == 'Totals');
      expect(totals, hasLength(1), reason: 'no Totals row to check');

      final stated = int.parse(totals.single.group(2)!);
      final summed = rows
          .where((m) => m.group(1)!.trim() != 'Totals')
          .fold(0, (sum, m) => sum + int.parse(m.group(2)!));
      expect(summed, stated, reason: 'the family rows do not sum to the total');
      expect(stated, classes.length - nonWidgetTypes.length,
          reason: 'the table counts wrapped widgets, so its total is the kit');
    });
  });
}

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}
