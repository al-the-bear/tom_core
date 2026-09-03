// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the curated code snippet and the rendered child — and every
// responsive group honours the snippet contract documented on
// [ShowcaseCell.code] and in README section 15.
//
// That contract has two halves, and only one of them is machine-checkable:
//
//  - A snippet **may abridge**. It drops the gallery harness (width pins,
//    FormHost scaffolding, badge rows), elides repetition behind a `…` comment,
//    and substitutes short stand-ins for gallery-specific ids. Judging an
//    abridgement is an editorial call, so no test tries.
//  - A snippet **may not invent**. Naming a constructor or method that does not
//    exist is the one failure a reader cannot recover from, because that is the
//    half they lean on when they lift a line into their own project. That half
//    *is* checkable, and the last test below checks it.

import 'dart:io';

import 'package:core_flutter_acl_responsive/common/showcase_cell.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/showcase_app.dart';
import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
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
    // A wide viewport so the cell uses its side-by-side regime.
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const marker = Key('cell-child-marker');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShowcaseCell(
              title: 'Demo',
              code: 'AclBuilder().append(demoBox("x", Colors.teal)).build()',
              child: SizedBox(key: marker, width: 24, height: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(marker), findsOneWidget);
    expect(
      find.textContaining(
        'AclBuilder().append(demoBox("x", Colors.teal)).build()',
      ),
      findsOneWidget,
    );
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('every responsive cell carries a non-empty snippet', (
    tester,
  ) async {
    // Group builders read Theme.of(context) / MediaQuery, so a real pumped
    // context is needed rather than a fake one.
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

    for (final group in responsiveGroups) {
      for (final cell in group.cells(capturedContext)) {
        expect(
          cell.code.trim(),
          isNotEmpty,
          reason: 'group ${group.id}: a cell has an empty code snippet',
        );
      }
    }
  });

  testWidgets('no snippet names an API absent from its own group source', (
    tester,
  ) async {
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

    for (final group in responsiveGroups) {
      // The group id doubles as the file name (README section 15, step 1); a
      // group whose file is renamed away from that mapping must fail loudly
      // rather than silently skip its snippets.
      final file = File('lib/groups/${group.id}_group.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'group ${group.id}: expected its source at ${file.path} — '
            'the snippet check reads the live child from there',
      );
      // Why the stripping matters: the snippets are themselves string literals
      // in this very file, so searching the raw text would find every name in
      // its own snippet and pass unconditionally.
      final live = _executableSource(file.readAsStringSync());

      for (final cell in group.cells(capturedContext)) {
        for (final name in _calledNames(cell.code)) {
          expect(
            live,
            contains(RegExp('\\b${RegExp.escape(name)}\\s*\\(')),
            reason:
                'group ${group.id}, cell "${cell.title}": the snippet '
                'calls `$name(...)`, which is never called by the live code '
                'in ${file.path}. A snippet may abridge the live child, but '
                'it may not name an API that does not exist. If the call is '
                'genuine but reached indirectly, make the snippet say so — '
                'that is a real gap between what is shown and what runs.',
          );
        }
      }
    }
  });
}

/// A group file reduced to the code that actually runs: comments and string
/// literals removed, everything else left in place.
///
/// This is what makes the check non-circular. A cell's snippet is a string
/// literal *inside the group file it describes*, so searching the raw file for
/// a name the snippet uses always succeeds — including for a name the snippet
/// invented. Dropping the literals leaves only the live `child` and its
/// helpers, which is the thing the snippet claims to illustrate. Comments go
/// first and in the same pass, so an apostrophe in prose ("the cell's width")
/// cannot open a phantom string and swallow the rest of the file.
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
/// Comments go so an elision marker (`// …gaps / errorIcon overrides…`) cannot
/// smuggle a name past the reader's eye and into the check. **String literals go
/// because a snippet's strings are data — labels, ids — not references**, and a
/// label that happens to end in a word before a bracket reads exactly like a
/// call: `demoBox('Anchor field (wide)', …)` would otherwise be reported as
/// calling a non-existent `field(...)`.
///
/// Language keywords that can legally precede `(` are dropped too: they are Dart
/// syntax, not API surface, and a snippet is free to use control flow the live
/// child spells differently.
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
