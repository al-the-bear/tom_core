/// Growth group — expand flags that fill the remaining row space.
///
/// `expandX()`, `expandY()` and `expand()` let a component soak up whatever
/// space the sized cells leave behind, the ACL equivalent of a Flutter
/// `Expanded`. Maps to the verified `expand_demo` / `dynamic_resize_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The growth capability group.
final ShowcaseGroup growthGroup = ShowcaseGroup(
  id: 'growth',
  title: 'Growth (expandX / expandY / expand)',
  summary: 'Expand flags let a component absorb the space the sized cells leave '
      'behind — the ACL counterpart of Flutter Expanded.',
  icon: Icons.open_in_full_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'expandX — fill remaining width',
      note: 'The fixed cell keeps its 120px; the flagged cell expands to fill '
          'the rest of the row.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('fixed 120', indigo))\n"
          '    .setPSize(120)\n'
          "    .append(demoBox('expandX', teal))\n"
          '    .expandX()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('fixed 120', Colors.indigo))
          .setPSize(120)
          .append(demoBox('expandX', Colors.teal))
          .expandX()
          .build(),
    ),
    ShowcaseCell(
      title: 'Two expanders share the surplus',
      note: 'When several cells expand, they divide the leftover space evenly.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('A', orange)).expandX()\n"
          "    .append(demoBox('B', purple)).expandX()\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('A', Colors.orange))
          .expandX()
          .append(demoBox('B', Colors.purple))
          .expandX()
          .build(),
    ),
    ShowcaseCell(
      title: 'expandY — fill the row height',
      note: 'expandY stretches the cell to the tallest component in the row.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('tall', red))\n"
          '    .setPSize(120, 96)\n'
          "    .append(demoBox('expandY', green))\n"
          '    .expandY()\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('tall', Colors.red))
          .setPSize(120, 96)
          .append(demoBox('expandY', Colors.green))
          .expandY()
          .build(),
    ),
  ],
);
