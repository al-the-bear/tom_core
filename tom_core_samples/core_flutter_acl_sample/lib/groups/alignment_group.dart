/// Alignment group — horizontal and vertical row alignment.
///
/// `setRowAlignLeft/Center/Right` place a row's components along its main axis;
/// `setRowAlignTop/Middle/Bottom` align components of differing heights on the
/// cross axis. Maps to the verified `alignment_demo` /
/// `convenience_placement_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The alignment capability group.
final ShowcaseGroup alignmentGroup = ShowcaseGroup(
  id: 'alignment',
  title: 'Alignment (row main & cross axis)',
  summary: 'setRowAlignLeft/Center/Right place a row horizontally; '
      'setRowAlignTop/Middle/Bottom align differing heights vertically.',
  icon: Icons.format_align_center_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Centre the row — setRowAlignCenter',
      note: 'With slack to spare, the components cluster in the middle instead '
          'of hugging the left edge.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('A', teal))\n"
          "    .append(demoBox('B', orange))\n"
          '    .setRowAlignCenter()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('A', Colors.teal))
          .append(demoBox('B', Colors.orange))
          .setRowAlignCenter()
          .build(),
    ),
    ShowcaseCell(
      title: 'Push the row right — setRowAlignRight',
      code: 'AclBuilder()\n'
          "    .append(demoBox('A', indigo))\n"
          "    .append(demoBox('B', cyan))\n"
          '    .setRowAlignRight()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('A', Colors.indigo))
          .append(demoBox('B', Colors.cyan))
          .setRowAlignRight()
          .build(),
    ),
    ShowcaseCell(
      title: 'Cross-axis bottom — setRowAlignBottom',
      note: 'A short cell next to a tall one: bottom alignment lines them up on '
          'their baselines.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('tall', red))\n"
          '    .setPSize(110, 88)\n'
          "    .append(demoBox('short', green))\n"
          '    .setRowAlignBottom()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('tall', Colors.red))
          .setPSize(110, 88)
          .append(demoBox('short', Colors.green))
          .setRowAlignBottom()
          .build(),
    ),
  ],
);
