/// Pins that the text this unit ships stands on its own — that a reader who
/// has only this package can resolve everything its comments point at.
///
/// Two ways of breaking that rule have already happened here, so both are
/// checked rather than left to review; neither breaks a build, and neither is
/// visible from inside the file that commits it.
///
/// **Section references.** The unit used to cite the specification bare —
/// `(see §24)`, `See bug §74`. A bare section number is unfollowable from the
/// rendered API docs, where the reader has neither the specification open nor
/// any way to guess which of the workspace's several numbered documents was
/// meant. `§74` was the proof: its only referent was a numbering internal to a
/// workspace-only planning document, describing a bug since fixed. Caught
/// here: a reference that names no document, one that names a section the
/// document does not have, and one that has drifted out of dartdoc into a
/// plain comment where the qualification rule was never applied.
///
/// **Cross-project vocabulary.** The unit also used to name parts of *other*
/// projects' specifications — `CE-LO`, `D09 XDS`, `csexb2`. Those are ids in
/// documents this package does not ship and does not depend on, so to a reader
/// they are noise that looks like it should mean something. Every one of them
/// stood next to a sentence that survived its removal, or stood for a fact
/// that could simply be stated. Caught here: any of those tokens returning,
/// anywhere in the unit or its tests.
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

/// The directories swept for cross-project vocabulary — the whole unit and its
/// whole test suite, not just the two files that carry section references.
/// Jargon spreads by copy-paste, and a test header is as public as a dartdoc
/// once someone reads the suite to learn the feature.
const _jargonRoots = <String>[
  'lib/src/advanced_container_layout',
  'test/advanced_container_layout',
];

/// Tokens that belong to another project's specification and cannot be
/// resolved from this package.
///
/// Each entry pairs the pattern with what it actually denoted, because the
/// point of the failure message is to tell whoever hits it what to write
/// *instead* — the fix is always to state the fact the id stood for.
const _jargon = <(String, String)>[
  (r'\bCE-[A-Z]{2}\b', 'a CodeSpecs part id (CE-LO = Layout, CE-EL = Element)'),
  // Deliberately the bare token and not `D\d\d XDS`: the document number is
  // how it was written here, but the acronym alone is equally unresolvable and
  // matching both would report one site twice.
  (r'\bXDS\b', "tom_specs' Experience Design Specification, cited as `D09 XDS`"),
  (r'\b[Cc][Ss][Ee][Xx][a-z]?\d+\b', 'a tom_specs quest todo id (csexb2)'),
];

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

/// This guard, excluded from its own sweep — it necessarily quotes every
/// token it forbids.
const _selfName = 'acl_shipped_text_test.dart';

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

/// Every `.dart` and `.md` file under [_jargonRoots], except this one.
List<File> _guardedFiles() {
  return _jargonRoots
      .expand((root) => Directory(root).listSync(recursive: true))
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.md'))
      .where((f) => !f.path.endsWith(_selfName))
      .toList();
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
              '(it defines ${_sectionList(sections)}):\n'
              '${dangling.map((r) => '  ${r.where}: §${r.section}').join('\n')}');
    });
  });

  group('the specification\'s own cross-references resolve', () {
    // Sections are deleted from this document as the design they recorded
    // stops being current — §19 and §22 went that way, and the numbering
    // gaps they left are deliberate (renumbering would invalidate every
    // `§NN` the source cites by number). What deletion *can* break is a
    // reference elsewhere in the document to the section that just left.
    late List<({int line, String section, String text})> internal;

    setUpAll(() => internal = _internalSpecReferences());

    test('the document cross-references itself at all', () {
      expect(internal.length, greaterThan(10),
          reason: 'only ${internal.length} internal §NN references found in '
              '$_specPath — the scan is probably broken');
    });

    test('every internal reference names a section that still exists', () {
      final dangling =
          internal.where((r) => !sections.contains(r.section)).toList();
      expect(dangling, isEmpty,
          reason: 'these point at sections $_specPath no longer defines — it '
              'has ${_sectionList(sections)}:\n'
              '${dangling.map((r) => '  line ${r.line}: §${r.section} — '
                  '${r.text}').join('\n')}');
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

  group('no shipped text names another project\'s specification', () {
    late List<File> guarded;

    setUpAll(() => guarded = _guardedFiles());

    // Same non-vacuity guard as above: a sweep that silently stopped finding
    // files would report "no violations" forever.
    test('the sweep actually reaches the unit and its tests', () {
      final names = guarded.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, contains('acl_flow.dart'));
      expect(names, contains('acl_flow_test.dart'));
      expect(names, contains('acl_container.dart'));
      expect(names, isNot(contains(_selfName)));
    });

    for (final (pattern, meaning) in _jargon) {
      test('no occurrence of /$pattern/', () {
        final regexp = RegExp(pattern);
        final hits = <String>[];
        for (final file in guarded) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (regexp.hasMatch(lines[i])) {
              hits.add('  ${file.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        expect(hits, isEmpty,
            reason: 'this names $meaning, which a reader of this package '
                'cannot resolve — state the fact it stood for instead:\n'
                '${hits.join('\n')}');
      });
    }
  });
}
