import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards the markdown links this package ships.
///
/// A link can fail in three ways, and only the first is obvious. It can point
/// at nothing — a path that does not resolve — or it can resolve cleanly onto
/// the *wrong* document. The second kind survives every path check ever
/// written, so it is checked separately here: when a link's label is a single
/// code-span identifier, the reader is being told "follow this to read about
/// `X`", and the guard holds the target to that promise by requiring it to
/// mention `X`.
///
/// The third is a link into the *same* document — an anchor. Path checks skip
/// it by construction, because there is no path, and a stale anchor renders as
/// an ordinary link that simply goes nowhere. That matters most for a table of
/// contents, whose entries are all anchors and which is the one part of a
/// document that is expected to stay in step with the rest of it: a section
/// added without its entry leaves the document advertising a shorter shape
/// than it has, and every reader who navigates by the contents never reaches
/// it. Both are guarded under `document structure` below.
///
/// The last group guards something that is not a link at all but fails the same
/// way — a claim in a document that the code stopped supporting. A module
/// document's `## Dependencies` section names types, and deleting the code that
/// used one leaves the line naming it in place; `documented dependencies`
/// requires every symbol listed there to be one the module actually refers to.
void main() {
  /// Roots that hold documentation this package publishes or maintains.
  const roots = <String>[
    'README.md',
    'CHANGELOG.md',
    'doc',
    'lib',
    'example',
    '_copilot_guidelines',
  ];

  /// `[label](target)`, with an optional `"title"` after the target.
  final linkPattern = RegExp(r'\[([^\]\n]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)');

  /// A label that is exactly one code-span identifier, e.g. ``[`TomException`]``.
  final identifierLabel = RegExp(r'^`([A-Za-z_][A-Za-z0-9_]*)`$');

  final fencedCode = RegExp(r'```[\s\S]*?```');

  /// An inline code span, e.g. ``` `TomException` ```.
  final inlineCode = RegExp(r'`[^`\n]*`');

  List<String> markdownFiles() {
    final files = <String>[];
    for (final root in roots) {
      if (FileSystemEntity.isFileSync(root)) {
        files.add(root);
        continue;
      }
      if (!Directory(root).existsSync()) continue;
      files.addAll(
        Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => p.normalize(f.path))
            .where((path) => path.endsWith('.md')),
      );
    }
    files.sort();
    return files;
  }

  /// Every *live* link in [file] — one a reader can follow.
  ///
  /// Link syntax quoted rather than used does not count, and there are two
  /// ways to quote it. A fenced block is dropped outright. An inline code span
  /// is subtler, because the two nestings mean opposite things: in
  /// ``[`Type`](target)`` the span is *inside* the link and the link is live,
  /// while in ``` `[Type](target)` ``` the link is inside the span and is
  /// prose about a link. Stripping spans would destroy the first kind's label,
  /// so links are matched whole and then discarded when they *start* inside a
  /// span — which is exactly the second nesting.
  Iterable<RegExpMatch> linksIn(String file) {
    final text = File(file).readAsStringSync().replaceAll(fencedCode, '');
    final quoted = inlineCode.allMatches(text);
    return linkPattern
        .allMatches(text)
        .where(
          (link) =>
              !quoted.any((q) => q.start < link.start && link.start < q.end),
        );
  }

  /// The on-disk path a link target resolves to, or `null` when the target is
  /// not a repository-relative path.
  ///
  /// Skipped: external schemes, same-document anchors, and `/`-rooted targets —
  /// the last are workspace-root-relative by convention, and the workspace root
  /// sits above this repository, so they are not resolvable from here.
  String? resolve(String file, String target) {
    if (target.startsWith('http://') ||
        target.startsWith('https://') ||
        target.startsWith('mailto:') ||
        target.startsWith('#') ||
        target.startsWith('/')) {
      return null;
    }
    return p.normalize(p.join(p.dirname(file), target.split('#').first));
  }

  /// The fragment a renderer derives from [heading] text.
  ///
  /// Follows `github-slugger`, which is the algorithm the rendered documents are
  /// read through, in three steps: lower-case, drop punctuation, then replace
  /// **each** remaining space with a hyphen.
  ///
  /// Both details that look like rounding errors are load-bearing. HTML entities
  /// are decoded before punctuation is dropped, because a heading that has to
  /// show a generic — `TomSetting&lt;T&gt;` — is anchored as the `<` and `>` it
  /// renders as, not as the letters of the escape; skipping that reports five
  /// live links in this package as dead. And spaces are replaced one at a time
  /// rather than by run, because dropping the punctuation *between* two spaces
  /// leaves both of them: `Memory Management — you must retain the observer`
  /// anchors as `memory-management--you-must-retain-the-observer`, with two
  /// hyphens. Collapsing the run instead reports that link dead too — which is
  /// how this was found.
  String anchorOf(String heading) {
    var text = heading.toLowerCase();
    for (final entity in const {
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
    }.entries) {
      text = text.replaceAll(entity.key, entity.value);
    }
    text = text.replaceAll(RegExp(r'[^\w\s-]'), '');
    return text.trim().replaceAll(' ', '-');
  }

  /// [file]'s text with fenced code removed — headings and links only.
  String proseOf(String file) =>
      File(file).readAsStringSync().replaceAll(fencedCode, '');

  /// Every heading in [file], as `(level, text)`.
  List<(int, String)> headingsIn(String file) =>
      RegExp(r'^(#{1,6}) (.+)$', multiLine: true)
          .allMatches(proseOf(file))
          .map((m) => (m.group(1)!.length, m.group(2)!.trim()))
          .toList();

  /// The text under [file]'s `## Table of Contents`, up to the next `##`.
  ///
  /// Empty when the document has no contents block.
  String contentsBlockOf(String file) {
    final prose = proseOf(file);
    final start = RegExp(
      r'^## Table of Contents$',
      multiLine: true,
    ).firstMatch(prose);
    if (start == null) return '';
    final rest = prose.substring(start.end);
    final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
    return next == null ? rest : rest.substring(0, next.start);
  }

  group('documentation links', () {
    test('every repository-relative link resolves on disk', () {
      final dead = <String>[];
      for (final file in markdownFiles()) {
        for (final link in linksIn(file)) {
          final target = link.group(2)!;
          final path = resolve(file, target);
          if (path == null) continue;
          if (!File(path).existsSync() && !Directory(path).existsSync()) {
            dead.add('$file: [${link.group(1)}]($target)');
          }
        }
      }
      expect(
        dead,
        isEmpty,
        reason:
            'These links point at paths that do not exist:\n${dead.join('\n')}',
      );
    });

    test('every identifier-labelled link lands on a document that '
        'documents that identifier', () {
      final wrong = <String>[];
      for (final file in markdownFiles()) {
        for (final link in linksIn(file)) {
          final identifier = identifierLabel
              .firstMatch(link.group(1)!.trim())
              ?.group(1);
          if (identifier == null) continue;
          final path = resolve(file, link.group(2)!);
          if (path == null || !path.endsWith('.md')) continue;
          if (!File(path).existsSync()) continue; // reported by the test above
          if (!File(path).readAsStringSync().contains(identifier)) {
            wrong.add(
              '$file: [`$identifier`](${link.group(2)}) — the target never '
              'mentions $identifier',
            );
          }
        }
      }
      expect(
        wrong,
        isEmpty,
        reason:
            'These links resolve, but to a document that does not describe the '
            'identifier they are labelled with:\n${wrong.join('\n')}',
      );
    });

    // Both guards above pass vacuously if the scan finds nothing — a broken
    // file walk or link pattern would read as a clean bill of health. These
    // pin that the scan still sees the corpus it was written against.
    test('the scan still finds the documentation it guards', () {
      final files = markdownFiles();
      var relative = 0;
      var identifierLabelled = 0;
      for (final file in files) {
        for (final link in linksIn(file)) {
          final path = resolve(file, link.group(2)!);
          if (path == null) continue;
          relative++;
          if (identifierLabel.hasMatch(link.group(1)!.trim())) {
            identifierLabelled++;
          }
        }
      }
      expect(files.length, greaterThanOrEqualTo(20));
      expect(relative, greaterThanOrEqualTo(40));
      expect(identifierLabelled, greaterThanOrEqualTo(10));
    });

    // The link this guard was written for: the little_things prose document
    // sends the reader to the kernel for the base type's payload.
    test('the little_things document points at the kernel little_things '
        'document for TomException', () {
      final links = linksIn('doc/little_things.md')
          .where((l) => l.group(1)!.trim() == '`TomException`')
          .map((l) => l.group(2)!)
          .toList();
      expect(links, isNotEmpty, reason: 'the outbound link has been removed');
      for (final target in links) {
        expect(target, endsWith('/little_things/little_things.md'));
      }
    });
  });

  group('document structure', () {
    /// The anchor pattern, matched on prose so a quoted example does not count.
    final anchorLink = RegExp(r'\[([^\]\n]*)\]\(#([^)\s]+)\)');

    test('every same-document anchor points at a heading that exists', () {
      final dead = <String>[];
      for (final file in markdownFiles()) {
        final targets = {for (final h in headingsIn(file)) anchorOf(h.$2)};
        for (final link in anchorLink.allMatches(proseOf(file))) {
          if (!targets.contains(link.group(2))) {
            dead.add('$file: [${link.group(1)}](#${link.group(2)})');
          }
        }
      }
      expect(
        dead,
        isEmpty,
        reason:
            'These anchors name no heading in their own document, so they '
            'render as links that go nowhere:\n${dead.join('\n')}',
      );
    });

    test('every cross-document anchor points at a heading in the document it '
        'names', () {
      // 'every repository-relative link resolves on disk' checks the path and
      // drops the fragment, so a link into another document was checked only as
      // far as the file. That is the half that rarely breaks: a renamed heading
      // leaves the path valid and the link silently landing at the top of the
      // right document, which reads as if the reference were simply vague.
      final dead = <String>[];
      for (final file in markdownFiles()) {
        for (final link in linksIn(file)) {
          final target = link.group(2)!;
          if (!target.contains('#') || target.startsWith('#')) continue;
          final path = resolve(file, target);
          if (path == null || !File(path).existsSync()) continue;
          final fragment = target.split('#').last;
          final targets = {for (final h in headingsIn(path)) anchorOf(h.$2)};
          if (!targets.contains(fragment)) {
            dead.add('$file: [${link.group(1)}]($target)');
          }
        }
      }
      expect(
        dead,
        isEmpty,
        reason:
            'These links name a heading their target document does not '
            'have, so they land at the top of it instead:\n${dead.join('\n')}',
      );
    });

    test("every module document's table of contents lists every one of its "
        'sections, in order', () {
      // The contents block is the one part of a document that has to be
      // maintained in step with the rest of it, and nothing about editing a
      // document makes that happen. A section added without its entry is
      // invisible to a reader who navigates by the contents — which is how
      // `doc/preferences.md` could have gained its Scope section and still not
      // offered it (tcinc666).
      //
      // Only top-level (`##`) sections are *required* to be listed. The API
      // summaries additionally nest their `###` classes under them, which is
      // more detail than this asks for, not a disagreement — so extra entries
      // are allowed and only omissions and misorderings are reported.
      //
      // Documents without a contents block are not required to grow one; this
      // checks agreement where the block exists, not its existence.
      final mismatched = <String>[];
      var checked = 0;
      for (final file in markdownFiles()) {
        final headings = headingsIn(file);
        if (!headings.any((h) => h.$1 == 2 && h.$2 == 'Table of Contents')) {
          continue;
        }
        checked++;

        final sections = [
          for (final h in headings)
            if (h.$1 == 2 && h.$2 != 'Table of Contents') h.$2,
        ];
        final wanted = [for (final s in sections) anchorOf(s)];

        // Entries are read from the contents block alone. A document also
        // links to its own sections from its prose — this file's own subject
        // document does, from the `getFor` paragraph — and counting those as
        // entries would make the block look like it listed a section twice.
        final block = contentsBlockOf(file);
        final listed = [
          for (final m in anchorLink.allMatches(block)) m.group(2)!,
        ];

        final missing = [
          for (var i = 0; i < sections.length; i++)
            if (!listed.contains(wanted[i])) sections[i],
        ];
        if (missing.isNotEmpty) {
          mismatched.add('$file: not listed in the contents: $missing');
          continue;
        }
        // Order is checked over the listed sections only, so nested class
        // entries in between do not count as a reordering.
        final listedSections = [
          for (final anchor in listed)
            if (wanted.contains(anchor)) anchor,
        ];
        if (listedSections.join('\n') != wanted.join('\n')) {
          mismatched.add(
            '$file: the contents lists the sections in a different order than '
            'the document presents them\n  contents: $listedSections\n'
            '  document: $wanted',
          );
        }
      }
      expect(
        mismatched,
        isEmpty,
        reason:
            'These contents blocks disagree with the sections they '
            'describe:\n${mismatched.join('\n')}',
      );
      // Pins that the walk still finds the documents — the check above is
      // vacuous if `checked` is zero.
      expect(checked, greaterThanOrEqualTo(7));
    });
  });

  group('documented dependencies', () {
    /// A framework symbol: a `TomFoo` type, or a `tomFoo` top-level marker or
    /// instance. Package names (`tom_core_kernel`) are excluded by requiring a
    /// capital after the prefix, and a member access matches only its type, so
    /// `TomApiEndpoint.resolveUri` is checked as `TomApiEndpoint`.
    final frameworkSymbol = RegExp(r'@?\b[Tt]om[A-Z][A-Za-z0-9]*\b');

    /// The bullet list under [file]'s `## Dependencies`, or `''` if it has none.
    ///
    /// The list only — not the whole section. Prose after it describes what an
    /// *application* must do, which legitimately names types the module itself
    /// never touches: `doc/preferences.md` closes by telling the reader to
    /// register a platform with `TomPlatformUtils`, which is true, load-bearing,
    /// and reached three collaborators away.
    String dependencyBulletsOf(String file) {
      final prose = proseOf(file);
      final start = RegExp(
        r'^## Dependencies$',
        multiLine: true,
      ).firstMatch(prose);
      if (start == null) return '';
      var rest = prose.substring(start.end);
      final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
      if (next != null) rest = rest.substring(0, next.start);

      final bullets = <String>[];
      var started = false;
      for (final line in rest.split('\n')) {
        if (line.startsWith('- ')) {
          started = true;
        } else if (started &&
            !line.startsWith('  ') &&
            line.trim().isNotEmpty) {
          break; // the list ended and prose began
        }
        if (started) bullets.add(line);
      }
      return bullets.join('\n');
    }

    test('every type a module names as a dependency is one it actually refers '
        'to', () {
      // A Dependencies section is the one part of a module document that
      // describes the *code* rather than the behaviour, so it goes stale in a
      // way prose does not: delete the code that used a type and the line
      // naming it survives, still telling the reader to go and install it. That
      // is what happened here (tcinc668) — `doc/resources.md` kept listing
      // `TomTextResourceProvider` after the translation lookup that used it was
      // removed, and because the text and config providers are separate
      // families with separate installation calls, a reader who followed it
      // installed the wrong one and found that no property resolved.
      //
      // The check is deliberately weak: *referred to somewhere in the module*,
      // dartdoc included, not "used in code". A dependency is legitimately
      // indirect — `configuration` names `TomException` as the base its
      // exceptions inherit, `preferences` names `TomBearerAuthentication` for a
      // token its channel attaches and `TomRuntime` for the platform its bean
      // locator selects on. None appears in an expression; all three are real,
      // and a stricter check would report correct documentation as broken. What
      // no genuine dependency does is go entirely unmentioned, in code and in
      // prose alike — which is exactly what a line left behind by deleted code
      // looks like.
      final unrelated = <String>[];
      var checked = 0;
      for (final file in markdownFiles()) {
        if (p.dirname(file) != 'doc') continue;
        final module = p.join(
          'lib',
          'src',
          'tomclient',
          p.basenameWithoutExtension(file),
        );
        if (!Directory(module).existsSync()) continue;
        final bullets = dependencyBulletsOf(file);
        if (bullets.isEmpty) continue;
        checked++;

        final source = Directory(module)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.readAsStringSync())
            .join('\n');

        final named = <String>{};
        for (final span in inlineCode.allMatches(bullets)) {
          named.addAll(frameworkSymbol.allMatches(span[0]!).map((m) => m[0]!));
        }
        for (final symbol in named) {
          if (!source.contains(symbol.replaceFirst('@', ''))) {
            unrelated.add('$file: names `$symbol`, absent from $module/');
          }
        }
      }
      expect(
        unrelated,
        isEmpty,
        reason:
            'These documents list a dependency the module has no '
            'relationship with, so a reader who acts on the line acts on '
            'nothing:\n${unrelated.join('\n')}',
      );
      // Vacuous if the walk stops finding module documents or their sections.
      expect(checked, greaterThanOrEqualTo(7));
    });
  });
}
