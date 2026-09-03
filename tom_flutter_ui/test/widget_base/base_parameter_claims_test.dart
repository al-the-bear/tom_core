import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// What a Tom widget accepts is one list, and the documents that enumerate
// it have to quote that list rather than a remembered version of it.
//
// The list has drifted twice. `lib/src/widgets/readme.md` named four
// parameters, then five, while the constructor took six the whole time — a
// reader following the readme would not have known `uiStateController` (the
// kit's only build-time hook) or `key` were accepted at all. Both times the
// prose was edited and the constructor was not, because nothing connected
// them.
//
// This file is that connection. Everything below is *derived* from
// `tom_family_base.dart`; no parameter name is written out as a fact. Add a
// seventh parameter to the base and these tests describe seven, and the
// documents that still describe six are what fails.

/// The `super.x` / `this.x` parameter names of the first constructor declared
/// in [source] after [className], in declaration order.
///
/// Deliberately positional-order-preserving: the readme presents the list as a
/// table, and a table whose rows are shuffled relative to the signature is
/// still misleading even when the set matches.
List<String> constructorParameters(String source, String className) {
  // Throws rather than `expect`s: this runs while `main` is still building the
  // suite, where `expect` has no test to fail and reports an
  // `OutsideTestException` instead of the missing constructor.
  final open = RegExp('$className\\(\\{').firstMatch(source);
  if (open == null) throw StateError('no `$className({` in source');
  final close = source.indexOf('})', open.end);
  if (close < 0) throw StateError('unterminated `$className({`');
  final body = source.substring(open.end, close);
  return RegExp(
    r'(?:super|this)\.(\w+)',
  ).allMatches(body).map((m) => m.group(1)!).toList();
}

/// The bare `` `name` `` cells in the first column of the first markdown table
/// that follows [heading] in [source].
List<String> firstColumnAfter(String source, String heading) {
  final start = source.indexOf(heading);
  if (start < 0) throw StateError('no `$heading` in the document');
  final rows = <String>[];
  var seenTable = false;
  for (final line in source.substring(start).split('\n')) {
    final cell = RegExp(r'^\|\s*`(\w+)`\s*\|').firstMatch(line);
    if (cell != null) {
      seenTable = true;
      rows.add(cell.group(1)!);
    } else if (seenTable && !line.trimLeft().startsWith('|')) {
      break;
    }
  }
  return rows;
}

String _read(String path) => File(path).readAsStringSync();

const _numberWords = {
  1: 'one',
  2: 'two',
  3: 'three',
  4: 'four',
  5: 'five',
  6: 'six',
  7: 'seven',
  8: 'eight',
};

void main() {
  final familyBaseSource = _read('lib/src/widget_base/tom_family_base.dart');
  final baseParameters = constructorParameters(
    familyBaseSource,
    'TomFamilyBase',
  );

  group('base parameter claims', () {
    test('tcinc807-01: the family base takes key plus the five policy '
        'parameters', () {
      // The one place the list is written down twice — here and in the
      // constructor — because a derived list that derives from itself checks
      // nothing. Every other assertion in this file reads `baseParameters`.
      expect(baseParameters, [
        'key',
        'tomId',
        'tomGroup',
        'scope',
        'authorizer',
        'uiStateController',
      ]);
    });

    test('tcinc807-02: every branch base forwards exactly the same list', () {
      final branches = RegExp(
        r'class\s+(Tom\w+Base)\s+extends\s+TomFamilyBase',
      ).allMatches(familyBaseSource).map((m) => m.group(1)!).toList();

      expect(branches, hasLength(20), reason: 'the twenty family branches');
      for (final branch in branches) {
        expect(
          constructorParameters(familyBaseSource, branch),
          baseParameters,
          reason: '$branch does not forward the base list unchanged',
        );
      }
    });

    test('tcinc807-03: TomNodeBase declares the same list', () {
      // `TomFamilyBase` forwards with `super.`, so the names it can use are
      // fixed by the node base two levels up. Pinning it here means a rename
      // there cannot leave the family base compiling against a stale name.
      expect(
        constructorParameters(
          _read('lib/src/widget_base/tom_node_base.dart'),
          'TomNodeBase',
        ),
        baseParameters,
      );
    });

    test('tcinc807-04: TomWidgetMixin exposes the five non-key members', () {
      // The kit's second route to the widget surface. `key` is Flutter's, so
      // the mixin has nothing to say about it; the other five it must declare
      // itself, or the seventeen widgets that use it accept less than the 273
      // that extend a base — which is the claim the readme makes for both.
      final declared = RegExp(r'get\s+(\w+)\s*(?:=>\s*null)?;')
          .allMatches(_read('lib/src/groups/tom_widget_mixin.dart'))
          .map((m) => m.group(1)!)
          .toSet();

      for (final name in baseParameters.where((p) => p != 'key')) {
        expect(
          declared,
          contains(name),
          reason: 'TomWidgetMixin does not expose `$name`',
        );
      }
    });

    test('tcinc807-05: the widgets readme tables the list in signature '
        'order', () {
      final readme = _read('lib/src/widgets/readme.md');
      expect(
        firstColumnAfter(readme, 'base parameters'),
        baseParameters,
        reason: 'the readme parameter table has drifted from the constructor',
      );
    });

    test('tcinc807-06: prose counting the base parameters counts them '
        'right', () {
      final word = _numberWords[baseParameters.length];
      expect(word, isNotNull, reason: 'extend _numberWords');

      final claim = RegExp(
        r'(?:\b(\w+)\b|(\d+))\s+(?:base|common|shared)\s+parameters',
        caseSensitive: false,
      );
      var found = 0;
      for (final file
          in Directory('.')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.md'))
              .where((f) => !f.path.contains('/build/'))) {
        for (final m in claim.allMatches(file.readAsStringSync())) {
          found++;
          expect(
            (m.group(1) ?? m.group(2))!.toLowerCase(),
            anyOf(word, '${baseParameters.length}'),
            reason: '${file.path} miscounts the base parameters',
          );
        }
      }
      expect(found, greaterThan(0), reason: 'no document states the count');
    });
  });
}
