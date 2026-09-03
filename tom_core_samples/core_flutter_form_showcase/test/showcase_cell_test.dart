// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the verbatim code snippet and the rendered child.
//
// The whole point of the showcase is that the source that produced a live form
// is displayed beside it, so these tests make that contract enforceable: both
// halves render, no group ships a cell with an empty snippet, and a snippet
// that quotes a configurable construct shows that construct's whole
// configuration rather than a partial one.
//
// The other machine-checkable part of "verbatim" — that a snippet names the Tom
// widget the child actually builds — lives in `widget_convention_test.dart`,
// beside the source-level half of the same rule and the one vocabulary both
// share.

import 'dart:io';

import 'package:core_flutter_form_showcase/common/showcase_cell.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:core_flutter_form_showcase/showcase_app.dart';
import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
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
              code: 'TomFormStringInput("name", "")',
              child: SizedBox(key: marker, width: 24, height: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(marker), findsOneWidget);
    expect(
      find.textContaining('TomFormStringInput("name", "")'),
      findsOneWidget,
    );
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('every showcase cell carries a non-empty snippet',
      (tester) async {
    // Group builders read Theme.of(context), so a real pumped context is
    // needed rather than a fake one.
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

  test('a snippet quoting a configurable construct shows its whole '
      'configuration', () {
    // The recurring snippet defect is not a wrong line, it is a *missing* one:
    // the child configures something and the snippet quietly leaves it out, so
    // a reader who copies the snippet gets different behaviour from the preview
    // it stands beside. Both `.setAclDefaultAppendGap(0)` (the builder default
    // is 8) and `draggableSplitter: true` (default false) are invisible when
    // dropped, and change what the copied code renders.
    //
    // A snippet is free to *abstract* — the theming cells stand in for the whole
    // layout with `formLayout`. What it may not do is name a construct and then
    // under-configure it. So each rule below applies only when the snippet
    // actually quotes the construct, which exempts a deliberate placeholder
    // automatically while binding anything that claims to show the real thing.
    final groups = Directory('lib/groups');
    expect(groups.existsSync(), isTrue,
        reason: 'tests must run from the package root');

    var aclChecked = 0;
    var scaffoldChecked = 0;

    for (final file in groups
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final snippet = _snippetText(source);
      final child = _childText(source);
      final name = file.uri.pathSegments.last;

      if (snippet.contains('TomAclBuilder(')) {
        aclChecked++;
        final missing = _builderCalls(child).difference(_builderCalls(snippet));
        expect(missing, isEmpty,
            reason: '$name: the snippet quotes TomAclBuilder but omits '
                '${missing.map((c) => ".$c()").join(", ")}, which the child '
                'calls — the copied layout would render differently');
      }

      for (final ctor in const [
        'TomMasterDetailListForm',
        'TomInlineListForm',
      ]) {
        if (!snippet.contains(ctor)) continue;
        scaffoldChecked++;
        final missing =
            _flagArguments(child, ctor).difference(_flagArguments(snippet, ctor));
        expect(missing, isEmpty,
            reason: '$name: the snippet quotes $ctor but omits '
                '${missing.join(", ")}, which the child passes');
      }
    }

    // Guard against the rules silently matching nothing, which would let the
    // test pass while checking no cell at all.
    expect(aclChecked, greaterThanOrEqualTo(2));
    expect(scaffoldChecked, greaterThanOrEqualTo(2));
  });
}

final _doubleQuoted = RegExp(r'"((?:[^"\\]|\\.)*)"');
final _lineComment = RegExp(r'//[^\n]*');
final _builderCall = RegExp(r'\.(setAcl[A-Za-z0-9]+|addRowBreakpoint)\s*\(');
final _flagArgument = RegExp(r'(\w+)\s*:\s*(true|false)\b');

/// The snippets in [source]. Cell snippets are the only double-quoted literals
/// in this package — everything else is single-quoted, per the lint.
String _snippetText(String source) =>
    _doubleQuoted.allMatches(source).map((m) => m.group(1)!).join('\n');

/// [source] with the snippets and comments removed: what the cells actually run.
///
/// Snippets go first, because a snippet may legitimately *contain* a `//`
/// comment (the lists cell quotes one) that must not be treated as source.
String _childText(String source) =>
    source.replaceAll(_doubleQuoted, '""').replaceAll(_lineComment, '');

/// The fluent configuration calls made on a `TomAclBuilder` chain in [source].
Set<String> _builderCalls(String source) =>
    _builderCall.allMatches(source).map((m) => m.group(1)!).toSet();

/// The boolean `name: value` arguments passed *directly* to [constructor] in
/// [source] — arguments of nested widgets are a different call's business, so
/// only depth one counts.
Set<String> _flagArguments(String source, String constructor) {
  final flags = <String>{};
  final opener = RegExp('$constructor\\s*(?:<[^>]*>\\s*)?\\(');
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
    for (final flag in _flagArgument.allMatches(args.toString())) {
      flags.add('${flag.group(1)}: ${flag.group(2)}');
    }
  }
  return flags;
}
