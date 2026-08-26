import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards what the comments in this package's test files are allowed to say.
///
/// A comment above a test outranks the test. A reader takes it as the
/// statement of intent and reads the code beneath as its implementation, so a
/// stale test comment costs more than stale prose elsewhere: there is nothing
/// to contradict it, because the test underneath is passing.
///
/// Two ways of going stale have actually happened here, and each has a check
/// below.
///
/// A comment can record the phase of its own authorship — that the test failed
/// against the implementation as it stood while the test was being written.
/// That is true for exactly as long as it takes to make the test pass, and the
/// change that makes it pass is not the change that remembers to delete the
/// note. What is left tells every later reader that the production code lacks
/// something it has, which is the strongest possible claim to get wrong.
///
/// A comment can also cite a numbered section of another document. Every such
/// citation this package ever carried pointed into a code-review working paper
/// that was never committed, so the context the comment promised had nowhere
/// to lead. The check is deliberately scoped to the files listed here rather
/// than being a package-wide ban: `codespecs_mapping.md` and
/// `completion/README.md` are cited elsewhere by number and both exist.
///
/// Both checks are satisfiable by deleting the prose they police — a comment
/// that explains nothing narrates no stale history either — so each guarded
/// module file must also keep saying the thing its comments exist to say.
/// Those needles are prose, and their brittleness against rewording is the
/// point rather than a flaw in it: what is guarded is the claim, so a rewrite
/// that keeps the claim should be phrased to keep the needle, and one that
/// drops it should turn this red.
void main() {
  /// The files whose comments this guard reads.
  ///
  /// It reads its own source too. That is not symmetry for its own sake: this
  /// file is where the forbidden patterns are written down, so it is the most
  /// likely place for one to be introduced by someone documenting the rule.
  const commentedFiles = <String>[
    'test/observing_test.dart',
    'test/resources_test.dart',
    'test/test_comment_hygiene_test.dart',
  ];

  // Both patterns are assembled from two fragments rather than written out,
  // because the list above includes this file. Spelled literally they would
  // match the source you are reading and the guard would report itself.
  //
  // The needles in `mustKeepSaying` need no such treatment, and the difference
  // is worth naming: they are checked against *other* files. While this guard
  // lived inside the suite it policed, a needle written here was also a needle
  // present in the file being read, and the positive check passed against its
  // own argument — it went green with the comment it was guarding deleted.
  // Moving the guard out of the file it reads is what fixed that, not care.
  final tddPhaseMarker = RegExp('RED ' r'(against|before)');
  final sectionCitation = RegExp('§' r'\s*\d');

  /// Per guarded module file, the claims its comments must still make, mapped
  /// to what a reader loses when one goes missing.
  const mustKeepSaying = <String, Map<String, String>>{
    'test/observing_test.dart': {
      '`TomObservingWidgetState.dispose` is what this pins':
          'the disposal test no longer names the hook it pins',
      '`TomObservingWidgetState.didUpdateWidget` is what this pins':
          'the swap test no longer names the hook it pins',
    },
    'test/resources_test.dart': {
      'the key and the value that could not be cast':
          'the type-mismatch group no longer says what the report has to name',
      'A property declared without a default is obligatory':
          'the obligatory-key group no longer says why an absent key is a '
              'failure rather than a null',
      '`getObjectOrNull` returns null both for a key that was never written':
          'the null-as-absent test no longer says which lookup makes a written '
              'null and an unwritten key indistinguishable',
      'The module tracks whether a default was supplied':
          'the nullable-default group no longer says why an explicit null '
              'default is honoured instead of being read as no default',
    },
  };

  group('the guard reads what it claims to', () {
    // Every check below is a search that passes when it finds nothing, so all
    // of them pass against a file list that is empty or wrong. These pin the
    // inputs so that a green result means the comments were read, not that the
    // reading was skipped.

    test('every guarded file exists and was read', () {
      final unreadable = <String>[
        for (final path in commentedFiles)
          if (!File(path).existsSync() ||
              File(path).readAsStringSync().trim().isEmpty)
            path,
      ];
      expect(unreadable, isEmpty,
          reason: 'the guard is scanning a file it cannot read');
      expect(commentedFiles.length, greaterThanOrEqualTo(3));
    });

    test('every required claim names a file the guard scans', () {
      // A needle listed against a path outside `commentedFiles` would be
      // checked but never protected: the file could grow the very narration
      // this guard forbids and nothing would report it.
      expect(mustKeepSaying.keys, everyElement(isIn(commentedFiles)));
      expect(
        mustKeepSaying.values.fold<int>(0, (sum, m) => sum + m.length),
        greaterThanOrEqualTo(6),
      );
    });
  });

  group('test comments state the contract, not the history', () {
    test('the guarded comments still make the claims they exist to make', () {
      final missing = <String>[
        for (final entry in mustKeepSaying.entries)
          for (final claim in entry.value.entries)
            if (!File(entry.key).readAsStringSync().contains(claim.key))
              '${entry.key}: ${claim.value}',
      ];
      expect(missing, isEmpty);
    });

    test('no comment narrates a red-first phase', () {
      final offenders = <String>[
        for (final path in commentedFiles)
          if (tddPhaseMarker.hasMatch(File(path).readAsStringSync()))
            '$path describes the implementation as it was before the test '
                'passed rather than what the test pins',
      ];
      expect(offenders, isEmpty);
    });

    test('no comment cites a numbered section of another document', () {
      final offenders = <String>[
        for (final path in commentedFiles)
          if (sectionCitation.hasMatch(File(path).readAsStringSync()))
            '$path cites a numbered section of a document; the ones these '
                'modules have carry named headings and no numbering for such '
                'a citation to refer to',
      ];
      expect(offenders, isEmpty);
    });
  });
}
