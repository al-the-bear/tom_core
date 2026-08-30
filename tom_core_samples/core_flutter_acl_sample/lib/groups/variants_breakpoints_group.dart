/// Variants & breakpoints group — width-reactive layout, shown statically.
///
/// `addRowBreakpoint(atWidth: …)` lets a row split onto two lines once the
/// container narrows past a width; `addVariant(name, atWidth: …, builder: …)`
/// swaps in an alternative row layout below a width. Here they are shown as
/// **static snapshots** — the same chain a responsive screen uses, rendered at
/// whatever width the preview happens to have. The live width-reactive reflow
/// is the subject of the sibling `core_flutter_acl_responsive` sample. Maps to
/// the verified `row_breakpoints_demo` / `inline_variants_demo` /
/// `responsive_variants_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The variants & breakpoints capability group.
final ShowcaseGroup variantsBreakpointsGroup = ShowcaseGroup(
  id: 'variants_breakpoints',
  title: 'Variants & breakpoints',
  summary: 'addRowBreakpoint splits a row when it narrows; addVariant swaps in '
      'an alternative layout below a width — shown here as static snapshots.',
  icon: Icons.view_column_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Row breakpoint — addRowBreakpoint',
      note: 'Once the container narrows past 480px the row splits after the '
          'second cell; above that width all four sit on one line. This is a '
          'static snapshot of whichever regime the preview width selects — the '
          'live reflow is the sibling `core_flutter_acl_responsive` sample.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('First', teal))\n"
          "    .append(demoBox('Second', teal))\n"
          '    .addRowBreakpoint(atWidth: 480, splitRowDist: 8)\n'
          "    .append(demoBox('Third', orange))\n"
          "    .append(demoBox('Fourth', orange))\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('First', Colors.teal))
          .append(demoBox('Second', Colors.teal))
          .addRowBreakpoint(atWidth: 480, splitRowDist: 8)
          .append(demoBox('Third', Colors.orange))
          .append(demoBox('Fourth', Colors.orange))
          .build(),
    ),
    ShowcaseCell(
      title: 'Inline variant — addVariant',
      note: 'A "narrow" variant registered at 420px supplies a stacked layout '
          'that replaces the default once the container drops below that width.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('Label', indigo))\n"
          "    .append(demoBox('Value', cyan), dist: 12)\n"
          "    .addVariant('narrow', atWidth: 420, builder: (b) {\n"
          "      b.append(demoBox('Label', indigo))\n"
          '          .newRow(dist: 6)\n'
          "          .append(demoBox('Value', cyan));\n"
          '    })\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('Label', Colors.indigo))
          .append(demoBox('Value', Colors.cyan), dist: 12)
          .addVariant('narrow', atWidth: 420, builder: (b) {
            b
                .append(demoBox('Label', Colors.indigo))
                .newRow(dist: 6)
                .append(demoBox('Value', Colors.cyan));
          })
          .build(),
    ),
  ],
);
