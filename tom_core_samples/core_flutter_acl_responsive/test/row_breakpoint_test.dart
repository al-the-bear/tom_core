// Row breakpoints: `addRowBreakpoint(atWidth: 400)` keeps two fields on one row
// above 400px and stacks them below it. The outcome is geometric, so it is
// asserted as geometry - the fields' tops - either side of the threshold.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/groups/row_breakpoint_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
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

  testWidgets('above 400px the two fields share one row', (tester) async {
    await pumpGroup(tester, rowBreakpointGroup);
    final cell = cellTitled('Wide (520px)');
    final industry = textRect(tester, cell, 'Industry');
    final taxId = textRect(tester, cell, 'Tax ID');
    expect(taxId.top, industry.top, reason: 'same row, same top');
    expect(taxId.left, greaterThan(industry.right), reason: 'side by side');
  });

  testWidgets('below 400px the same row stacks', (tester) async {
    await pumpGroup(tester, rowBreakpointGroup);
    final cell = cellTitled('Narrow (320px)');
    final industry = textRect(tester, cell, 'Industry');
    final taxId = textRect(tester, cell, 'Tax ID');
    expect(taxId.top, greaterThan(industry.bottom), reason: 'stacked below');
  });
}
