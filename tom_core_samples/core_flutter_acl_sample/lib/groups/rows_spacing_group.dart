/// Rows & spacing group — multi-row layout and inter-component gaps.
///
/// `newRow()` starts a fresh row; the `dist:` argument on `append`/`newRow`
/// inserts a gap before the component/row. Together they build grid-like forms
/// without nested Columns. Maps to the verified `basic_row_demo` /
/// `multi_row_demo` / `spacing_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The rows & spacing capability group.
final ShowcaseGroup rowsSpacingGroup = ShowcaseGroup(
  id: 'rows_spacing',
  title: 'Rows & spacing (newRow, dist)',
  summary:
      'newRow starts a fresh row; the dist argument inserts gaps before a '
      'component or row — grid-like layouts without nested Columns.',
  icon: Icons.table_rows_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'A single row',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('A', red))\n"
          "    .append(demoBox('B', green))\n"
          "    .append(demoBox('C', blue))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('A', Colors.red))
          .append(demoBox('B', Colors.green))
          .append(demoBox('C', Colors.blue))
          .build(),
    ),
    ShowcaseCell(
      title: 'Two rows — newRow',
      note: 'newRow(dist: 8) drops to a second row with an 8px gap above it.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('Row 1 · A', teal))\n"
          "    .append(demoBox('Row 1 · B', teal))\n"
          '    .newRow(dist: 8)\n'
          "    .append(demoBox('Row 2 · C', orange))\n"
          "    .append(demoBox('Row 2 · D', orange))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('Row 1 · A', Colors.teal))
          .append(demoBox('Row 1 · B', Colors.teal))
          .newRow(dist: 8)
          .append(demoBox('Row 2 · C', Colors.orange))
          .append(demoBox('Row 2 · D', Colors.orange))
          .build(),
    ),
    ShowcaseCell(
      title: 'Per-component gaps — append(dist:)',
      note:
          'dist on append inserts a leading gap, so spacing is local to each '
          'component rather than a single row-wide value.',
      code:
          'AclBuilder()\n'
          "    .append(demoBox('A', indigo))\n"
          "    .append(demoBox('B', indigo), dist: 24)\n"
          "    .append(demoBox('C', indigo), dist: 4)\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('A', Colors.indigo))
          .append(demoBox('B', Colors.indigo), dist: 24)
          .append(demoBox('C', Colors.indigo), dist: 4)
          .build(),
    ),
  ],
);
