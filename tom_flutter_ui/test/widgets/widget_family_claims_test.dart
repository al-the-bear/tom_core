import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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

/// A public top-level `class` declaration and its `extends`/`with` clause.
///
/// The leading alternation is Dart's modifier soup (`abstract final class`);
/// the second group is everything up to the opening brace, which is where the
/// superclass and the mixins are.
final _declaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'class\s+(Tom\w+)(?:<[^>]*>)?\s*([^{]*)\{',
  multiLine: true,
);

final _extendsClause = RegExp(r'extends\s+(\w+)');

/// Every Tom class declared under `lib/src/widgets/`, name → clause.
Map<String, String> _widgetKitClasses() {
  final out = <String, String>{};
  final files = Directory('lib/src/widgets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    for (final m in _declaration.allMatches(file.readAsStringSync())) {
      out[m.group(1)!] = m.group(2)!.split(RegExp(r'\s+')).join(' ');
    }
  }
  return out;
}

/// The twenty branch bases, read from `widget_base/` rather than listed here.
///
/// Deriving the set is what keeps this test from becoming a second hand-kept
/// copy of the catalogue it is guarding — adding a family base makes it a
/// family base here too, with no edit.
Set<String> _familyBases() {
  final source =
      File('lib/src/widget_base/tom_family_base.dart').readAsStringSync();
  return RegExp(r'class\s+(Tom\w+Base)\s+extends\s+TomFamilyBase')
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toSet();
}

/// The types under `widgets/` that are not widgets: a route, a static facade,
/// and seven plain classes that hold widgets without being one.
const _nonWidgets = {
  'TomAclBuilder',
  'TomDataCell',
  'TomDataColumn',
  'TomDataRow',
  'TomDialogs',
  'TomExpansionPanel',
  'TomMessenger',
  'TomPageRoute',
  'TomTreeNode',
};

/// The widgets that extend a Flutter widget directly and mix in
/// `TomWidgetMixin`, because their Flutter original must be a specific subtype
/// to satisfy the parent that accepts it.
const _mixinUsers = {
  'TomAnimatedPositioned',
  'TomAnimatedPositionedDirectional',
  'TomCheckedPopupMenuItem',
  'TomCupertinoTabView',
  'TomDropdownMenuItem',
  'TomExpanded',
  'TomFlexible',
  'TomNavigationDestination',
  'TomNavigationDrawerDestination',
  'TomPopupMenuDivider',
  'TomPopupMenuItem',
  'TomRefreshProgressIndicator',
  'TomSnackBar',
  'TomSnackBarAction',
  'TomSpacer',
  'TomTab',
  'TomTableCell',
};

/// A row of the family catalogue in `doc/widgets.md`: base, then the
/// representative widget names it claims report that family.
final _catalogueRow = RegExp(
  r'^\|\s*`(\w+)`\s*\|\s*`(Tom\w+Base)`\s*\|\s*([^|]+)\|',
  multiLine: true,
);

void main() {
  final classes = _widgetKitClasses();
  final bases = _familyBases();
  String? parentOf(String name) =>
      _extendsClause.firstMatch(classes[name] ?? '')?.group(1);

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
      expect(mixers, _mixinUsers);
    });

    test('tccf1-04: the remaining 9 types are not widgets at all', () {
      final rest = classes.keys
          .where((n) => !bases.contains(parentOf(n)))
          .where((n) => !classes[n]!.contains('TomWidgetMixin'))
          .toSet();
      expect(rest, _nonWidgets);
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
}

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}
