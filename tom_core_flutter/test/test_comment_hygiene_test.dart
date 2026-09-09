import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards what the comments in this package's test files are allowed to say.
///
/// A comment above a test outranks the test. A reader takes it as the
/// statement of intent and reads the code beneath as its implementation, so a
/// stale test comment costs more than stale prose elsewhere: there is nothing
/// to contradict it, because the test underneath is passing.
///
/// Three ways of going stale are specific enough to be checked for
/// mechanically, and each has a check below.
///
/// A comment can record the phase of its own authorship — that the test failed
/// against the implementation as it stood while the test was being written.
/// That is true for exactly as long as it takes to make the test pass, and the
/// change that makes it pass is not the change that remembers to delete the
/// note. What is left tells every later reader that the production code lacks
/// something it has, which is the strongest possible claim to get wrong.
///
/// A comment can also cite a numbered section of another document. For these
/// files the only document with such numbering is a code-review working paper
/// that is not committed, so the context such a comment promises has nowhere
/// to lead. The check is deliberately scoped to the files listed here rather
/// than being a package-wide ban: `codespecs_mapping.md` is cited by number
/// elsewhere in the package and does exist.
///
/// The third is not about a comment going stale but about where it sends the
/// reader, and it is package-wide rather than scoped to a file list. **No
/// artefact of this package may cite a document in the AI-state mount.** That
/// mount is a different repository — `tom_agent_state`, symlinked into the
/// workspace — so a reader holding these sources and not that layer cannot
/// follow such a reference at all. The citations that prompted this were the worst shape
/// for it: bare relative-looking paths that read like a sibling file and were
/// quest documents four directories away in another repository. The literal is
/// not written here, for the reason the fragment-assembly note below gives —
/// this file is scanned too, and an example spelled out would be an offence
/// against the rule it illustrates.
///
/// Citing *another package in the code tree* is fine and stays that way. The
/// distinction is whether the target ships with a checkout of the code, which
/// is what a reader actually cares about: `codespecs_mapping.md` lives in
/// `tom_ai/ai_build/tom_specs_model/doc/` and comes with the monorepo, and
/// three artefacts here cite it deliberately.
///
/// The rule is about a *citation*, and that is why this guard is a member of
/// this package's suite rather than a check over `tom_ai/core`. A package whose
/// code reads or writes that mount at runtime names those paths to describe its
/// own behaviour, not to send a reader elsewhere for a reason —
/// `tom_core_agentic` stores prompt trails under one — and lifting this check
/// across the tree without that distinction would report three such files as
/// defects. Nothing in this package operates on the mount, so the two questions
/// do not have to be told apart here.
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
  // is worth naming: they are checked against *other* files. Were a positive
  // needle written here to also name this file, it would be present in the text
  // being read purely because the guard states it, and the check would pass
  // against its own argument — green with the comment it guards deleted. That
  // the guard lives outside the files it requires claims of is what prevents
  // it, not care.
  final tddPhaseMarker = RegExp(
    'RED '
    r'(against|before)',
  );
  final sectionCitation = RegExp(
    '§'
    r'\s*\d',
  );

  /// Path segments that exist only in the AI-state repository.
  ///
  /// Assembled from fragments for the same reason as the two patterns above:
  /// this file names the rule, so spelled literally each needle would match the
  /// sentence describing it and the guard would report itself.
  ///
  /// Three segments rather than one, because the citations that prompted the
  /// rule did not write the mount at all. The first catches an honest workspace
  /// path; the other two catch the bare relative form, which is the shape that
  /// actually appeared and the harder one to notice — it looks like a file
  /// beside the one you are reading.
  final questStatePaths = <RegExp>[
    // Anchored so it cannot fire on `tom_ai/`, which is the code tree and is
    // explicitly allowed. Written as a plain substring it matched three files
    // that cite this repository's own tooling — exactly the reference the rule
    // is careful to permit.
    RegExp(
      r'(?<![A-Za-z0-9])'
      '_a'
      r'i/',
    ),
    RegExp(
      r'(?<![A-Za-z0-9])'
      'complet'
      r'ion/',
    ),
    RegExp(
      r'(?<![A-Za-z0-9])'
      'que'
      r'sts/',
    ),
  ];

  /// Every authored artefact of this package.
  ///
  /// Package-wide rather than a file list, because the rule is about where a
  /// reader is sent and that is not a property of any particular file. Two of
  /// the three artefacts citing the sibling specification are published
  /// documentation rather than tests, which is what settled the scope: a rule
  /// that only bound test comments would leave a module readme free to send a
  /// reader into a repository they do not have.
  ///
  /// Generated mirrors are skipped. A generator that emitted such a path would
  /// be the generator's defect, and failing here would point at the wrong
  /// package.
  List<File> authoredFiles() {
    final files = <File>[];
    for (final directory in const ['lib', 'test', 'example', 'doc']) {
      final root = Directory(directory);
      if (!root.existsSync()) continue;
      files.addAll(
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.md'))
            .where((f) => !f.path.endsWith('.reflection.dart')),
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

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
      expect(
        unreadable,
        isEmpty,
        reason: 'the guard is scanning a file it cannot read',
      );
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

    test('the package walk reaches its own sources', () {
      // The check below passes when it finds nothing, so it passes over a walk
      // that found nothing. This is what makes a green result mean the files
      // were read.
      final found = authoredFiles();
      expect(found, hasLength(greaterThan(40)));
      for (final directory in const ['lib/', 'test/', 'doc/']) {
        expect(
          found.where((f) => f.path.startsWith(directory)),
          isNotEmpty,
          reason: 'the walk reached nothing under $directory',
        );
      }
    });

    test('no artefact cites a document in the AI-state repository', () {
      final offenders = <String>[];
      for (final file in authoredFiles()) {
        final source = file.readAsStringSync();
        for (final needle in questStatePaths) {
          final hit = needle.firstMatch(source);
          if (hit != null) {
            offenders.add('${file.path} names `${hit.group(0)}`');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '`_ai` is a different repository, mounted into the workspace as a '
            'symlink, so a reader who has these sources and not the AI-state '
            'layer cannot follow such a reference at all. State the reason '
            'inline instead. Citing another package in the code tree is fine — '
            'that ships with a checkout:\n${offenders.join('\n')}',
      );
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
