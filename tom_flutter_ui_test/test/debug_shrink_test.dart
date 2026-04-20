/// Diagnostic: measure rendered widths in size_constraints panel 4
/// (mixed + expandX) at a range of viewport widths to understand the
/// shrink behaviour the user reported.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';

void main() {
  const capKey = ValueKey('cap');
  const uncapAKey = ValueKey('uncapA');
  const uncapBKey = ValueKey('uncapB');
  const expandKey = ValueKey('expand');

  Widget buildAcl() {
    return AclBuilder()
        .append(const KeyedSubtree(
            key: capKey,
            child: DemoBox('Cap', Colors.cyan)))
        .setMSize(80, 40)
        .setPSize(160, 40)
        .setXSize(260, 40)
        .append(const KeyedSubtree(
            key: uncapAKey,
            child: DemoBox('A', Colors.indigo)), dist: 6)
        .setMSize(60, 40)
        .setPSize(140, 40)
        .append(const KeyedSubtree(
            key: uncapBKey,
            child: DemoBox('B', Colors.orange)), dist: 6)
        .setMSize(50, 40)
        .setPSize(120, 40)
        .append(const KeyedSubtree(
            key: expandKey,
            child: DemoBox('ExpandX', Colors.lightGreen)), dist: 6)
        .setMSize(80, 40)
        .setPSize(200, 40)
        .setAttr(AclFlags.expandX)
        .build();
  }

  Future<void> measure(WidgetTester tester, double w) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: w,
          child: buildAcl(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final cap = tester.getRect(find.byKey(capKey));
    final a = tester.getRect(find.byKey(uncapAKey));
    final b = tester.getRect(find.byKey(uncapBKey));
    final e = tester.getRect(find.byKey(expandKey));
    // ignore: avoid_print
    print('width=$w  cap=${cap.width.toStringAsFixed(1)}  '
        'A=${a.width.toStringAsFixed(1)}  '
        'B=${b.width.toStringAsFixed(1)}  '
        'expand=${e.width.toStringAsFixed(1)}  '
        'total=${(cap.width + a.width + b.width + e.width + 18).toStringAsFixed(1)}');
  }

  testWidgets('size_constraints panel 4 shrink at multiple widths',
      (tester) async {
    for (final w in [800.0, 600.0, 500.0, 448.0, 400.0, 350.0, 300.0]) {
      await measure(tester, w);
    }
  });
}
