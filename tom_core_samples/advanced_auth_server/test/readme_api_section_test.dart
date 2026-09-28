/// Holds the README's `## API` table to the barrel it claims to index.
///
/// **Shared in shape with `advanced_app_server`**, whose
/// `test/readme_api_section_test.dart` asks the same four questions of its own
/// barrel. The two differ only in the barrel they open, so a fix worth making
/// here is worth making there.
///
/// **Why the table exists and why it needs this.** A sample package carries no
/// `doc/api/` mirror — a decision taken once for the whole sample suite and
/// stated in `tom_core_samples/README.md`, on the grounds that a sample has no
/// consumers who need its surface indexed. What a reader of *this* package
/// still wants is the question a narrative guide does not answer: what does the
/// barrel export, and which of those may I call?
///
/// A hand-written answer drifts the moment an export is added or renamed, which
/// is the objection to writing one at all. So neither side is written out here:
/// the exports come from `lib/advanced_auth_server.dart` and the rows from the
/// README, and the two sets are compared. The table is then as true as the
/// barrel, and adding an export without documenting it fails rather than going
/// unnoticed.
library;

import 'dart:io';

import 'package:test/test.dart';

/// An `export 'src/…';` directive in the barrel.
final _export = RegExp(r"^export\s+'([^']+)'", multiLine: true);

/// The first cell of a table row, which is the library path in a code span.
final _row = RegExp(r'^\|\s*`([^`]+\.dart)`\s*\|', multiLine: true);

/// The README's `## API` section, up to the next heading.
final _apiSection = RegExp(r'\n## API\n(.*?)\n## ', dotAll: true);

void main() {
  final barrel = File('lib/advanced_auth_server.dart').readAsStringSync();
  final readme = File('README.md').readAsStringSync();

  group('the README API table matches the barrel', () {
    test('the barrel exports something to index', () {
      // Without this the comparison below passes on two empty sets and reports
      // a documented package it never opened.
      expect(_export.allMatches(barrel), isNotEmpty);
    });

    test('the README has an API section', () {
      expect(
        _apiSection.hasMatch(readme),
        isTrue,
        reason: 'README.md must carry a `## API` section indexing the barrel',
      );
    });

    test('every export has a row, and every row an export', () {
      final exported = _export
          .allMatches(barrel)
          .map((m) => m.group(1)!)
          .toSet();
      final documented = _row
          .allMatches(_apiSection.firstMatch(readme)!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        documented,
        equals(exported),
        reason:
            'exports with no row: ${exported.difference(documented)}; '
            'rows with no export: ${documented.difference(exported)}',
      );
    });

    test('every documented library is on disk', () {
      // A row can name a path that resolves nowhere even while matching an
      // export, if the barrel itself went stale — so the file is checked too.
      for (final match in _export.allMatches(barrel)) {
        final path = 'lib/${match.group(1)!}';
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is exported and is not there',
        );
      }
    });
  });
}
