// Cell-contract tests: a [ShowcaseCell] always shows BOTH halves of the
// teaching pair — the verbatim code snippet and the rendered child.
//
// The whole point of this sample over `tom_flutter_ui_test/lib/acl_demos/` is
// that the source that produced an ACL layout is displayed beside the layout.
// These tests make that contract enforceable: an empty snippet, or a cell that
// silently drops its child, fails here.

import 'package:core_flutter_acl_sample/acl_app.dart';
import 'package:core_flutter_acl_sample/common/showcase_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
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
              code: 'AclBuilder().append(box).build()',
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
      find.textContaining('AclBuilder().append(box).build()'),
      findsOneWidget,
    );
    // The title is present.
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('every ACL cell carries a non-empty snippet', (tester) async {
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

    for (final group in aclGroups) {
      for (final cell in group.cells(capturedContext)) {
        expect(cell.code.trim(), isNotEmpty,
            reason: 'group ${group.id}: a cell has an empty code snippet');
      }
    }
  });
}
