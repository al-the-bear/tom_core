/// Pins that the text this package ships stands on its own — that a reader who
/// has only `tom_flutter_ui` can resolve everything its comments point at.
///
/// The failure this guards has now happened twice, in two unrelated units, so
/// it is a package property rather than a unit one. Source comments here have
/// named parts of *other* projects' specifications — `CE-LO` and `CE-EL`
/// (CodeSpecs concern-extension part ids), `D09 XDS` (a tom_specs document),
/// `csexb2` and `CSEXB1` (ids of items in another quest's task list). Those
/// live in documents this package neither ships nor depends on, so to a reader
/// they are noise that looks like it ought to mean something; the last of them
/// was not even a document, but an entry in a backlog.
///
/// Two of the occurrences were in rendered dartdoc, which is the sharpest form
/// of the defect: the reader who could have followed the citation is not the
/// reader the API documentation is written for. Every occurrence found so far
/// either stood beside a sentence that survived its removal, or stood for a
/// fact that could simply be stated — so the remedy is always to state the
/// fact and drop the citation, never to expand the id in place.
///
/// The sweep covers `lib` and `test` wholesale rather than a named unit:
/// jargon spreads by copy-paste, and a test header is as public as a dartdoc
/// once someone reads the suite to learn a feature.
///
/// **Not the same rule as the read-as-is guards**, and folding it into them
/// would lose cases. `tom_core_kernel/test/comments_read_as_is_test.dart` and
/// `tool/check_comments_read_as_is.py` match a *shape* — letters then digits,
/// in either case — against a closed vocabulary of ordinary and published
/// words. Two of the three tokens here have no such shape at all: `CE-LO` is
/// hyphenated with no digit run, and `XDS` carries no digits. The third,
/// `CSEXB1`, the ALL-CAPS shape does now reach, but its lowercase twin
/// `csexb2` is caught here and only here, because a lowercase run of six
/// letters followed by a digit is what half this package's fixtures look like.
/// This guard names three specific vocabularies from three specific outside
/// documents; the shape guards name a class. Keep both.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The trees swept. Everything the package ships plus everything a reader of
/// the suite sees.
const _sweptRoots = <String>['lib', 'test'];

/// This guard, excluded from its own sweep — it necessarily quotes every token
/// it forbids.
const _selfName = 'shipped_text_test.dart';

/// Tokens that belong to another project's specification and cannot be
/// resolved from this package.
///
/// Each entry pairs the pattern with what it actually denoted, because the
/// point of the failure message is to tell whoever hits it what to write
/// *instead*.
const _jargon = <(String, String)>[
  (r'\bCE-[A-Z]{2}\b', 'a CodeSpecs part id (CE-LO = Layout, CE-EL = Element)'),
  // Deliberately the bare token and not `D\d\d XDS`: the document number is
  // how it was written here, but the acronym alone is equally unresolvable and
  // matching both would report one site twice.
  (
    r'\bXDS\b',
    "tom_specs' Experience Design Specification, cited as `D09 XDS`",
  ),
  // The suffix letter is matched case-insensitively on purpose. The first
  // version of this pattern wrote it `[a-z]?`, which matches `csexb2` but not
  // `CSEXB1` — and `CSEXB1` was exactly what the next occurrence turned out to
  // be, so the guard would have passed over it.
  (
    r'\b[Cc][Ss][Ee][Xx][A-Za-z]?\d+\b',
    'a tom_specs quest todo id (csexb2, CSEXB1)',
  ),
];

/// Every `.dart` and `.md` file under [_sweptRoots], except this one.
List<File> _sweptFiles() {
  return _sweptRoots
      .expand((root) => Directory(root).listSync(recursive: true))
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.md'))
      .where((f) => !f.path.endsWith(_selfName))
      .toList();
}

void main() {
  group('no shipped text names another project\'s specification', () {
    late List<File> swept;

    setUpAll(() => swept = _sweptFiles());

    // A sweep that silently stopped finding files would report "no violations"
    // forever. Name one file from each tree, and both of the units that have
    // carried the defect.
    test('the sweep reaches the whole package', () {
      final names = swept.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, contains('acl_container.dart'));
      expect(names, contains('acl_flow_test.dart'));
      expect(names, contains('tom_form_nullable_bool_field.dart'));
      expect(names, contains('validator_registry_test.dart'));
      expect(names, isNot(contains(_selfName)));
      expect(
        swept.length,
        greaterThan(100),
        reason:
            'only ${swept.length} files swept — the scan is probably '
            'not running from the package root',
      );
    });

    // The patterns are as easy to get wrong as the text they police — one of
    // them already was. Pin each against the spelling that actually occurred.
    test('each pattern matches the occurrence it was written for', () {
      String meaningOf(String needle) => _jargon
          .firstWhere(
            (j) => RegExp(j.$1).hasMatch(needle),
            orElse: () => throw StateError('no pattern matches "$needle"'),
          )
          .$2;

      expect(meaningOf('CE-LO'), contains('CodeSpecs'));
      expect(meaningOf('CE-EL'), contains('CodeSpecs'));
      expect(meaningOf('D09 XDS'), contains('Experience Design'));
      expect(meaningOf('csexb2'), contains('quest todo'));
      expect(meaningOf('CSEXB1'), contains('quest todo'));
    });

    for (final (pattern, meaning) in _jargon) {
      test('no occurrence of /$pattern/', () {
        final regexp = RegExp(pattern);
        final hits = <String>[];
        for (final file in swept) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (regexp.hasMatch(lines[i])) {
              hits.add('  ${file.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        expect(
          hits,
          isEmpty,
          reason:
              'this names $meaning, which a reader of this package '
              'cannot resolve — state the fact it stood for instead:\n'
              '${hits.join('\n')}',
        );
      });
    }
  });
}
