/// Pins that this unit's section references stand on their own — that a reader
/// who has only this package can resolve everything its comments point at.
///
/// A section of `doc/acl_design_specification.md` cited bare — `(see §24)`,
/// naming no document — is unfollowable from the rendered API docs, where the
/// reader has neither the specification open nor any way to guess which of
/// the workspace's several numbered documents was meant. Every section number
/// in this unit therefore names that document, and that document has to
/// define the section. Caught here: a reference that names no document, one
/// that names a section the document does not have, and one that has drifted
/// out of dartdoc into a plain comment where the qualification rule does not
/// get applied.
///
/// The unit's other shipped-text failure — naming parts of *other* projects'
/// specifications — turned out not to be unit-specific, and is guarded for the
/// whole package by `test/shipped_text_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The unit under guard. Paths are package-relative; `flutter test` runs with
/// the package root as its working directory.
const _sourcePaths = <String>[
  'lib/src/advanced_container_layout/acl_builder.dart',
  // The `acl_builder` library's parts, listed for the same reason.
  'lib/src/advanced_container_layout/acl_builder_data.dart',
  'lib/src/advanced_container_layout/acl_builder_sizing.dart',
  'lib/src/advanced_container_layout/acl_builder_alignment.dart',
  'lib/src/advanced_container_layout/acl_builder_chrome.dart',
  'lib/src/advanced_container_layout/acl_builder_identity.dart',
  'lib/src/advanced_container_layout/acl_builder_responsive.dart',
  'lib/src/advanced_container_layout/acl_container.dart',
  // The `acl_container` library's parts. Listed rather than globbed: a file
  // that stops being scanned should be a line somebody deleted, not a name
  // that stopped matching.
  'lib/src/advanced_container_layout/acl_container_values.dart',
  'lib/src/advanced_container_layout/acl_container_model.dart',
  'lib/src/advanced_container_layout/acl_container_widgets.dart',
  'lib/src/advanced_container_layout/acl_container_state_lifecycle.dart',
  'lib/src/advanced_container_layout/acl_container_passes.dart',
  'lib/src/advanced_container_layout/acl_container_identity.dart',
  'lib/src/advanced_container_layout/acl_container_fitting.dart',
  'lib/src/advanced_container_layout/acl_container_geometry.dart',
  'lib/src/advanced_container_layout/acl_container_chrome.dart',
  'lib/src/advanced_container_layout/acl_container_content.dart',
  'lib/src/advanced_container_layout/acl_container_row.dart',
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
      references.add(
        _Reference(
          path: path,
          line: i + 1,
          section: match.group(1)!,
          lineText: lines[i].trim(),
          block: blockOfLine[i],
        ),
      );
    }
  }
  return references;
}

/// The set of section identifiers the specification actually defines, read
/// from its `## N.` headings. Includes the lettered ones, because in
/// `doc/acl_design_specification.md` §26 and §26b are different mechanisms
/// that a citation can easily confuse.
Set<String> _specSections() {
  final headings = RegExp(r'^##\s+(\d+[a-z]?)[.\s]', multiLine: true);
  final source = File(_specPath).readAsStringSync();
  return headings.allMatches(source).map((m) => m.group(1)!).toSet();
}

/// The section list as a reader expects to see it — `5, 5b, 6, … 17, 18, 20`
/// rather than the lexical `1, 10, 11, … 2, 20`, which is unreadable in a
/// failure message precisely when someone is scanning it for a number.
String _sectionList(Set<String> sections) {
  final ordered = sections.toList()
    ..sort((a, b) {
      final na = int.parse(RegExp(r'\d+').firstMatch(a)!.group(0)!);
      final nb = int.parse(RegExp(r'\d+').firstMatch(b)!.group(0)!);
      return na != nb ? na.compareTo(nb) : a.compareTo(b);
    });
  return ordered.join(', ');
}

/// Every `§NN` the specification uses to point at *itself*, with the line it
/// sits on.
///
/// A reference qualified with another document's filename on the same line —
/// `[tom_ui_widgets_forms.md §19](…)` — points outward and is excluded: this
/// package cannot check another document's numbering, and the link already
/// tells the reader where to look.
List<({int line, String section, String text})> _internalSpecReferences() {
  final lines = File(_specPath).readAsLinesSync();
  final other = RegExp(r'\b([\w]+\.md)\b');
  final found = <({int line, String section, String text})>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final pointsOutward = other
        .allMatches(line)
        .any((m) => !_specPath.endsWith(m.group(1)!));
    if (pointsOutward) continue;
    for (final m in RegExp(r'§(\d+[a-z]?)').allMatches(line)) {
      found.add((line: i + 1, section: m.group(1)!, text: line.trim()));
    }
  }
  return found;
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
      expect(
        references,
        isNotEmpty,
        reason:
            'no §NN references found in $_sourcePaths — either the '
            'unit stopped citing the spec, or the scan is broken',
      );
      expect(sections, contains('24'));
      expect(sections, contains('26b'));
    });

    test('every reference sits in a doc comment', () {
      // A section banner carries no section number — no
      // `// ── IDs (§24 of doc/acl_design_specification.md) ──`. A navigation
      // banner reads just as well without one, and each such number is a
      // second place for the numbering to drift. Because the banner form is
      // a plain `//` comment, the qualification rule would not reach it —
      // so catch it here instead.
      final stray = references.where((r) => r.block == null).toList();
      expect(
        stray,
        isEmpty,
        reason:
            'section references outside dartdoc:\n'
            '${stray.map((r) => '  ${r.where}: ${r.lineText}').join('\n')}',
      );
    });

    test('every reference names the document it points into', () {
      final bare = references
          .where((r) => r.block != null && !r.block!.contains(_specPath))
          .toList();
      expect(
        bare,
        isEmpty,
        reason:
            'section references whose dartdoc never names $_specPath:\n'
            '${bare.map((r) => '  ${r.where}: ${r.lineText}').join('\n')}',
      );
    });

    test('every reference resolves to a heading that exists', () {
      final dangling = references
          .where((r) => !sections.contains(r.section))
          .toList();
      expect(
        dangling,
        isEmpty,
        reason:
            'section references with no matching heading in $_specPath '
            '(it defines ${_sectionList(sections)}):\n'
            '${dangling.map((r) => '  ${r.where}: §${r.section}').join('\n')}',
      );
    });
  });

  group('the specification\'s own cross-references resolve', () {
    // Sections are deleted from doc/acl_design_specification.md as the design
    // they recorded stops being current, and the numbering gaps that leaves
    // are deliberate: renumbering would invalidate every `§NN` the source
    // cites by number. What deletion *can* break is a reference elsewhere in
    // the document to the section that just left.
    late List<({int line, String section, String text})> internal;

    setUpAll(() => internal = _internalSpecReferences());

    test('the document cross-references itself at all', () {
      expect(
        internal.length,
        greaterThan(10),
        reason:
            'only ${internal.length} internal §NN references found in '
            '$_specPath — the scan is probably broken',
      );
    });

    test('every internal reference names a section that still exists', () {
      final dangling = internal
          .where((r) => !sections.contains(r.section))
          .toList();
      expect(
        dangling,
        isEmpty,
        reason:
            'these point at sections $_specPath no longer defines — it '
            'has ${_sectionList(sections)}:\n'
            '${dangling.map((r) => '  line ${r.line}: §${r.section} — '
                '${r.text}').join('\n')}',
      );
    });
  });

  group('the numbers that are easiest to get wrong', () {
    test('no §74 of acl_design_specification.md is cited', () {
      // doc/acl_design_specification.md has no §74. The number belongs to a
      // workspace-only document's own bug numbering, so a reader of the API
      // docs could not follow a citation of it even in principle.
      expect(references.map((r) => r.section), isNot(contains('74')));
    });

    test('elision cites §26b of acl_design_specification.md, not §26', () {
      // The two are adjacent in doc/acl_design_specification.md and easy to
      // confuse: §26 is group visibility, a different mechanism with
      // different gap semantics, and doc/acl_design_specification.md states
      // the elision rule in §26b alone.
      final elision = references.firstWhere(
        (r) => r.block != null && r.block!.contains('Elision rules'),
        orElse: () => throw StateError('elision dartdoc no longer found'),
      );
      expect(elision.section, '26b');
    });
  });
}
