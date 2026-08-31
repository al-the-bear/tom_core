// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the verbatim code snippet and the rendered child.
//
// The whole point of the showcase over `tom_flutter_ui_test` is that the
// source that produced a widget is displayed beside the widget. These tests
// make that contract enforceable: an empty snippet, a cell that silently drops
// its child, or a snippet naming something that exists nowhere, fails here.

import 'dart:io';

import 'package:core_flutter_ui_showcase/common/showcase_cell.dart';
import 'package:core_flutter_ui_showcase/showcase_app.dart';
import 'package:core_flutter_ui_showcase/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Cell snippets are the only double-quoted literals in `lib/groups/` —
/// everything else is single-quoted, per the lint. That is what lets the two
/// halves of a group file be separated as text.
final _doubleQuoted = RegExp(r'"((?:[^"\\]|\\.)*)"');
final _lineComment = RegExp(r'//[^\n]*');
final _singleQuoted = RegExp(r"'(?:[^'\\]|\\.)*'");
final _escape = RegExp(r'\\.');
final _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// Dart keywords and literals: they are syntax, not references to a
/// declaration, so a snippet may use them without the child doing so.
const _syntax = {
  'const', 'final', 'var', 'new', 'return', 'true', 'false', 'null', 'this'
};

/// The snippets in [source] — the text a reader copies out of the running app.
/// Escape sequences are dropped rather than decoded: `\n` is a line break in
/// the rendered snippet, not a reference to something called `n`.
String _snippetText(String source) => _doubleQuoted
    .allMatches(source)
    .map((m) => m.group(1)!.replaceAll(_escape, ' '))
    .join('\n');

/// [source] with the snippets and comments removed: what the cells actually
/// run, plus the file's own declarations.
String _childText(String source) =>
    source.replaceAll(_doubleQuoted, '""').replaceAll(_lineComment, '');

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  testWidgets('renders both the code snippet and the live child',
      (tester) async {
    const marker = Key('cell-child-marker');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShowcaseCell(
              title: 'Demo',
              code: 'TomElevatedButton(label: "Go")',
              child: SizedBox(key: marker, width: 24, height: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The rendered child is present.
    expect(find.byKey(marker), findsOneWidget);
    // The code snippet text is present (SelectableText inside CodeBlock).
    expect(
      find.textContaining('TomElevatedButton(label: "Go")'),
      findsOneWidget,
    );
    // The title is present.
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('every showcase cell carries a non-empty snippet',
      (tester) async {
    // Some group builders read `Theme.of(context)` eagerly, so we need a real
    // BuildContext from a pumped MaterialApp rather than a fake.
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    for (final group in showcaseGroups) {
      for (final cell in group.cells(capturedContext)) {
        expect(cell.code.trim(), isNotEmpty,
            reason: 'group ${group.id}: a cell has an empty code snippet');
      }
    }
  });

  // The other half of "verbatim", and the half proofreading kept missing: a
  // snippet may only name things that exist. Placeholder stand-ins (`boxA`,
  // `chipA`) and leaked locals (`scheme`, which lived in showcase_cell.dart,
  // not in the cell's own file) both read as real code and neither compiles
  // for a reader who copies it. Every identifier a snippet uses must therefore
  // also appear in its group file's non-snippet source — the cells' children,
  // that file's helpers, and its imports' names. That granularity is
  // deliberate: it accommodates `toggles_sliders_group.dart`, whose snippets
  // legitimately name `_on`/`_checked`/`_value` from the stateful demo
  // wrappers declared beside them.
  test('a snippet only names identifiers that exist in its group file', () {
    final files = Directory('lib/groups')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    var identifiersChecked = 0;

    for (final file in files) {
      final source = file.readAsStringSync();
      final defined =
          _identifier.allMatches(_childText(source)).map((m) => m[0]!).toSet();

      // Strings *inside* a snippet are data (labels, ids), not references.
      final snippet = _snippetText(source).replaceAll(_singleQuoted, "''");

      for (final match in _identifier.allMatches(snippet)) {
        final name = match[0]!;
        if (_syntax.contains(name)) continue;
        identifiersChecked++;
        expect(defined, contains(name),
            reason: '${file.path}: the snippet names `$name`, which appears '
                'nowhere in the file that renders it — a reader copying the '
                'snippet gets code that does not compile');
      }
    }

    // Guard against the rule silently matching nothing: every group file must
    // have been read, and each must have contributed snippet identifiers.
    expect(files.length, equals(showcaseGroups.length));
    expect(identifiersChecked, greaterThan(10 * files.length));
  });
}
