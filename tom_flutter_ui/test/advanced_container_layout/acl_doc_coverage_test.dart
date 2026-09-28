/// Pins `doc/advanced_container_layout.md` against the barrel it claims to
/// document — the symbol index, and the sections that must exist.
///
/// **The failure this exists to stop.** The overview table is a hand-written
/// index of the unit's public surface. Nothing breaks when a type is added to
/// the barrel and not to the table, so the table only ever drifts one way. By
/// the time this test was written seventeen of the thirty-five exported public
/// types were missing from it, and eleven of those appeared *nowhere* in the
/// document at all — container titles, borders, separators, layout direction
/// and the axis-point enums were entirely undiscoverable to a reader working
/// from the reference. A reader working from the API list, conversely, met
/// types the document never mentioned.
///
/// So the index is derived on one side and read on the other, and the two are
/// compared. Adding a type to the barrel without indexing it is a red test at
/// the moment it happens, not a discovery two quarters later.
///
/// **Both directions are checked.** Missing entries are the drift that
/// actually happened; invented ones are the drift a rename produces, where the
/// table keeps naming a type that no longer exists. The second check is what
/// makes the first safe to satisfy — an index nobody verifies can be padded.
///
/// **The five feature sections.** Titles, borders, separators, scrolling and
/// right-to-left layout are the areas the document had no section for. An
/// index entry alone does not tell a reader how to switch a feature on, so
/// each area is additionally required to have a section that names the API
/// that configures it. [_featureSections] is the contract: heading on the
/// left, the identifiers that section must mention on the right.
///
/// The table of contents is checked against the headings for the same reason —
/// a section nobody can find from the top of the document is only half added.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The module reference under test, and the barrel that defines the surface it
/// must cover. Paths are package-relative; `flutter test` runs with the
/// package root as its working directory.
const _docPath = 'doc/advanced_container_layout.md';
const _barrelPath =
    'lib/src/advanced_container_layout/advanced_container_layout.dart';

/// The heading of the symbol index, whose scope the coverage checks use.
///
/// The section holds several grouped tables rather than one; grouping
/// thirty-five symbols by area is what makes the index usable. The checks
/// therefore scope to the *section*, not to a single table.
const _overviewHeading = 'Overview';

/// The five feature areas that had no section, and the identifiers each
/// section must name.
///
/// The right-hand side is deliberately the **configuring API** rather than the
/// types alone: a section that mentions `AclSeparator` but never `gapRow` has
/// told the reader what a separator *is* and not how to get one, which is the
/// gap this guard closes.
const _featureSections = <String, List<String>>{
  'Container titles': [
    'setAclTitle',
    'AclTitlePosition',
    'AclTitleBorderAlign',
  ],
  'Container borders': ['setAclBorderStyle', 'AclBorderStyle', 'AclBorderKind'],
  'Gap rows and separators': [
    'gapRow',
    'AclSeparator',
    'AclSeparatorStyle',
    'AclSeparatorAlignment',
  ],
  'Scrolling': ['setAclScrollableX', 'setAclScrollableY'],
  'Layout direction — LTR and RTL': [
    'setAclDirection',
    'AclDirection',
    'AclDirectionScope',
  ],
};

String _doc() => File(_docPath).readAsStringSync();

/// The `export '…';` targets of the module barrel, resolved to real paths,
/// each followed into its `part` files.
///
/// A library's declarations are not all in the file the barrel names:
/// `acl_container.dart` is split into nine parts, and reading only the file
/// named here would find the container and miss the model, the values and the
/// widgets — which reads as "the overview documents types that do not exist".
List<File> _exportedFiles() {
  final barrel = File(_barrelPath);
  final dir = barrel.parent.path;
  final out = <File>[];
  for (final m in RegExp(
    r"^export '([^']+)';",
    multiLine: true,
  ).allMatches(barrel.readAsStringSync())) {
    final library = File('$dir/${m.group(1)!}');
    out.add(library);
    for (final part in RegExp(
      r"^part '([^']+)';",
      multiLine: true,
    ).allMatches(library.readAsStringSync())) {
      out.add(File('$dir/${part.group(1)!}'));
    }
  }
  return out;
}

/// Every public type the barrel exports: classes, enums, mixins, extensions
/// and typedefs whose name does not start with `_`.
///
/// This is the checklist the index must match, and it is read from the source
/// rather than listed here so that a type added tomorrow is covered today.
Set<String> _exportedPublicTypes() {
  final decl = RegExp(
    r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*'
    r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)',
    multiLine: true,
  );
  return {
    for (final file in _exportedFiles())
      for (final m in decl.allMatches(file.readAsStringSync()))
        if (!m.group(1)!.startsWith('_')) m.group(1)!,
  };
}

/// Every public *top-level* function the barrel exports.
///
/// Anchored at column zero, which is what separates a top-level declaration
/// from a method — the index lists `aclWrapRows` and `aclResolveBreakpointed`
/// alongside the types, and those entries deserve checking too.
Set<String> _exportedPublicFunctions() {
  final fn = RegExp(
    r'^[A-Za-z_][\w<>?, \[\]]*\s+([a-z][A-Za-z0-9_]*)(?:<[^>]*>)?\s*\(',
    multiLine: true,
  );
  return {
    for (final file in _exportedFiles())
      for (final m in fn.allMatches(file.readAsStringSync()))
        if (!m.group(1)!.startsWith('_')) m.group(1)!,
  };
}

/// The `## ` headings of the document, in order, as written.
List<String> _headings() => RegExp(
  r'^## (.+)$',
  multiLine: true,
).allMatches(_doc()).map((m) => m.group(1)!.trim()).toList();

/// The link titles of the table of contents, in order.
List<String> _tocEntries() {
  final doc = _doc();
  final start = doc.indexOf('## Table of Contents');
  final end = doc.indexOf('\n## ', start + 5);
  return RegExp(r'^- \[(.+?)\]\(#', multiLine: true)
      .allMatches(doc.substring(start, end))
      .map((m) => m.group(1)!.trim())
      .toList();
}

/// The body of the `## [heading]` section, up to the next `## ` heading.
///
/// Returns an empty string when there is no such heading, so a missing section
/// fails the content check as well as the presence check rather than throwing.
String _section(String heading) {
  final doc = _doc();
  final start = doc.indexOf('\n## $heading\n');
  if (start < 0) return '';
  final end = doc.indexOf('\n## ', start + 4);
  return doc.substring(start, end < 0 ? doc.length : end);
}

/// The first cell of every markdown table row in [section] — the Symbol
/// column — split on `/` so a paired row like ``​`AclVariant` / `AclRowBreakpoint`​``
/// yields both names.
///
/// Header and separator rows are dropped: a row is a data row only when its
/// first cell contains a backticked identifier.
List<String> _indexedSymbols(String section) {
  final symbols = <String>[];
  for (final line in section.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final firstCell = trimmed.split('|')[1];
    for (final m in RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)',
    ).allMatches(firstCell)) {
      symbols.add(m.group(1)!);
    }
  }
  return symbols;
}

void main() {
  group('the overview indexes the barrel', () {
    test('every exported public type appears in the overview', () {
      // The drift that actually happened, and the one the reader notices: a
      // type exists, works, is exported — and the reference never says so.
      final overview = _section(_overviewHeading);
      expect(
        overview,
        isNotEmpty,
        reason: '$_docPath has no "## $_overviewHeading" section',
      );

      final indexed = _indexedSymbols(overview).toSet();
      final missing = _exportedPublicTypes().difference(indexed).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'these public types are exported by the module barrel but '
            'are not named in the overview, so a reader working from the '
            'document cannot learn they exist:\n'
            '${missing.map((t) => '  $t').join('\n')}',
      );
    });

    test('the overview names nothing that does not exist', () {
      // The drift a rename produces. Without this, the check above can be
      // satisfied by an index nobody keeps honest.
      final symbols = _indexedSymbols(_section(_overviewHeading)).toSet();
      final known = _exportedPublicTypes().union(_exportedPublicFunctions());
      final invented = symbols.difference(known).toList()..sort();
      expect(
        invented,
        isEmpty,
        reason:
            'the overview names these symbols, which the module barrel '
            'exports neither as a public type nor as a public top-level '
            'function — they were renamed or removed:\n'
            '${invented.map((t) => '  $t').join('\n')}',
      );
    });
  });

  group('the five feature areas each have a section', () {
    // Titles, borders, separators, scrolling and RTL. Each was supported by
    // the code and absent from the document.
    for (final entry in _featureSections.entries) {
      final heading = entry.key;

      test('"$heading" has a section', () {
        expect(
          _headings(),
          contains(heading),
          reason:
              '$_docPath has no "## $heading" section, so the feature '
              'is undiscoverable to a reader of the reference',
        );
      });

      test('"$heading" says how to configure it', () {
        // A section that describes a feature without naming the call that
        // switches it on leaves the reader exactly where they started.
        final body = _section(heading);
        final unmentioned = entry.value
            .where((id) => !body.contains(id))
            .toList();
        expect(
          unmentioned,
          isEmpty,
          reason:
              'the "$heading" section never mentions '
              '${unmentioned.join(', ')} — the reader is told the feature '
              'exists but not how to reach it',
        );
      });
    }
  });

  group('the table of contents matches the document', () {
    // A section that is not listed is half-added; a listing with no section
    // is a dead link. Both are cheap to introduce and invisible in review.
    test('every section is listed in the contents', () {
      final listed = _tocEntries().toSet();
      final unlisted = _headings()
          .where((h) => h != 'Table of Contents' && !listed.contains(h))
          .toList();
      expect(
        unlisted,
        isEmpty,
        reason:
            'these sections are missing from the table of contents: '
            '${unlisted.join(', ')}',
      );
    });

    test('every contents entry has a section', () {
      final headings = _headings().toSet();
      final dangling = _tocEntries()
          .where((e) => !headings.contains(e))
          .toList();
      expect(
        dangling,
        isEmpty,
        reason:
            'these contents entries point at sections that do not '
            'exist: ${dangling.join(', ')}',
      );
    });
  });
}
