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
///
/// **The last group polices what the prose says, not whether it exists.**
/// Documentation written alongside a build plan tends to describe the code's
/// position in that plan — "Phase 5c — Cupertino concretes", "Round-6 (a):
/// subscribe to…", "See Demo H-A". Every one of those is a fact about the
/// schedule, not about the code, and it decays the moment the schedule is
/// over: a reader who arrives at the published API documentation cannot
/// resolve "Demo H-A" or place "Phase 5c" against anything they can see.
/// The markers are enumerated in [_rolloutMarkers].
///
/// **The final group polices a narrower claim: how the member is called.**
/// Prose that calls `resolveAuthState()` "a getter" is not a style quibble —
/// it tells the reader to write `guard.resolveAuthState`, which does not
/// compile, and it hid a second error behind it (the comment justified the
/// member by subclass-overriding, which no test does). Both checks re-derive
/// the real declaration kind from source rather than trusting a list.
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

/// Vocabularies that name a position in the build plan rather than the code.
///
/// Each entry pairs a pattern with the wording to use instead, so a failure
/// tells the author what to write rather than only what not to write.
///
/// All three require a capital letter and an adjacent digit, which is what
/// keeps them off ordinary prose: an animation that runs "in three phases",
/// a `roundTo` helper and a `demoController` field all read past them. The
/// cost of that precision is that the set is a denylist and an author who
/// invents a fourth vocabulary escapes it — so this catches drift back into
/// the established habits, not every conceivable way of writing a date into
/// a doc comment.
const _rolloutMarkers = <String, String>{
  r'Phase[ -]\d':
      'a rollout phase — describe what the code does; for the steps of an '
          'algorithm write "Step 1", which reads as structure rather than '
          'schedule',
  r'Round[ -]\d':
      'a review round — state the rule the code follows now, not the round '
          'in which it changed',
  r'Demo [A-Z]\b':
      'a demo from the build plan — those letters resolve nowhere a reader '
          'of the published documentation can look; name the example file, '
          'or describe the arrangement',
};

/// Every Dart source file under `lib/`, as repo-relative paths.
///
/// Walked rather than listed: a file added tomorrow is covered without anyone
/// remembering this test exists.
List<String> _allLibrarySources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path)
    .where((p) => p.endsWith('.dart'))
    .toList()
  ..sort();

/// A member dartdoc paired with the declaration it is attached to.
typedef _DocumentedMember = ({String path, int line, String doc, String decl});

/// Every `///` block in [path] that documents a *member*, paired with the
/// declaration line it precedes.
///
/// Annotations between the comment and the declaration are skipped, so
/// `@visibleForTesting` / `@override` do not hide the thing being documented.
///
/// Type declarations (`class`, `mixin`, …) and `library;` are excluded on
/// purpose. A class's dartdoc talks *about its members* — "every method
/// forwards to…" is a true statement there, and checking it against the class
/// itself would be nonsense.
List<_DocumentedMember> _documentedMembers(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <_DocumentedMember>[];
  var i = 0;
  while (i < lines.length) {
    if (!lines[i].trimLeft().startsWith('///')) {
      i++;
      continue;
    }
    final start = i;
    final doc = <String>[];
    while (i < lines.length && lines[i].trimLeft().startsWith('///')) {
      doc.add(lines[i].trimLeft().substring(3).trim());
      i++;
    }
    var j = i;
    while (j < lines.length && lines[j].trimLeft().startsWith('@')) {
      j++;
    }
    if (j >= lines.length) continue;
    final decl = lines[j].trim();
    if (RegExp(r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|'
            r'mixin\s+)*(?:class|enum|mixin|extension|typedef)\b')
        .hasMatch(decl)) {
      continue;
    }
    if (decl.startsWith('library')) continue;
    out.add((path: path, line: start + 1, doc: doc.join(' '), decl: decl));
  }
  return out;
}

/// Type names declared in [source] — `class`, `enum`, `mixin`, `extension`
/// and `typedef`.
///
/// Used to recognise an opening line that merely *names* the file's subject
/// instead of describing it.
Set<String> _declaredTypes(String source) => RegExp(
      r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*'
      r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
      multiLine: true,
    ).allMatches(source).map((m) => m.group(1)!).toSet();

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

  group('the documentation describes the code, not its rollout', () {
    test('no source names a build-plan position', () {
      // Scans raw source rather than extracted comments, deliberately: the
      // same narration reaches a user through `@Deprecated('… from Phase 2+
      // …')`, which is a string literal. Since every marker needs a space
      // between a capitalised word and a digit, and a Dart identifier cannot
      // contain a space, scanning everything costs no false positives on code.
      final offences = <String>[];
      for (final path in _allLibrarySources()) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final entry in _rolloutMarkers.entries) {
            if (!RegExp(entry.key).hasMatch(lines[i])) continue;
            offences.add('$path:${i + 1}\n'
                '    ${lines[i].trim()}\n'
                '    → ${entry.value}');
          }
        }
      }
      expect(offences, isEmpty,
          reason: 'these lines date the documentation to a schedule the '
              'reader cannot see:\n\n${offences.join('\n\n')}');
    });

    test('no library dartdoc opens by naming its own subject', () {
      // "`TomAuthGuard`." as an opening line tells a reader nothing they did
      // not already know from the file name — and it is what a phase label is
      // usually attached to, so removing the label can leave this behind.
      //
      // Derived from each file's own declarations rather than a list of
      // names, so it keeps working as types are added and renamed.
      final offences = <String>[];
      for (final path in _allLibrarySources()) {
        final doc = _libraryDartdoc(path);
        if (doc.isEmpty) continue;

        final opener = doc.split('\n').first;
        // Strip the punctuation a label is dressed in — backticks, a
        // trailing period — then split the "`A` / `B`" form into its parts.
        final words = opener
            .replaceAll('`', '')
            .replaceAll(RegExp(r'[.]+$'), '')
            .split(RegExp(r'\s*/\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (words.isEmpty) continue;

        final declared = _declaredTypes(File(path).readAsStringSync());
        if (words.every(declared.contains)) {
          offences.add('$path\n'
              '    $opener\n'
              '    → names the file\'s own types and nothing else');
        }
      }
      expect(offences, isEmpty,
          reason: 'these library dartdocs open with a label instead of a '
              'statement of what the library is:\n\n${offences.join('\n\n')}');
    });

    test('no published file is named after a build-plan position', () {
      // A file name outranks any doc comment for visibility: it is what pub.dev
      // lists, what an import statement spells out, and what a reader types.
      // `example/phase1_demo.dart` announced a schedule position in the one
      // place a reader could not skim past.
      //
      // Checked across the three directories that ship or are read by users;
      // the doc/ plan documents are exempt because a build plan naming its own
      // phases is describing its actual subject.
      final offences = <String>[];
      for (final dir in const ['lib', 'example', 'test']) {
        for (final file in Directory(dir).listSync(recursive: true)) {
          if (file is! File || !file.path.endsWith('.dart')) continue;
          final name = file.uri.pathSegments.last;
          if (!RegExp(r'(phase|round|step)[ _-]?\d', caseSensitive: false)
              .hasMatch(name)) {
            continue;
          }
          offences.add('${file.path}\n'
              '    → name it for what it shows, not for when it was built');
        }
      }
      expect(offences, isEmpty,
          reason: 'these file names carry a schedule position:\n\n'
              '${offences.join('\n\n')}');
    });
  });

  group('the documentation says how the member is actually called', () {
    test('no member dartdoc calls its own declaration the wrong kind', () {
      // `resolveAuthState()` was documented as "a getter", which tells the
      // reader to write `guard.resolveAuthState` — that does not compile. The
      // kind word is a call-shape claim, so it is checkable against the real
      // declaration rather than a matter of taste.
      //
      // Two narrowings, both drawn from wording that exists in this package
      // rather than invented defensively:
      //
      //   - Only the *singular* word is matched. "the gap setters read 0 as
      //     off" is a statement about a group and cannot describe the one
      //     declaration it is attached to.
      //   - A kind word introduced by a `code span` or [reference] names
      //     something else — "the `_NullableFieldLabels` getters" appears on a
      //     field in `tom_form_nullable_inputs.dart`.
      //
      // `setX(...)` builder methods are exempt from the "setter" mismatch. The
      // ACL builder calls them setters throughout, including a spec heading,
      // and the name carries `set` in plain sight — so the prose describes the
      // name and misleads nobody about the call shape. That is a consistent
      // house vocabulary, and consistency wins over a global rule.
      final offences = <String>[];
      for (final path in _allLibrarySources()) {
        for (final member in _documentedMembers(path)) {
          final isGetter = RegExp(r'\bget\s+\w+').hasMatch(member.decl);
          final isSetter = RegExp(r'\bset\s+\w+\s*\(').hasMatch(member.decl);
          final name = RegExp(r'(\w+)\s*[({=]').firstMatch(member.decl);
          final setPrefixed = name?.group(1)?.startsWith('set') ?? false;

          for (final m
              in RegExp(r'\b(getter|setter|method)\b').allMatches(member.doc)) {
            final word = m.group(1)!;
            final before = member.doc.substring(0, m.start).trimRight();
            if (before.endsWith('`') || before.endsWith(']')) continue;
            if (word == 'setter' && setPrefixed) continue;

            final actual =
                isGetter ? 'getter' : (isSetter ? 'setter' : 'method');
            if (word == actual) continue;
            offences.add('${member.path}:${member.line}\n'
                '    says "$word", but the declaration is a $actual:\n'
                '    ${member.decl}');
          }
        }
      }
      expect(offences, isEmpty,
          reason: 'these doc comments misstate how their member is called:\n\n'
              '${offences.join('\n\n')}');
    });

    test('no prose calls a code span with a call signature a getter', () {
      // `doc/custom.md` read "`… resolveAuthState()` getter". This one needs no
      // lookup at all: the span *shows* a parameter list, so it contradicts
      // itself on the page. A getter and a setter are both read or written
      // without one.
      final pattern = RegExp(r'`([^`]*\([^`]*\))`\s+(getter|setter)\b');
      final offences = <String>[];
      final docs = [
        File('README.md'),
        ...Directory('doc')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.md')),
      ]..sort((a, b) => a.path.compareTo(b.path));

      for (final file in docs) {
        // Soft wraps split these spans across lines, so match on the joined
        // text and report the file rather than a line that may not exist.
        final joined = File(file.path)
            .readAsStringSync()
            .replaceAll(RegExp(r'\s*\n\s*'), ' ');
        for (final m in pattern.allMatches(joined)) {
          offences.add('${file.path}\n'
              '    `${m.group(1)}` ${m.group(2)}\n'
              '    → the span shows a call signature, so it is a method');
        }
      }
      expect(offences, isEmpty,
          reason: 'these spans contradict the word beside them:\n\n'
              '${offences.join('\n\n')}');
    });
  });
}
