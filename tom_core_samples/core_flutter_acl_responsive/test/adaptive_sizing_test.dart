// Adaptive sizing: a cell with min 80 / preferred 160 / max 240 beside an
// `expandX` cell. The outcome is the width each cell resolves to, measured
// either side of the point where the row can no longer give the sized cell its
// preferred width.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/groups/adaptive_sizing_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'group_harness.dart';

const _sized = 'min 80 / pref 160 / max 240';
const _expanding = 'expandX — soaks up the rest';

void main() {
  setUpAll(initializeReflection);
  setUp(
    () => TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    ),
  );

  testWidgets('at 600px the sized cell sits at its preferred 160px and expandX '
      'takes the rest', (tester) async {
    await pumpGroup(tester, adaptiveSizingGroup);
    final cell = cellTitled('Wide (600px)');
    expect(boxWidth(tester, cell, _sized), 160);
    expect(boxWidth(tester, cell, _expanding), greaterThan(160));
  });

  testWidgets(
    'at 320px the sized cell gives up width but stays within its band, '
    'and expandX absorbs most of the shortfall',
    (tester) async {
      await pumpGroup(tester, adaptiveSizingGroup);
      final wide = cellTitled('Wide (600px)');
      final narrow = cellTitled('Narrow (320px)');

      final sized = boxWidth(tester, narrow, _sized);
      expect(sized, lessThan(160), reason: 'below its preferred width');
      expect(
        sized,
        greaterThanOrEqualTo(80),
        reason: 'never below its minimum',
      );

      final sizedLoss = boxWidth(tester, wide, _sized) - sized;
      final expandingLoss =
          boxWidth(tester, wide, _expanding) -
          boxWidth(tester, narrow, _expanding);
      expect(expandingLoss, greaterThan(sizedLoss));
    },
  );
}
