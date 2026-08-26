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
    return linkPattern.allMatches(text).where(
      (link) => !quoted.any((q) => q.start < link.start && link.start < q.end),
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
  /// Lower-cased, punctuation dropped, whitespace runs joined with hyphens.
  /// HTML entities are decoded first, because a heading that has to show a
  /// generic — `TomSetting&lt;T&gt;` — is anchored as the `<` and `>` it
  /// renders as, not as the letters of the escape. Skipping that step reports
  /// five live links in this package as dead.
  String anchorOf(String heading) {
    var text = heading.toLowerCase();
    for (final entity in const {'&lt;': '<', '&gt;': '>', '&amp;': '&'}.entries) {
      text = text.replaceAll(entity.key, entity.value);
    }
    text = text.replaceAll(RegExp(r'[^\w\s-]'), '');
    return text.trim().replaceAll(RegExp(r'\s+'), '-');
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
    final start = RegExp(r'^## Table of Contents$', multiLine: true)
        .firstMatch(prose);
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
        reason: 'These anchors name no heading in their own document, so they '
            'render as links that go nowhere:\n${dead.join('\n')}',
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
        reason: 'These contents blocks disagree with the sections they '
            'describe:\n${mismatched.join('\n')}',
      );
      // Pins that the walk still finds the documents — the check above is
      // vacuous if `checked` is zero.
      expect(checked, greaterThanOrEqualTo(7));
    });
  });
}
