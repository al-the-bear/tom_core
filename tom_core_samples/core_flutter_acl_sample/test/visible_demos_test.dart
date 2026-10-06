// The visibility audit in `visible_demos.dart` must fail on the defect it
// exists for. A check that only ever passes against the real groups cannot be
// told apart from one that stopped measuring, so each case below collapses a
// demo on purpose and requires the audit to name it.

import 'package:core_flutter_acl_sample/common/chrome_texts.dart';
import 'package:core_flutter_acl_sample/common/showcase_cell.dart';
import 'package:core_flutter_acl_sample/common/showcase_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'visible_demos.dart';

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  Future<void> pumpCell(WidgetTester tester, Widget demo) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final group = ShowcaseGroup(
      id: 'probe',
      title: 'Probe',
      summary: 'One cell under test.',
      icon: Icons.science,
      cells: (_) => [ShowcaseCell(title: 'Probe cell', code: 'x', child: demo)],
    );
    await tester.pumpWidget(MaterialApp(home: GroupScreen(group: group)));
    await tester.pump();
  }

  testWidgets('VD-1: a visible demo passes and its labels are measured', (
    tester,
  ) async {
    await pumpCell(
      tester,
      const SizedBox(width: 120, height: 40, child: Text('shown')),
    );

    final audit = auditDemos();
    expect(audit.faults, isEmpty);
    expect(audit.demosMeasured, 1);
    expect(audit.labelsMeasured, 1);
  });

  testWidgets('VD-2: a demo laid out with no height is reported', (
    tester,
  ) async {
    await pumpCell(
      tester,
      const SizedBox(width: 120, height: 0, child: Text('gone')),
    );

    expect(auditDemos().faults, [contains('"Probe cell": the demo is')]);
  });

  testWidgets(
    'VD-3: one squashed box beside a full-height neighbour is reported',
    (tester) async {
      // The shape that went unnoticed: the row keeps its neighbour's height,
      // so the demo as a whole still has area and only the box is gone.
      await pumpCell(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, height: 0, child: Text('max 160')),
            SizedBox(width: 80, height: 40, child: Text('grows')),
          ],
        ),
      );

      expect(auditDemos().faults, [
        contains('"Probe cell": label "max 160" is'),
      ]);
    },
  );
}
