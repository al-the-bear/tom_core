// The capstone: one TomAclBuilder chain under a TomFormStyleScope, where the
// same width moves BOTH axes - `addRowBreakpoint(atWidth: 480)` on the layout
// axis, the `*BpOverrides` label placement (floating < 400 <= above < 700 <=
// inline) and label size on the style axis. Each is asserted either side of its
// threshold, from the rendered tree.
//
// Label placement is read structurally: a floating label is drawn inside the
// field's InputDecorator; an `above` label is a separate Text outside it.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/groups/responsive_acl_form_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'group_harness.dart';

void main() {
  setUpAll(initializeReflection);
  setUp(
    () => TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    ),
  );

  /// The label Text for [label] inside [cell] - `Industry`, or `Industry *`
  /// when a floating label carries the required marker inline.
  Finder labelIn(Finder cell, String label) => find.descendant(
    of: cell,
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data == label || w.data == '$label *'),
    ),
  );

  bool insideDecorator(Finder label) => find
      .ancestor(of: label, matching: find.byType(InputDecorator))
      .evaluate()
      .isNotEmpty;

  testWidgets('640px: the row is shared and labels sit above at 13px', (
    tester,
  ) async {
    await pumpGroup(tester, responsiveAclFormGroup);
    final cell = cellTitled('Wide (640px)');

    // Layout axis: 640 >= 480, so industry and taxId share one row.
    final industry = tester.getRect(labelIn(cell, 'Industry'));
    final taxId = tester.getRect(labelIn(cell, 'Tax ID'));
    expect(taxId.top, industry.top);

    // Style axis: 400 <= 640 < 700 is the `above` tier - outside the
    // decorator, 13px. Not `inline`, which needs 700.
    final label = labelIn(cell, 'Industry');
    expect(insideDecorator(label), isFalse);
    expect(tester.widget<Text>(label).style?.fontSize, 13);
  });

  testWidgets('360px: the row stacks and labels float inside the field', (
    tester,
  ) async {
    await pumpGroup(tester, responsiveAclFormGroup);
    final cell = cellTitled('Narrow (360px)');

    final industry = tester.getRect(labelIn(cell, 'Industry'));
    final taxId = tester.getRect(labelIn(cell, 'Tax ID'));
    expect(taxId.top, greaterThan(industry.bottom));

    expect(insideDecorator(labelIn(cell, 'Industry')), isTrue);
  });
}
