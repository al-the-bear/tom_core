import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards the markdown links this package ships.
///
/// A link can fail in two ways, and only the first is obvious. It can point at
/// nothing — a path that does not resolve — or it can resolve cleanly onto the
/// *wrong* document. The second kind survives every path check ever written,
/// so it is checked separately here: when a link's label is a single code-span
/// identifier, the reader is being told "follow this to read about `X`", and
/// the guard holds the target to that promise by requiring it to mention `X`.
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
}
