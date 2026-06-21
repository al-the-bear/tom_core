/// Sizing group — preferred / minimum / maximum component sizing.
///
/// The ACL engine sizes each component by three independent dimensions:
/// **preferred** (`setPSize`), **minimum** (`setMSize`) and **maximum**
/// (`setXSize`). A component starts at its preferred width, shrinks no smaller
/// than its minimum and grows no larger than its maximum as the row reflows.
/// Maps to the verified `all_dimensions_demo` / `size_constraints_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The sizing capability group.
final ShowcaseGroup sizingGroup = ShowcaseGroup(
  id: 'sizing',
  title: 'Sizing (preferred / min / max)',
  summary: 'setPSize, setMSize and setXSize size each component independently '
      'by preferred, minimum and maximum width.',
  icon: Icons.straighten_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Preferred width — setPSize',
      note: 'The first cell asks for a 200px preferred width; the remaining '
          'cells share the leftover space.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('200px preferred', teal))\n"
          '    .setPSize(200)\n'
          "    .append(demoBox('rest', orange))\n"
          "    .append(demoBox('rest', purple))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('200px preferred', Colors.teal))
          .setPSize(200)
          .append(demoBox('rest', Colors.orange))
          .append(demoBox('rest', Colors.purple))
          .build(),
    ),
    ShowcaseCell(
      title: 'Minimum width — setMSize',
      note: 'setMSize pins a floor: the cell never shrinks below 120px even as '
          'the row tightens.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('min 120', indigo))\n"
          '    .setMSize(120)\n'
          "    .append(demoBox('flex', cyan))\n"
          "    .append(demoBox('flex', green))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('min 120', Colors.indigo))
          .setMSize(120)
          .append(demoBox('flex', Colors.cyan))
          .append(demoBox('flex', Colors.green))
          .build(),
    ),
    ShowcaseCell(
      title: 'Maximum width — setXSize',
      note: 'setXSize caps growth: the cell stops widening at 160px and the '
          'surplus flows to its neighbours.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('max 160', deepPurple))\n"
          '    .setXSize(160)\n'
          "    .append(demoBox('grows', red))\n"
          '    .expandX()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('max 160', Colors.deepPurple))
          .setXSize(160)
          .append(demoBox('grows', Colors.red))
          .expandX()
          .build(),
    ),
    ShowcaseCell(
      title: 'All three together',
      note: 'A single cell with preferred 180 / min 100 / max 240 — the band it '
          'is free to occupy as the row reflows.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('P180 M100 X240', teal))\n"
          '    .setPSize(180)\n'
          '    .setMSize(100)\n'
          '    .setXSize(240)\n'
          "    .append(demoBox('neighbour', orange))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('P180 M100 X240', Colors.teal))
          .setPSize(180)
          .setMSize(100)
          .setXSize(240)
          .append(demoBox('neighbour', Colors.orange))
          .build(),
    ),
  ],
);
