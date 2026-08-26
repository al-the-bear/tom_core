/// Pins that every `§NN` the unit ships names the document it points into and
/// resolves to a heading that actually exists there.
///
/// The unit used to carry these references bare — `(see §24)`, `See bug §74`.
/// A bare section number is unfollowable from the rendered API docs, where the
/// reader has neither the specification open nor any way to guess which of the
/// workspace's several numbered documents was meant. `§74` was the proof: its
/// only referent was a numbering internal to a workspace-only planning
/// document, describing a bug that had since been fixed.
///
/// Nothing about a reference going stale breaks a build, so this is checked
/// here rather than left to review. The three failure modes it catches are a
/// reference that names no document, one that names a section the document
/// does not have, and one that has drifted out of dartdoc into a plain
/// comment where the qualification rule was never applied.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The unit under guard. Paths are package-relative; `flutter test` runs with
/// the package root as its working directory.
const _sourcePaths = <String>[
  'lib/src/advanced_container_layout/acl_builder.dart',
  'lib/src/advanced_container_layout/acl_container.dart',
];

/// The one document this unit's section numbers may refer to.
const _specPath = 'doc/acl_design_specification.md';

/// A single `§NN` occurrence, together with the doc comment enclosing it.
class _Reference {
  _Reference({
    required this.path,
    required this.line,
    required this.section,
    required this.lineText,
    required this.block,
  });

  final String path;
  final int line;

  /// The section identifier as written — `24`, `26b`.
  final String section;
  final String lineText;

  /// The full text of the `///` run this reference sits in, or null when the
  /// reference is not in a doc comment at all.
  final String? block;

  String get where => '$path:$line';
}

/// Collects every `§`-reference in [path], attaching the doc-comment run each
/// one belongs to.
///
/// A "run" is a maximal block of consecutive `///` lines. Attaching the whole
/// run rather than the single line is what lets a reference be qualified on a
/// following line, which is how most of them have to be written to stay inside
/// the line-length budget.
List<_Reference> _referencesIn(String path) {
  final lines = File(path).readAsLinesSync();
  final references = <_Reference>[];

  // Index every line that belongs to a doc-comment run to that run's text.
  final blockOfLine = <int, String>{};
  var index = 0;
  while (index < lines.length) {
    if (lines[index].trimLeft().startsWith('///')) {
      final start = index;
      while (index < lines.length &&
          lines[index].trimLeft().startsWith('///')) {
        index++;
      }
      final block = lines.sublist(start, index).join('\n');
      for (var i = start; i < index; i++) {
        blockOfLine[i] = block;
      }
    } else {
      index++;
    }
  }

  final pattern = RegExp(r'§(\d+[a-z]?)');
  for (var i = 0; i < lines.length; i++) {
    for (final match in pattern.allMatches(lines[i])) {
      references.add(_Reference(
        path: path,
        line: i + 1,
        section: match.group(1)!,
        lineText: lines[i].trim(),
        block: blockOfLine[i],
      ));
    }
  }
  return references;
}

/// The set of section identifiers the specification actually defines, read
/// from its `## N.` headings. Includes the lettered ones (`5b`, `26b`), which
/// matter because §26 and §26b are different mechanisms that were once
/// conflated here.
Set<String> _specSections() {
  final headings = RegExp(r'^##\s+(\d+[a-z]?)[.\s]', multiLine: true);
  final source = File(_specPath).readAsStringSync();
  return headings.allMatches(source).map((m) => m.group(1)!).toSet();
}

void main() {
  late List<_Reference> references;
  late Set<String> sections;

  setUpAll(() {
    references = _sourcePaths.expand(_referencesIn).toList();
    sections = _specSections();
  });

  group('every shipped section reference stands on its own', () {
    // Without this, all three checks below would pass on a unit that had
    // simply stopped citing the specification — and would keep passing after
    // someone deleted the last reference by accident.
    test('the unit still cites the specification', () {
      expect(references, isNotEmpty,
          reason: 'no §NN references found in $_sourcePaths — either the '
              'unit stopped citing the spec, or the scan is broken');
      expect(sections, contains('24'));
      expect(sections, contains('26b'));
    });

    test('every reference sits in a doc comment', () {
      // Plain `//` comments used to carry section numbers in section banners
      // (`// ── IDs (§24) ──`). Those were removed rather than qualified: a
      // navigation banner reads just as well without a number, and every one
      // of them was a second place for the numbering to drift. Should the
      // habit return, it returns unqualified — so catch it here.
      final stray = references.where((r) => r.block == null).toList();
      expect(stray, isEmpty,
          reason: 'section references outside dartdoc:\n'
              '${stray.map((r) => '  ${r.where}: ${r.lineText}').join('\n')}');
    });

    test('every reference names the document it points into', () {
      final bare = references
          .where((r) => r.block != null && !r.block!.contains(_specPath))
          .toList();
      expect(bare, isEmpty,
          reason: 'section references whose dartdoc never names $_specPath:\n'
              '${bare.map((r) => '  ${r.where}: ${r.lineText}').join('\n')}');
    });

    test('every reference resolves to a heading that exists', () {
      final dangling =
          references.where((r) => !sections.contains(r.section)).toList();
      expect(dangling, isEmpty,
          reason: 'section references with no matching heading in $_specPath '
              '(it defines ${(sections.toList()..sort()).join(', ')}):\n'
              '${dangling.map((r) => '  ${r.where}: §${r.section}').join('\n')}');
    });
  });

  group('the references that were wrong before are right now', () {
    test('no reference to the retired §74 survives', () {
      // §74 was never a section of this specification at all — it belonged to
      // a workspace-only document's own bug numbering, and named a defect
      // (`setAclDefaultRowHorizontalAlignment` not applying retroactively)
      // that is fixed. A reader of the API docs could not have followed it
      // even in principle.
      expect(references.map((r) => r.section), isNot(contains('74')));
    });

    test('the auth-elision rules cite §26b, not §26', () {
      // The two are adjacent in the spec and easy to confuse, but §26 is
      // group visibility — a different mechanism with different gap
      // semantics. The elision comment cited §26 for a rule only §26b states.
      final elision = references.firstWhere(
        (r) => r.block != null && r.block!.contains('Elision rules'),
        orElse: () => throw StateError('elision dartdoc no longer found'),
      );
      expect(elision.section, '26b');
    });
  });
}
