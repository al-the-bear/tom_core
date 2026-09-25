/// Holds `doc/demo_catalogue.md` and the README to the Demos tab as the app
/// renders it.
///
/// The Demos tab in `lib/main.dart` is the canonical grouping — it is what a
/// reader scrolls — and it has ten sections. The catalogue groups the same
/// demos under its own `###` headings, and the README counts both. Nothing
/// related the three, so the README could say "three sections" while the app
/// showed ten, and a demo could sit under one heading on screen and another in
/// the catalogue.
///
/// Read from source rather than by pumping `RootScreen`: the tab is a lazy
/// `ListView`, so a widget test would see only the tiles that fit on screen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One section of the Demos list: its heading and the ids of its demos, in
/// order (`A`, `H-A`, `1`, …).
typedef _Section = ({String heading, List<String> demos});

void main() {
  final app = _appSections(File('lib/main.dart').readAsStringSync());
  final catalogue = _catalogueSections(
    File('doc/demo_catalogue.md').readAsStringSync(),
  );

  test('the app renders ten sections over 33 demos', () {
    // Pins the parse as much as the app: a pattern that stopped matching would
    // otherwise make the comparisons below vacuously equal.
    expect(app, hasLength(10));
    expect(app.expand((s) => s.demos), hasLength(33));
  });

  test('the catalogue uses the same headings, in the same order', () {
    expect(
      catalogue.map((s) => s.heading).toList(),
      app.map((s) => s.heading).toList(),
    );
  });

  test('each demo sits under the same heading in both', () {
    expect(
      {for (final s in catalogue) s.heading: s.demos},
      {for (final s in app) s.heading: s.demos},
    );
  });

  test('the README states the counts the app shows', () {
    final readme = File('README.md').readAsStringSync();
    final demos = app.expand((s) => s.demos).length;
    expect(readme, contains('$demos demos in ${_words[app.length]} sections'));
  });
}

const _words = {10: 'ten'};

/// The Demos list of `RootScreen`: every `_DemoSectionHeader` label, and the
/// `Demo <id>:` tiles that follow it.
List<_Section> _appSections(String source) {
  final sections = <_Section>[];
  final token = RegExp(
    r"_DemoSectionHeader\(\s*label:\s*'([^']*)'|title:\s*'Demo ([^:]+):",
  );
  for (final m in token.allMatches(source)) {
    if (m.group(1) != null) {
      sections.add((heading: _unescape(m.group(1)!), demos: []));
    } else {
      sections.last.demos.add(m.group(2)!);
    }
  }
  return sections;
}

/// The `###` headings under the catalogue's `## Demos` part, and the demo ids
/// in the first column of each heading's table.
List<_Section> _catalogueSections(String markdown) {
  final start = markdown.indexOf('\n## Demos');
  final end = markdown.indexOf('\n## ', start + 1);
  final part = markdown.substring(start, end < 0 ? null : end);
  final sections = <_Section>[];
  for (final line in part.split('\n')) {
    if (line.startsWith('### ')) {
      sections.add((heading: line.substring(4).trim(), demos: []));
      continue;
    }
    final row = RegExp(r'^\| (\S+) — ').firstMatch(line);
    if (row != null && sections.isNotEmpty) {
      sections.last.demos.add(row.group(1)!);
    }
  }
  return sections;
}

/// A Dart string literal's `\uXXXX` escapes, decoded.
String _unescape(String literal) => literal.replaceAllMapped(
  RegExp(r'\\u([0-9a-fA-F]{4})'),
  (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
);
