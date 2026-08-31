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

  // The third failure mode, and the one naming identifiers cannot see: a
  // snippet that compiles, names only real things, and *still* renders
  // differently from the preview beside it, because it drops what the child
  // passes. A `TomColumn` without `mainAxisSize: MainAxisSize.min` takes the
  // full height; a `TomLinearProgressIndicator` without the `TomSizedBox`
  // around it spans its whole parent. Both read as complete code.
  //
  // A snippet stays free to *abstract* — `toggles_sliders_group.dart` stands in
  // for a whole StatefulWidget with `_value` and `setState`. What it may not do
  // is quote a construct and then under-configure it, so every rule below fires
  // only where the snippet actually quotes the construct.
  test('a snippet quoting a construct shows its whole configuration', () {
    final groups = Directory('lib/groups');
    expect(groups.existsSync(), isTrue,
        reason: 'tests must run from the package root');

    var sizingChecked = 0;
    var ctorsChecked = 0;
    var aclChecked = 0;

    for (final file in groups
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final snippet = _snippetText(source);
      final child = _childText(source);
      final name = file.uri.pathSegments.last;

      // A `TomSizedBox` in a group file is never decoration — it is there
      // because the widget inside has no intrinsic extent. Dropping it is the
      // one omission that changes the rendering without changing a single
      // argument, so it cannot be caught by comparing argument lists.
      if (child.contains('TomSizedBox(')) {
        sizingChecked++;
        expect(snippet, contains('TomSizedBox('),
            reason: '$name: the child constrains a widget with TomSizedBox but '
                'no snippet shows it — a reader copying the snippet gets an '
                'unconstrained widget, not the one previewed');
      }

      // For every Tom widget a snippet quotes, the arguments the child passes
      // directly to that widget must all appear. Depth one only: what a nested
      // widget is given is that widget's own rule to answer.
      for (final ctor in _tomConstructors(snippet)) {
        ctorsChecked++;
        final missing = _namedArguments(child, ctor)
            .difference(_namedArguments(snippet, ctor));
        expect(missing, isEmpty,
            reason: '$name: the snippet quotes $ctor but omits '
                '${missing.map((a) => "$a:").join(", ")}, which the child '
                'passes — the copied widget would render differently');
      }

      // The ACL engine configures through a fluent chain rather than
      // arguments, so the same rule needs the same shape as in
      // `core_flutter_acl_sample`: a dropped `.setPSize(200)` is invisible and
      // changes the layout.
      if (snippet.contains('AclBuilder(')) {
        aclChecked++;
        final missing = _builderCalls(child).difference(_builderCalls(snippet));
        expect(missing, isEmpty,
            reason: '$name: the snippet quotes AclBuilder but omits '
                '${missing.map((c) => ".$c()").join(", ")}, which the child '
                'calls — the copied layout would render differently');
      }
    }

    // Guard against the rules silently matching nothing, which would let the
    // test pass while checking no cell at all.
    expect(sizingChecked, greaterThanOrEqualTo(3));
    expect(ctorsChecked, greaterThanOrEqualTo(20));
    expect(aclChecked, greaterThanOrEqualTo(1));
  });
}

final _tomConstructor = RegExp(r'\b(Tom[A-Za-z0-9]*)\s*\(');
final _builderCall =
    RegExp(r'\.(append|setPSize|setMinSize|setMaxSize|setAcl[A-Za-z0-9]*)\s*\(');
final _namedArgument = RegExp(r'\b(\w+)\s*:');

/// The Tom widget constructors invoked in [source].
Set<String> _tomConstructors(String source) =>
    _tomConstructor.allMatches(source).map((m) => m.group(1)!).toSet();

/// The fluent configuration calls made on an `AclBuilder` chain in [source].
Set<String> _builderCalls(String source) =>
    _builderCall.allMatches(source).map((m) => m.group(1)!).toSet();

/// The names of the arguments passed *directly* to [constructor] in [source],
/// unioned over every call to it. Arguments of nested widgets belong to that
/// widget's own call, so only depth one counts.
Set<String> _namedArguments(String source, String constructor) {
  final names = <String>{};
  final opener = RegExp('\\b$constructor\\s*(?:<[^>]*>\\s*)?\\(');
  for (final match in opener.allMatches(source)) {
    final args = StringBuffer();
    var depth = 0;
    for (var i = match.end - 1; i < source.length; i++) {
      final char = source[i];
      if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']' || char == '}') {
        depth--;
        if (depth == 0) break;
      }
      if (depth == 1) args.write(char);
    }
    names.addAll(_namedArgument.allMatches(args.toString()).map((m) => m[1]!));
  }
  return names;
}
