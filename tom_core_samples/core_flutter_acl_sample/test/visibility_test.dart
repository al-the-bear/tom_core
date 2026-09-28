// The group-visibility cell is the sample's one interactive cell and the only
// place its state changes: a switch drives an `AclBinaryVisibilityController`
// that shows or hides the builder's named `details` group. The smoke test
// builds it; this suite operates it, so a regression that left the group
// permanently shown - or hid the summary row with it - fails here.

import 'package:core_flutter_acl_sample/common/chrome_texts.dart';
import 'package:core_flutter_acl_sample/common/showcase_section.dart';
import 'package:core_flutter_acl_sample/groups/visibility_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  testWidgets('the switch hides and reveals the details group, and only it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: visibilityGroup)),
    );
    await tester.pump();

    // Starts visible, with the switch reading on.
    expect(find.text('Show details'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Detail A'), findsOneWidget);
    expect(find.text('Detail B'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Detail A'), findsNothing);
    expect(find.text('Detail B'), findsNothing);
    expect(
      find.text('Summary (always shown)'),
      findsOneWidget,
      reason: 'the ungrouped row does not react',
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Detail A'), findsOneWidget);
    expect(find.text('Detail B'), findsOneWidget);
  });
}
