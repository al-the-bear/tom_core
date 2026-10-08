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
/// **Every module barrel is documented, and [_knownUndocumented] is empty.**
/// It was a ratchet while it was being worked off, and the mechanism stays:
/// a new barrel added without a dartdoc fails, and so does an attempt to
/// silence that failure by re-populating the set. Emptiness is itself
/// asserted, so the escape hatch that made the sweep possible cannot quietly
/// become the way new gaps are accepted.
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
/// **The fourth group polices a narrower claim: how the member is called.**
/// Prose that calls `resolveAuthState()` "a getter" is not a style quibble —
/// it tells the reader to write `guard.resolveAuthState`, which does not
/// compile, and it hid a second error behind it (the comment justified the
/// member by subclass-overriding, which no test does). Both checks re-derive
/// the real declaration kind from source rather than trusting a list.
///
/// **The final group polices where a library dartdoc may point**, in three
/// checks, each taking a question it can answer exactly rather than guessing
/// at the rest.
///
/// A library dartdoc resolves in *library* scope, so a bare
/// `[fallbackBuilder]` — an instance field — links to nothing no matter what
/// the file imports; only `[TomErrorBoundary.fallbackBuilder]` reaches it.
/// The first check asks only about members of the file it is reading, because
/// that is the one version of the question no import can change the answer to.
///
/// The second takes the narrow slice of the *type* question that is still
/// decidable: a type declared in a sibling file, in the same folder, that this
/// file never imports. `tom_infinite_scroll.dart` claimed its default builders
/// rendered `[TomErrorBoundary]` while importing two siblings and building its
/// error slot from raw Material widgets — a dead link wrapped around a false
/// claim.
///
/// The third widens that to the whole package by resolving the import graph
/// instead of approximating it. `[TomAction]` in a barrel is unresolvable and
/// entirely correct — a barrel `export`s rather than `import`s — so the check
/// computes each file's transitive *export* surface and treats "this file
/// exports the type" as the barrel's licence to name it. That distinction is
/// exact rather than heuristic, which is what lets the rule leave the folder
/// boundary behind. The walk itself lives in `support/export_surface.dart`,
/// shared with `package_barrel_test.dart`; why *this* rule is drawn from it is
/// argued at the check.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/export_surface.dart';

/// The package barrel — the sole library `dart doc` emits a page for.
const _packageBarrel = 'lib/tom_flutter_ui.dart';

/// The ACL module barrel, whose orientation duty this test pins in detail.
const _aclBarrel =
    'lib/src/advanced_container_layout/advanced_container_layout.dart';

/// Module barrels allowed to carry no library dartdoc.
///
/// Empty, and pinned empty below. It held five entries while the sweep was in
/// progress — each one a reader arriving at a bare `export` list — and every
/// one of them has since been written. Adding an entry back is how a real
/// regression would be made to look intentional, so it is a failure rather
/// than a decision available to whoever hits the ratchet.
const _knownUndocumented = <String>{};

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
    if (RegExp(
      r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|'
      r'mixin\s+)*(?:class|enum|mixin|extension|typedef)\b',
    ).hasMatch(decl)) {
      continue;
    }
    if (decl.startsWith('library')) continue;
    out.add((path: path, line: start + 1, doc: doc.join(' '), decl: decl));
  }
  return out;
}

/// The `export 'src/…';` targets of the package barrel, as repo-relative paths.
///
/// Derived rather than listed, so a newly added unit is covered the moment it
/// is exported instead of when someone remembers to update this file.
List<String> _moduleBarrels() {
  final source = File(_packageBarrel).readAsStringSync();
  return RegExp(
    r"^export '([^']+)';",
    multiLine: true,
  ).allMatches(source).map((m) => 'lib/${m.group(1)!}').toList();
}

/// The unit a module barrel belongs to: its directory under `lib/src/`, or its
/// own basename when it sits directly in `lib/src/`.
///
/// `lib/src/widget_base/widget_base.dart` → `widget_base`;
/// `lib/src/kernel_types.dart` → `kernel_types`;
/// `lib/src/forms/tom_forms.dart` → `forms` (the file name and the unit name
/// disagree, which is why this reads the directory rather than the basename).
String _unitName(String barrelPath) {
  final parts = barrelPath.split('/'); // lib / src / … / <file>.dart
  return parts.length > 3 ? parts[2] : parts.last.replaceAll('.dart', '');
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

/// The library dartdoc of [path] as 1-based `(line, text)` pairs, so an
/// offence can name a line the reader can jump to. Empty when the file has no
/// library dartdoc — same `library;` anchor rule as [_libraryDartdoc].
List<({int line, String text})> _libraryDartdocLines(String path) {
  final lines = File(path).readAsLinesSync();
  final doc = <({int line, String text})>[];
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('///')) {
      doc.add((line: i + 1, text: trimmed.substring(3).trim()));
      continue;
    }
    if (trimmed == 'library;') return doc;
    if (trimmed.isEmpty) continue;
    return const [];
  }
  return const [];
}

/// The type names declared by the files sitting beside [path], as
/// `name -> file name`.
///
/// Restricted to one directory on purpose. That restriction is what makes the
/// sibling check answerable without resolving a package graph: a relative
/// `import` with no `/` in it names a file in this very folder, so "did this
/// file import that one" reduces to comparing two strings.
Map<String, String> _siblingTypes(String path) {
  final directory = File(path).parent;
  final types = <String, String>{};
  for (final entity in directory.listSync().whereType<File>()) {
    if (!entity.path.endsWith('.dart')) continue;
    final name = entity.uri.pathSegments.last;
    if (name == path.split(Platform.pathSeparator).last) continue;
    for (final m in RegExp(
      r'^(?:abstract |base |final |sealed |interface |mixin )*'
      r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
      multiLine: true,
    ).allMatches(entity.readAsStringSync())) {
      types.putIfAbsent(m.group(1)!, () => name);
    }
  }
  return types;
}

/// The file names [path] pulls in from its own directory.
///
/// `export` counts as well as `import`. A barrel that re-exports a sibling is
/// entitled to name it in prose, and the point of this set is to stay silent
/// wherever the reference is defensible.
Set<String> _sameDirectoryLinks(String path) {
  final linked = RegExp(
    r"^(?:import|export)\s+'([^'/:]+\.dart)'",
    multiLine: true,
  ).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();
  // A linked file may be one file of a several-file library, and linking the
  // library reaches all of it. `acl_container.dart` is twelve files; a barrel
  // that exports it is entitled to name what its parts declare, and stopping
  // at the named file reports a correct reference as a dangling one.
  final directory = File(path).parent;
  for (final name in linked.toList()) {
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    if (!file.existsSync()) continue;
    for (final m in RegExp(
      r"^\s*part\s+'([^'/:]+\.dart)'",
      multiLine: true,
    ).allMatches(file.readAsStringSync())) {
      linked.add(m.group(1)!);
    }
  }
  return linked;
}

/// The names [path] declares, split by what a *library* dartdoc is allowed to
/// reach: `topLevel` is in scope there, `members` never is.
///
/// The split is the whole point. A library dartdoc is resolved in library
/// scope, so `[fallbackBuilder]` — an instance field — resolves to nothing no
/// matter what is imported, while `[TomErrorBoundary.fallbackBuilder]` resolves
/// through the class. Column position is what separates the two: Dart's
/// formatter puts top-level declarations at column 0 and members under an
/// indent, so "is this a member" is decidable by reading one file.
///
/// Both sets are gathered leniently, and in opposite directions on purpose.
/// `topLevel` over-collects, because every name in it is one the check stays
/// silent about. `members` is built from the shapes that actually carry widget
/// configuration — `this.x` constructor parameters above all — because a name
/// missing from it is only a defect this check declines to report, never a
/// false alarm.
({Set<String> topLevel, Set<String> members}) _declaredNames(String path) {
  final lines = File(path).readAsLinesSync();
  var i = 0;
  while (i < lines.length && lines[i].trim().startsWith('///')) {
    i++;
  }
  final body = lines.skip(i).join('\n');

  final topLevel = <String>{
    for (final m in RegExp(
      r'^(?:abstract |base |final |sealed |interface |mixin )*'
      r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
    for (final m in RegExp(
      r'^(?:[\w<>,\s?]+\s+)?(\w+)\s*\(',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
    for (final m in RegExp(
      r'^(?:const|final|var)\s+(?:[\w<>?]+\s+)?(\w+)\s*=',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
  };

  final members = <String>{
    // `this.foo` in a constructor — how nearly every widget field arrives.
    for (final m in RegExp(r'\bthis\.(\w+)').allMatches(body)) m.group(1)!,
    for (final m in RegExp(
      r'^\s+(?:final|const|late|static|var)\s[\w<>?,\s]*?(\w+)\s*[;=]',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
    for (final m in RegExp(
      r'^\s+[\w<>?,\s]+\bget\s+(\w+)',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
    for (final m in RegExp(
      r'^\s{2,}(?:[\w<>?,\s]+\s+)?(\w+)\s*\([^)]*\)\s*(?:\{|=>|async)',
      multiLine: true,
    ).allMatches(body))
      m.group(1)!,
  };

  return (topLevel: topLevel, members: members);
}

void main() {
  group('the package barrel documents itself', () {
    // This is the one page `dart doc` generates, so an omission here is
    // invisible in the source tree and total in the output.
    late String doc;

    setUpAll(() => doc = _libraryDartdoc(_packageBarrel));

    test('it has a library dartdoc at all', () {
      expect(
        doc,
        isNotEmpty,
        reason:
            '$_packageBarrel is the only library `dart doc` emits a '
            'page for. Without a `///` run before `library;` that page has '
            'no description whatsoever.',
      );
    });

    test('it opens with a statement of what the package is', () {
      final firstParagraph = doc.split('\n\n').first;
      expect(
        firstParagraph.length,
        greaterThan(60),
        reason:
            'the opening paragraph is the whole of what a reader is '
            'shown before the member list; one line is not enough',
      );
    });

    test('it names every unit it exports', () {
      // The landing page carries the unit map, because no module barrel gets a
      // page of its own to carry it.
      //
      // Matching on the backticked unit name rather than a bare substring is
      // deliberate: `widgets` and `widget_base` both occur in ordinary prose
      // about widgets, so a substring test would pass on a page that never
      // lists them.
      final missing =
          _moduleBarrels()
              .map(_unitName)
              .where((unit) => !doc.contains('`$unit`'))
              .toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'these exported units are not named on the landing page, so '
            'a reader cannot learn they exist: $missing',
      );
    });

    test('it points at the documentation set', () {
      expect(
        doc,
        contains('doc/README.md'),
        reason:
            'the landing page should hand the reader on to the doc '
            'index rather than being the end of the trail',
      );
    });
  });

  group('the ACL module barrel orients its reader', () {
    // The unit exports around thirty types; a reader needs to be told which
    // two to read first.
    late String doc;

    setUpAll(() => doc = _libraryDartdoc(_aclBarrel));

    test('it has a library dartdoc', () {
      expect(doc, isNotEmpty, reason: '$_aclBarrel carries no library dartdoc');
    });

    test('it states what the unit is in a paragraph', () {
      final firstParagraph = doc.split('\n\n').first;
      expect(
        firstParagraph.length,
        greaterThan(60),
        reason: 'a one-line summary does not tell a newcomer what ACL is',
      );
    });

    test('it names the entry points', () {
      // Out of ~30 exported types, these are the two a newcomer should read
      // first — naming them is the difference between a barrel and a map.
      for (final entryPoint in ['[AclBuilder]', '[Acl]']) {
        expect(
          doc,
          contains(entryPoint),
          reason: '$_aclBarrel should name $entryPoint as an entry point',
        );
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
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$_aclBarrel points at $path, which is not there',
        );
      }
    });
  });

  group('the undocumented-barrel ratchet', () {
    test('the known-gap list is empty', () {
      // The list is the only way a bare barrel can pass the check below, so
      // without this the sweep is undone by a one-line edit that reads like
      // bookkeeping. Every module barrel is documented; keep it that way by
      // making the exemption unavailable rather than merely discouraged.
      expect(
        _knownUndocumented,
        isEmpty,
        reason:
            'a module barrel was exempted from needing a library '
            'dartdoc. Write the dartdoc instead — the shape is a paragraph '
            'saying what the unit is, the two or three types to read first '
            'as [] refs, and the unit\'s doc/ document named by path:\n'
            '${_knownUndocumented.map((p) => '  $p').join('\n')}',
      );
    });

    test('every module barrel is documented, or listed as a known gap', () {
      final undocumented = _moduleBarrels()
          .where((path) => _libraryDartdoc(path).isEmpty)
          .toSet();

      final regressions = undocumented.difference(_knownUndocumented).toList()
        ..sort();
      expect(
        regressions,
        isEmpty,
        reason:
            'these module barrels lost or never had a library dartdoc '
            'and are not on the known-gap list. Document them, or — if the '
            'gap is deliberate — add them to _knownUndocumented with a '
            'reason:\n${regressions.map((p) => '  $p').join('\n')}',
      );
    });

    test('the known-gap list contains no stale entries', () {
      // Keeps the list honest in the other direction: an entry that has since
      // been documented, renamed or deleted must come off, so the set always
      // reads as the real outstanding work.
      final barrels = _moduleBarrels().toSet();
      final stale =
          _knownUndocumented
              .where(
                (path) =>
                    !barrels.contains(path) || _libraryDartdoc(path).isNotEmpty,
              )
              .toList()
            ..sort();
      expect(
        stale,
        isEmpty,
        reason:
            'these entries in _knownUndocumented are no longer '
            'undocumented module barrels — remove them:\n'
            '${stale.map((p) => '  $p').join('\n')}',
      );
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
      for (final path in allLibrarySources()) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final entry in _rolloutMarkers.entries) {
            if (!RegExp(entry.key).hasMatch(lines[i])) continue;
            offences.add(
              '$path:${i + 1}\n'
              '    ${lines[i].trim()}\n'
              '    → ${entry.value}',
            );
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these lines date the documentation to a schedule the '
            'reader cannot see:\n\n${offences.join('\n\n')}',
      );
    });

    test('no library dartdoc opens by naming its own subject', () {
      // "`TomAuthGuard`." as an opening line tells a reader nothing they did
      // not already know from the file name — and it is what a phase label is
      // usually attached to, so removing the label can leave this behind.
      //
      // Derived from each file's own declarations rather than a list of
      // names, so it keeps working as types are added and renamed.
      final offences = <String>[];
      for (final path in allLibrarySources()) {
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

        final declared = declaredTypes(File(path).readAsStringSync());
        if (words.every(declared.contains)) {
          offences.add(
            '$path\n'
            '    $opener\n'
            '    → names the file\'s own types and nothing else',
          );
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these library dartdocs open with a label instead of a '
            'statement of what the library is:\n\n${offences.join('\n\n')}',
      );
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
          if (!RegExp(
            r'(phase|round|step)[ _-]?\d',
            caseSensitive: false,
          ).hasMatch(name)) {
            continue;
          }
          offences.add(
            '${file.path}\n'
            '    → name it for what it shows, not for when it was built',
          );
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these file names carry a schedule position:\n\n'
            '${offences.join('\n\n')}',
      );
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
      for (final path in allLibrarySources()) {
        for (final member in _documentedMembers(path)) {
          final isGetter = RegExp(r'\bget\s+\w+').hasMatch(member.decl);
          final isSetter = RegExp(r'\bset\s+\w+\s*\(').hasMatch(member.decl);
          final name = RegExp(r'(\w+)\s*[({=]').firstMatch(member.decl);
          final setPrefixed = name?.group(1)?.startsWith('set') ?? false;

          for (final m in RegExp(
            r'\b(getter|setter|method)\b',
          ).allMatches(member.doc)) {
            final word = m.group(1)!;
            final before = member.doc.substring(0, m.start).trimRight();
            if (before.endsWith('`') || before.endsWith(']')) continue;
            if (word == 'setter' && setPrefixed) continue;

            final actual = isGetter
                ? 'getter'
                : (isSetter ? 'setter' : 'method');
            if (word == actual) continue;
            offences.add(
              '${member.path}:${member.line}\n'
              '    says "$word", but the declaration is a $actual:\n'
              '    ${member.decl}',
            );
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these doc comments misstate how their member is called:\n\n'
            '${offences.join('\n\n')}',
      );
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
        final joined = File(
          file.path,
        ).readAsStringSync().replaceAll(RegExp(r'\s*\n\s*'), ' ');
        for (final m in pattern.allMatches(joined)) {
          offences.add(
            '${file.path}\n'
            '    `${m.group(1)}` ${m.group(2)}\n'
            '    → the span shows a call signature, so it is a method',
          );
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these spans contradict the word beside them:\n\n'
            '${offences.join('\n\n')}',
      );
    });
  });

  group('a library dartdoc only links what library scope can reach', () {
    test('no library dartdoc references a member of its own file', () {
      // `tom_error_boundary.dart` ended its library dartdoc with "configurable
      // via [fallbackBuilder]". A library dartdoc resolves in *library* scope,
      // where an instance field is not visible, so that link rendered as dead
      // plain text — in the sentence telling the reader how to configure the
      // widget. `[TomErrorBoundary.fallbackBuilder]` resolves; the bare name
      // never can, whatever is imported.
      //
      // That "whatever is imported" is why this check is worth having and the
      // `comment_references` lint is not. The lint flags 180 references in this
      // package, and they are overwhelmingly *correct* pointers at real classes
      // in sibling files — a barrel `export`s rather than `import`s, so
      // `[TomAction]` in `actions.dart` is unresolvable and completely right.
      // Silencing those would mean adding imports that exist only for prose,
      // several of them cycles. This check asks a strictly narrower question
      // with no import in it: is the name a *member of this very file*? Then no
      // import could have helped, and the reference is wrong on its own terms.
      //
      // The same reasoning `tool/check_dartdoc_refs.py` applies to private
      // names, which is where the phantom `[_TomErrorBoundaryMarker]` in this
      // file's earlier dartdoc was caught. Both checks pick the question that
      // one file can answer alone.
      final offences = <String>[];
      for (final path in allLibrarySources()) {
        final doc = _libraryDartdocLines(path);
        if (doc.isEmpty) continue;
        final declared = _declaredNames(path);

        for (final entry in doc) {
          for (final m in RegExp(
            r'\[([A-Za-z_][\w.]*)\]',
          ).allMatches(entry.text)) {
            final name = m.group(1)!;
            // Already qualified — `[Foo.bar]` reaches `bar` through `Foo`.
            if (name.contains('.')) continue;
            // A capitalised name is a type. Whether it resolves depends on the
            // imports, which is exactly the question this check refuses.
            if (name[0].toUpperCase() == name[0]) continue;
            if (declared.topLevel.contains(name)) continue;
            if (!declared.members.contains(name)) continue;

            offences.add(
              '$path:${entry.line}\n'
              '    [$name] is a member of this file, so it is out of scope '
              'in a library dartdoc\n'
              '    → qualify it: [<OwningClass>.$name]',
            );
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these library dartdocs link names that cannot resolve:\n\n'
            '${offences.join('\n\n')}',
      );
    });

    test('no library dartdoc links a same-directory sibling it never imports', () {
      // `tom_infinite_scroll.dart` opened with "The default slot builders
      // render [TomEmptyState], [TomSkeletonLoader] and [TomErrorBoundary]".
      // Two of the three were real. The file imports exactly two siblings and
      // its error slot is raw Material widgets, so the link was dead *and* the
      // sentence was false — which is the pairing worth catching: a claim about
      // what this file is built from, contradicted by what it imports.
      //
      // The sibling case is the one slice of "does this type resolve" that a
      // single directory can settle, and it earns its keep because the repair
      // is free either way — add the missing import, or write the name in
      // backticks because the file genuinely does not use it.
      //
      // Measured on this package before the rule was adopted: 55 sibling
      // references across 40 library dartdocs, of which exactly one was wrong.
      //
      // Types from further afield are the next check's business, and it
      // subsumes this one — a sibling is imported through the same graph as
      // anything else. This one is kept because it is answerable by reading a
      // single folder, so it stays correct if the graph walk ever needs to be
      // narrowed, and because its message names the neighbouring file directly.
      final offences = <String>[];
      for (final path in allLibrarySources()) {
        final doc = _libraryDartdocLines(path);
        if (doc.isEmpty) continue;
        final siblings = _siblingTypes(path);
        final linked = _sameDirectoryLinks(path);
        final own = _declaredNames(path).topLevel;

        for (final entry in doc) {
          for (final m in RegExp(r'\[([A-Z][\w]*)\]').allMatches(entry.text)) {
            final name = m.group(1)!;
            if (own.contains(name)) continue;
            final home = siblings[name];
            // Not a neighbour, so whether it resolves is an import-graph
            // question this check has no business answering.
            if (home == null) continue;
            if (linked.contains(home)) continue;

            offences.add(
              '$path:${entry.line}\n'
              '    [$name] lives in $home, beside this file, but this file '
              'never imports it\n'
              '    → import $home, or write it as `$name` if the file does '
              'not use it',
            );
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these library dartdocs link uses they do not have:\n\n'
            '${offences.join('\n\n')}',
      );
    });

    test('no library dartdoc links a package type it neither imports nor '
        'exports', () {
      // The same defect one directory further out, and milder: here the prose
      // is true and only the link is dead. `tom_auth_tree.dart` read "Contrast
      // [TomTreeView], whose authorization is widget-level" — an accurate
      // cross-reference to `widgets/trees/`, which `custom/` does not import
      // and should not import for the sake of a sentence. The reader is not
      // misled; they simply do not get the navigation the brackets promise.
      //
      // The rule the sibling check above declined to widen into is decidable
      // after all. A library dartdoc resolves in *library* scope, where
      // `export` brings in nothing — so a barrel naming `[TomAction]` is
      // unresolvable, and also entirely correct: the barrel is the reason that
      // name is reachable at all, and the alternative is importing a type
      // purely so prose can link it, several of them cycles. Asking "does this
      // file export the type" separates the two populations *exactly*. The two
      // heuristics considered instead merely correlate with the answer:
      // counting `export` directives is defeated by a two-export barrel, and
      // asking whether the type appears outside the dartdoc does not
      // discriminate at all, since a barrel also names its exports only in
      // prose.
      //
      // Measured on this package before the rule was adopted: 106 library
      // dartdoc references to a type declared under `lib/` that library scope
      // cannot reach. 100 of them are a barrel naming what it exports and are
      // carved out with no false positives; the remaining 6 were dead links in
      // three implementation files, all now written as backticks. That the
      // carve-out is still doing that work is asserted below, so a change that
      // quietly stopped it matching would fail here rather than start
      // reporting a hundred correct references.
      final surfaces = exportSurfaces();
      final homes = typeHomes();
      final offences = <String>[];
      var carvedOut = 0;

      for (final path in allLibrarySources()) {
        final doc = _libraryDartdocLines(path);
        if (doc.isEmpty) continue;
        final reachable = reachableTypes(path, surfaces);
        final exported = surfaces[path] ?? const <String>{};

        for (final entry in doc) {
          for (final m in RegExp(r'\[([A-Z]\w*)\]').allMatches(entry.text)) {
            final name = m.group(1)!;
            final home = homes[name];
            // Declared elsewhere — the Flutter SDK, the kernel, or nowhere at
            // all. `tool/check_dartdoc_refs.py` owns the phantom case.
            if (home == null) continue;
            if (reachable.contains(name)) continue;
            if (exported.contains(name)) {
              carvedOut++;
              continue;
            }

            offences.add(
              '$path:${entry.line}\n'
              '    [$name] is declared in $home, which this file neither '
              'imports nor exports\n'
              '    → write it as `$name`, or import $home if the file uses it',
            );
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason:
            'these library dartdocs promise links they cannot deliver:\n\n'
            '${offences.join('\n\n')}',
      );
      expect(
        carvedOut,
        greaterThan(50),
        reason:
            'the barrel carve-out matched $carvedOut references, far below the '
            '100 measured — either the barrels stopped naming what they '
            'export, or the export surface is no longer being computed, and '
            'in the second case this check is silent for the wrong reason',
      );
    });
  });

  group('the package reaches other packages only through their barrels', () {
    test('no directive under lib/ names another package\'s lib/src', () {
      // `lib/src/` is Dart's convention for "not part of the public API", so
      // a directive that names one couples this package to a layout the other
      // package never promised to keep: a reorganisation there becomes a
      // compile error here even when its public surface never moved.
      //
      // Two files did this — both re-exporting the kernel's authorization
      // types from `tom_core_kernel/src/tombase/security/`, which the kernel
      // barrel already exports unfiltered. The deep path bought nothing and
      // risked exactly that breakage.
      //
      // The `implementation_imports` lint covers the `import` half of this and
      // is enabled in `analysis_options.yaml`; it does not fire on `export`,
      // which is the half that actually occurred. Hence this test.
      final directive = RegExp(
        r"^\s*(import|export)\s+'package:(\w+)/src/([^']*)'",
        multiLine: true,
      );
      final offences = <String>[];
      for (final path in allLibrarySources()) {
        final source = File(path).readAsStringSync();
        for (final m in directive.allMatches(source)) {
          final package = m.group(2)!;
          offences.add(
            '$path\n'
            '    ${m.group(1)} of package:$package/src/${m.group(3)}\n'
            '    → name the public barrel, package:$package/$package.dart',
          );
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'these directives reach into another package\'s private '
            'source:\n\n${offences.join('\n\n')}',
      );
    });
  });
}
