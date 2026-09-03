// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — a curated code snippet and the rendered child.
//
// The contract has two halves and only one of them is machine-checkable. A
// snippet **may abridge**: it drops the `FormHost` scaffolding and width pins,
// elides repetition behind a `…` comment, and stands in for gallery-specific
// ids. Judging whether an abridgement is honest is an editorial call no test
// can make. A snippet **may not invent** — naming an API that does not exist —
// and that half is exactly checkable. These tests hold the checkable parts:
// both halves render, no group ships an empty snippet, no snippet names an API
// the sample never calls, and a snippet quoting a configurable construct shows
// that construct's whole configuration rather than a partial one.
//
// The remaining machine-checkable rule — that a snippet names the Tom widget
// the child actually builds — lives in `widget_convention_test.dart`, beside
// the source-level half of the same rule and the one vocabulary both share.

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

  testWidgets('renders both the code snippet and the live child', (
    tester,
  ) async {
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

  testWidgets('every showcase cell carries a non-empty snippet', (
    tester,
  ) async {
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
        expect(
          cell.code.trim(),
          isNotEmpty,
          reason: 'group ${group.id}: a cell has an empty code snippet',
        );
      }
    }
  });

  // The invention half of the contract. Its scope is the sample's whole `lib/`,
  // and that is the one place this sample's guard differs from the siblings':
  // there, a cell's `child` is built inline in `lib/groups/<id>_group.dart`, so
  // the group file *is* the thing the snippet illustrates. Here it is not. What
  // a forms cell teaches is a field *declaration* — `TomFormStringInput('name',
  // …, validators: [...])` — which lives in `lib/forms/company_form.dart`,
  // while the group file holds only the `FormHost` that mounts it. Scoping to
  // the group file would fail ~30 snippets that are entirely honest.
  //
  // Widening trades a little precision for the right question: a name must
  // exist *in this sample*, rather than in this file. The failure mode that
  // matters is untouched — an invented `form.buildColumn()` is nowhere in
  // `lib/`, so it still fails.
  testWidgets('no snippet names an API the sample never calls', (tester) async {
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

    // Why the stripping matters: the snippets are themselves string literals
    // inside `lib/groups/`, so searching the raw text would find every name in
    // its own snippet and pass unconditionally. Generated reflection output is
    // excluded — it is the generator's, not the sample's, and it names far more
    // than the sample writes.
    final live = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.reflection.dart'))
        .map((f) => _executableSource(f.readAsStringSync()))
        .join('\n');
    expect(live, isNotEmpty, reason: 'tests must run from the package root');

    for (final group in showcaseGroups) {
      for (final cell in group.cells(capturedContext)) {
        for (final name in _calledNames(cell.code)) {
          expect(
            live,
            contains(RegExp('\\b${RegExp.escape(name)}\\s*\\(')),
            reason:
                'group ${group.id}, cell "${cell.title}": the snippet '
                'calls `$name(...)`, which nothing in lib/ calls. A snippet '
                'may abridge the live child, but it may not name an API that '
                'does not exist. If the name is a private helper of the '
                'sample, spell it with its underscore — `_MasterPane`, not '
                '`MasterPane` — so a reader does not go looking for it in '
                'tom_flutter_ui.',
          );
        }
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
    expect(
      groups.existsSync(),
      isTrue,
      reason: 'tests must run from the package root',
    );

    var aclChecked = 0;
    var scaffoldChecked = 0;

    for (final file in groups.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    )) {
      final source = file.readAsStringSync();
      final snippet = _snippetText(source);
      final child = _childText(source);
      final name = file.uri.pathSegments.last;

      if (snippet.contains('TomAclBuilder(')) {
        aclChecked++;
        final missing = _builderCalls(child).difference(_builderCalls(snippet));
        expect(
          missing,
          isEmpty,
          reason:
              '$name: the snippet quotes TomAclBuilder but omits '
              '${missing.map((c) => ".$c()").join(", ")}, which the child '
              'calls — the copied layout would render differently',
        );
      }

      for (final ctor in const [
        'TomMasterDetailListForm',
        'TomInlineListForm',
      ]) {
        if (!snippet.contains(ctor)) continue;
        scaffoldChecked++;
        final missing = _flagArguments(
          child,
          ctor,
        ).difference(_flagArguments(snippet, ctor));
        expect(
          missing,
          isEmpty,
          reason:
              '$name: the snippet quotes $ctor but omits '
              '${missing.join(", ")}, which the child passes',
        );
      }
    }

    // Guard against the rules silently matching nothing, which would let the
    // test pass while checking no cell at all.
    expect(aclChecked, greaterThanOrEqualTo(2));
    expect(scaffoldChecked, greaterThanOrEqualTo(2));
  });
}

/// A library file reduced to the code that actually runs: comments and string
/// literals removed, everything else left in place.
///
/// This is what makes the invention check non-circular. A cell's snippet is a
/// string literal *inside `lib/groups/`*, so searching the raw sources for a
/// name the snippet uses always succeeds — including for a name the snippet
/// invented. Dropping the literals leaves only live code, which is the thing
/// the snippet claims to illustrate. Comments go first and in the same pass, so
/// an apostrophe in prose ("the cell's width") cannot open a phantom string and
/// swallow the rest of the file.
String _executableSource(String dart) {
  final out = StringBuffer();
  var i = 0;
  while (i < dart.length) {
    final c = dart[i];
    final next = i + 1 < dart.length ? dart[i + 1] : '';

    if (c == '/' && next == '/') {
      while (i < dart.length && dart[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < dart.length && !(dart[i] == '*' && dart[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == '"' || c == "'") {
      final triple = dart.startsWith(c * 3, i);
      final close = triple ? c * 3 : c;
      i += close.length;
      while (i < dart.length && !dart.startsWith(close, i)) {
        i += dart[i] == r'\' ? 2 : 1;
      }
      i += close.length;
      // Emit a separator so `a'x'b` cannot fuse into the identifier `ab`.
      out.write(' ');
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Every identifier a snippet invokes — the `foo` of any `foo(`.
///
/// Two kinds of text are removed before looking, and both are load-bearing.
/// Comments go so an elision marker (`// …validators / style overrides…`)
/// cannot smuggle a name past the reader's eye and into the check. **String
/// literals go because a snippet's strings are data — labels, ids — not
/// references**, and a label that happens to end in a word before a bracket
/// reads exactly like a call.
///
/// Language keywords that can legally precede `(` are dropped too: they are
/// Dart syntax, not API surface, and a snippet is free to use control flow the
/// live child spells differently.
Set<String> _calledNames(String code) {
  var withoutComments = code
      .split('\n')
      .map((line) {
        final marker = line.indexOf('//');
        return marker == -1 ? line : line.substring(0, marker);
      })
      .join('\n');
  withoutComments = withoutComments
      .replaceAll(RegExp(r"'(?:[^'\\]|\\.)*'"), "''")
      .replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '""');

  const keywords = {
    'if',
    'for',
    'while',
    'switch',
    'return',
    'catch',
    'assert',
    'super',
    'this',
    'new',
    'await',
    'in',
    'is',
    'as',
    'else',
    'do',
    'throw',
    'yield',
  };

  return RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)\s*\(')
      .allMatches(withoutComments)
      .map((m) => m.group(1)!)
      .where((name) => !keywords.contains(name))
      .toSet();
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
