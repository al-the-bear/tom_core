/// Adaptive sizing — preferred / min / max widths that reflow across widths.
///
/// Per-component sizing pins each cell's elastic range: `setMSize` is the floor
/// it shrinks to, `setPSize` the preferred width it targets, `setXSize` the
/// ceiling it grows to, and `expandX()` lets a cell soak up the leftover row
/// space. As the container narrows, cells shrink toward their min before the row
/// reflows. Each cell pins a width to show the two regimes side by side.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

Widget _sizingLayout(double width) {
  return SizedBox(
    width: width,
    child: AclBuilder()
        .append(demoBox('min 80 / pref 160 / max 240', Colors.teal))
        .setMSize(80)
        .setPSize(160)
        .setXSize(240)
        .append(demoBox('expandX — soaks up the rest', Colors.orange), dist: 12)
        .expandX()
        .build(),
  );
}

/// The adaptive-sizing mechanism group.
final ShowcaseGroup adaptiveSizingGroup = ShowcaseGroup(
  id: 'adaptive_sizing',
  title: 'Adaptive sizing',
  summary: 'setMSize/setPSize/setXSize give a cell an elastic min/preferred/max '
      'range; expandX soaks up leftover row space. Cells shrink toward their '
      'min as the row narrows.',
  icon: Icons.open_in_full_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Wide (600px) — preferred widths honoured',
      note: 'At 600px the first cell sits near its 160px preferred width and '
          'the second cell expands to fill the rest.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('sized', Colors.teal))\n"
          '    .setMSize(80).setPSize(160).setXSize(240)\n'
          "    .append(demoBox('expandX', Colors.orange), dist: 12)\n"
          '    .expandX()\n'
          '    .build()',
      child: _sizingLayout(600),
    ),
    ShowcaseCell(
      title: 'Narrow (320px) — sized cell shrinks toward min',
      note: 'At 320px the first cell shrinks toward its 80px floor before the '
          'row would reflow; expandX still claims the remainder.',
      code: '// Same chain — only the available width differs.\n'
          'SizedBox(width: 320, child: sizingLayout)',
      child: _sizingLayout(320),
    ),
  ],
);
