// Four-state authorization contract: the `none` state is distinct from the
// three visible states, and the visible states each render their content.
//
// `none` collapses the gated widget to nothing, while
// `full`, `read` and `disabled` all keep the button on screen. (The pixel-level
// opacity distinction between `disabled` and `read` is asserted in
// tom_flutter_ui's own suite; here we assert the sample wires all four states
// through the ACL row without conflating any with `none`.)

import 'package:core_flutter_acl_sample/common/showcase_section.dart';
import 'package:core_flutter_acl_sample/groups/authorization_group.dart';
import 'package:core_flutter_acl_sample/common/chrome_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  Future<void> pumpAuthGroup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: authorizationGroup)),
    );
    await tester.pump();
  }

  testWidgets('all four state cells render their titles', (tester) async {
    await pumpAuthGroup(tester);
    expect(find.text('TomAuthState.full'), findsOneWidget);
    expect(find.text('TomAuthState.read'), findsOneWidget);
    expect(find.text('TomAuthState.disabled'), findsOneWidget);
    expect(find.text('TomAuthState.none'), findsOneWidget);
  });

  testWidgets('the gated button shows for full/read/disabled but not none', (
    tester,
  ) async {
    await pumpAuthGroup(tester);
    // The button label appears once per visible state (full, read, disabled),
    // and never for `none` — proving `none` collapses the widget while the
    // other three keep it on screen.
    final approveLabels = find.descendant(
      of: find.byType(TomElevatedButton),
      matching: find.text('Approve'),
    );
    expect(
      approveLabels,
      findsNWidgets(3),
      reason: 'full, read and disabled render the button; none hides it',
    );
  });

  testWidgets('every authorization cell carries a non-empty snippet', (
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
    for (final cell in authorizationGroup.cells(capturedContext)) {
      expect(
        cell.code.trim(),
        contains('TomAuthorizer.fixed'),
        reason: 'each authorization snippet must show the gating call',
      );
    }
  });
}
