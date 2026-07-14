// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the verbatim code snippet and the rendered child — and no
// responsive group ships a cell with an empty snippet.
//
// The whole point of the showcase is that the source that produced a live,
// width-reactive layout is displayed beside it; these tests make that contract
// enforceable across every group.

import 'package:core_flutter_acl_responsive/common/showcase_cell.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/showcase_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  testWidgets('renders both the code snippet and the live child',
      (tester) async {
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
              code: 'AclBuilder().append(demoBox("x", teal)).build()',
              child: SizedBox(key: marker, width: 24, height: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(marker), findsOneWidget);
    expect(
      find.textContaining('AclBuilder().append(demoBox("x", teal)).build()'),
      findsOneWidget,
    );
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('every responsive cell carries a non-empty snippet',
      (tester) async {
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
        expect(cell.code.trim(), isNotEmpty,
            reason: 'group ${group.id}: a cell has an empty code snippet');
      }
    }
  });
}
