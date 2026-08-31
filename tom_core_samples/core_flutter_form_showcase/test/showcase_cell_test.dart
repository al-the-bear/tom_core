// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the verbatim code snippet and the rendered child — and no
// group ships a cell with an empty snippet.
//
// The whole point of the showcase is that the source that produced a live form
// is displayed beside it; these tests make that contract enforceable.

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

  testWidgets('no snippet teaches a raw Flutter widget over its Tom equivalent',
      (tester) async {
    // The sample lays out exclusively with Tom* widgets (G-UI-1), and every
    // snippet is advertised as verbatim — so a snippet naming `Row` or
    // `Expanded` is wrong twice: it does not match the child it claims to
    // reproduce, and a reader who copies it is taught the very thing the
    // surrounding code avoids.
    //
    // Non-emptiness was previously the only gated part of the snippet
    // contract; matching the child stayed a review obligation. This closes the
    // half of that gap a machine can actually check.
    final rawWidget = RegExp(
      r'(?<![A-Za-z0-9_$.])'
      r'(Row|Column|Expanded|Flexible|SizedBox|Padding|Card|Divider|InkWell'
      r'|ListView|ListTile|Wrap|SingleChildScrollView|Stack|Positioned'
      r'|DecoratedBox|Chip|Text|Icon|IconButton|SelectableText'
      r'|ElevatedButton|FilledButton|OutlinedButton|TextButton)'
      r'\s*\(',
    );

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
        final hits =
            rawWidget.allMatches(cell.code).map((m) => m.group(1)).toSet();
        expect(hits, isEmpty,
            reason: 'group "${group.id}", cell "${cell.title}": snippet uses '
                'raw Flutter ${hits.join(", ")} instead of the Tom '
                'equivalent(s)');
      }
    }
  });
}
