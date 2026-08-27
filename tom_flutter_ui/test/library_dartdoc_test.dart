/// Pins the library-level dartdoc on the package barrel and the module
/// barrels it exports.
///
/// **Why this needs a test rather than review.** A missing library dartdoc
/// breaks nothing. The package compiles, the analyzer is silent, and the only
/// symptom is that a reader arriving at the generated API documentation is told
/// nothing about what they are looking at. So it drifts in one direction only:
/// new barrels get added undocumented, and nobody notices until someone tries
/// to use the docs.
///
/// **What the generated output actually contains**, which is not what the
/// directory layout suggests: `dart doc` reports *"Documented 1 public
/// library"*. Everything under `lib/src/` is private by convention, so no
/// module barrel gets a landing page of its own — `AclBuilder`, `TomForm` and
/// `TomAction` are all documented under the single `tom_flutter_ui` library.
/// That makes `lib/tom_flutter_ui.dart` the **only** page a documentation
/// reader lands on, and its dartdoc the only prose they are shown. It is
/// checked hardest here for that reason.
///
/// The module barrels are still checked, because they are the entry point for
/// the other reader — the one navigating the source, or following an IDE
/// "go to definition" into `lib/src/`.
///
/// **This is a ratchet, not a clean sweep.** Five module barrels are
/// undocumented today and are named in [_knownUndocumented]. The test fails if
/// that set grows, or if a barrel on it is quietly deleted; removing an entry
/// is the only edit that should ever be needed.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The package barrel — the sole library `dart doc` emits a page for.
const _packageBarrel = 'lib/tom_flutter_ui.dart';

/// The ACL module barrel, whose orientation duty this test pins in detail.
const _aclBarrel =
    'lib/src/advanced_container_layout/advanced_container_layout.dart';

/// Module barrels that carry no library dartdoc yet.
///
/// Each entry is a reader who currently arrives at a bare `export` list. The
/// set may shrink; a growing set is a regression and fails the ratchet below.
const _knownUndocumented = <String>{
  'lib/src/forms/tom_forms.dart',
  'lib/src/resource_auth/resource_auth.dart',
  'lib/src/theme/theme.dart',
  'lib/src/widget_base/widget_base.dart',
  'lib/src/widgets/widgets.dart',
};

/// The `export 'src/…';` targets of the package barrel, as repo-relative paths.
///
/// Derived rather than listed, so a newly added unit is covered the moment it
/// is exported instead of when someone remembers to update this file.
List<String> _moduleBarrels() {
  final source = File(_packageBarrel).readAsStringSync();
  return RegExp(r"^export '([^']+)';", multiLine: true)
      .allMatches(source)
      .map((m) => 'lib/${m.group(1)!}')
      .toList();
}

/// The unit a module barrel belongs to: its directory under `lib/src/`, or its
/// own basename when it sits directly in `lib/src/`.
///
/// `lib/src/widget_base/widget_base.dart` → `widget_base`;
/// `lib/src/advanced_container_layout.dart` → `advanced_container_layout`;
/// `lib/src/forms/tom_forms.dart` → `forms` (the file name and the unit name
/// disagree, which is why this reads the directory rather than the basename).
String _unitName(String barrelPath) {
  final parts = barrelPath.split('/'); // lib / src / … / <file>.dart
  return parts.length > 3
      ? parts[2]
      : parts.last.replaceAll('.dart', '');
}

/// The library dartdoc of [path] — the `///` run that precedes `library;` —
/// with the comment markers stripped. Empty when the file has none.
///
/// The `library;` anchor is what distinguishes a *library* dartdoc from a doc
/// comment on the first declaration, and it is also what the analyzer's
/// `dangling_library_doc_comments` lint insists on. A file whose header uses
/// `//` instead of `///` therefore reads as empty here — which is exactly the
/// state the package barrel was in.
String _libraryDartdoc(String path) {
  final lines = File(path).readAsLinesSync();
  final doc = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      doc.add(trimmed.substring(3).trim());
      continue;
    }
    if (trimmed == 'library;') return doc.join('\n');
    if (trimmed.isEmpty) continue;
    return ''; // Hit a declaration before `library;` — no library dartdoc.
  }
  return '';
}

void main() {
  group('the package barrel documents itself', () {
    // This is the one page `dart doc` generates, so an omission here is
    // invisible in the source tree and total in the output.
    late String doc;

    setUpAll(() => doc = _libraryDartdoc(_packageBarrel));

    test('it has a library dartdoc at all', () {
      expect(doc, isNotEmpty,
          reason: '$_packageBarrel is the only library `dart doc` emits a '
              'page for. Without a `///` run before `library;` that page has '
              'no description whatsoever.');
    });

    test('it opens with a statement of what the package is', () {
      final firstParagraph = doc.split('\n\n').first;
      expect(firstParagraph.length, greaterThan(60),
          reason: 'the opening paragraph is the whole of what a reader is '
              'shown before the member list; one line is not enough');
    });

    test('it names every unit it exports', () {
      // The landing page carries the unit map, because no module barrel gets a
      // page of its own to carry it.
      //
      // Matching on the backticked unit name rather than a bare substring is
      // deliberate: `widgets` and `widget_base` both occur in ordinary prose
      // about widgets, so a substring test would pass on a page that never
      // lists them.
      final missing = _moduleBarrels()
          .map(_unitName)
          .where((unit) => !doc.contains('`$unit`'))
          .toList()
        ..sort();
      expect(missing, isEmpty,
          reason: 'these exported units are not named on the landing page, so '
              'a reader cannot learn they exist: $missing');
    });

    test('it points at the documentation set', () {
      expect(doc, contains('doc/README.md'),
          reason: 'the landing page should hand the reader on to the doc '
              'index rather than being the end of the trail');
    });
  });

  group('the ACL module barrel orients its reader', () {
    // tcinc712's subject. The unit exports around thirty types; a reader
    // needs to be told which two to read first.
    late String doc;

    setUpAll(() => doc = _libraryDartdoc(_aclBarrel));

    test('it has a library dartdoc', () {
      expect(doc, isNotEmpty, reason: '$_aclBarrel carries no library dartdoc');
    });

    test('it states what the unit is in a paragraph', () {
      final firstParagraph = doc.split('\n\n').first;
      expect(firstParagraph.length, greaterThan(60),
          reason: 'a one-line summary does not tell a newcomer what ACL is');
    });

    test('it names the entry points', () {
      // Out of ~30 exported types, these are the two a newcomer should read
      // first — naming them is the difference between a barrel and a map.
      for (final entryPoint in ['[AclBuilder]', '[Acl]']) {
        expect(doc, contains(entryPoint),
            reason: '$_aclBarrel should name $entryPoint as an entry point');
      }
    });

    test('it links both prose documents', () {
      // The two-tier split of `doc/README.md`: the reference answers "how do I
      // call this", the specification answers "why is it shaped this way".
      expect(doc, contains('doc/advanced_container_layout.md'));
      expect(doc, contains('doc/acl_design_specification.md'));
    });

    test('the documents it links exist', () {
      for (final path in const [
        'doc/advanced_container_layout.md',
        'doc/acl_design_specification.md',
        'lib/src/advanced_container_layout/readme.md',
      ]) {
        expect(File(path).existsSync(), isTrue,
            reason: '$_aclBarrel points at $path, which is not there');
      }
    });
  });

  group('the undocumented-barrel ratchet', () {
    test('every module barrel is documented, or listed as a known gap', () {
      final undocumented = _moduleBarrels()
          .where((path) => _libraryDartdoc(path).isEmpty)
          .toSet();

      final regressions = undocumented.difference(_knownUndocumented).toList()
        ..sort();
      expect(regressions, isEmpty,
          reason: 'these module barrels lost or never had a library dartdoc '
              'and are not on the known-gap list. Document them, or — if the '
              'gap is deliberate — add them to _knownUndocumented with a '
              'reason:\n${regressions.map((p) => '  $p').join('\n')}');
    });

    test('the known-gap list contains no stale entries', () {
      // Keeps the list honest in the other direction: an entry that has since
      // been documented, renamed or deleted must come off, so the set always
      // reads as the real outstanding work.
      final barrels = _moduleBarrels().toSet();
      final stale = _knownUndocumented
          .where((path) =>
              !barrels.contains(path) || _libraryDartdoc(path).isNotEmpty)
          .toList()
        ..sort();
      expect(stale, isEmpty,
          reason: 'these entries in _knownUndocumented are no longer '
              'undocumented module barrels — remove them:\n'
              '${stale.map((p) => '  $p').join('\n')}');
    });
  });
}
