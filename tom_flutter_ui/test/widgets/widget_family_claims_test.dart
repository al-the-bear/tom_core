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
    test('tccf1-01: widgets/ declares 301 Tom types', () {
      expect(classes.length, 301);
    });

    test('tccf1-02: 275 of them extend one of the 20 family bases', () {
      expect(bases.length, 20);
      final extenders =
          classes.keys.where((n) => bases.contains(parentOf(n))).toList();
      expect(extenders.length, 275);
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
}

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}
