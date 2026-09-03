/// Nesting group — an ACL container as a component of another.
///
/// `AclBuilder.build()` returns a plain `Widget`, so an entire ACL layout can
/// be appended into another ACL as a single cell. That is how complex,
/// panel-within-panel forms are composed. Maps to the verified
/// `nested_containers_demo` / `complex_layout_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The nesting capability group.
final ShowcaseGroup nestingGroup = ShowcaseGroup(
  id: 'nesting',
  title: 'Nesting (ACL inside ACL)',
  summary:
      'AclBuilder.build() returns a Widget, so a whole layout can be '
      'appended as one cell of another — panel-within-panel composition.',
  icon: Icons.account_tree_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'A two-row panel nested in a row',
      note:
          'The inner builder produces a small stacked panel; the outer '
          'builder treats it as one component beside a sibling box.',
      code:
          'final inner = AclBuilder()\n'
          "    .append(demoBox('Item 1', green))\n"
          '    .newRow(dist: 4)\n'
          "    .append(demoBox('Item 2', green))\n"
          '    .build();\n'
          '\n'
          'AclBuilder()\n'
          '    .append(inner)\n'
          '    .setPSize(160)\n'
          "    .append(demoBox('sibling', orange))\n"
          '    .expandX()\n'
          '    .build()',
      child: AclBuilder()
          .append(
            AclBuilder()
                .append(demoBox('Item 1', Colors.green))
                .newRow(dist: 4)
                .append(demoBox('Item 2', Colors.green))
                .build(),
          )
          .setPSize(160)
          .append(demoBox('sibling', Colors.orange))
          .expandX()
          .build(),
    ),
    ShowcaseCell(
      title: 'Two nested panels side by side',
      note:
          'Each panel is its own ACL build result; the outer row sizes and '
          'spaces them like any other component.',
      code:
          'final leftPanel = AclBuilder()\n'
          "    .append(demoBox('Left · A', blue))\n"
          '    .newRow(dist: 4)\n'
          "    .append(demoBox('Left · B', blue))\n"
          '    .setAclBorderStyle(const AclBorderStyle.solid())\n'
          "    .setAclTitle('Left')\n"
          '    .build();\n'
          '\n'
          'final rightPanel = AclBuilder()\n'
          "    .append(demoBox('Right · A', purple))\n"
          '    .newRow(dist: 4)\n'
          "    .append(demoBox('Right · B', purple))\n"
          '    .setAclBorderStyle(const AclBorderStyle.solid())\n'
          "    .setAclTitle('Right')\n"
          '    .build();\n'
          '\n'
          'AclBuilder()\n'
          '    .append(leftPanel)\n'
          '    .setPSize(150)\n'
          '    .append(rightPanel, dist: 12)\n'
          '    .setPSize(150)\n'
          '    .build()',
      child: AclBuilder()
          .append(
            AclBuilder()
                .append(demoBox('Left · A', Colors.blue))
                .newRow(dist: 4)
                .append(demoBox('Left · B', Colors.blue))
                .setAclBorderStyle(const AclBorderStyle.solid())
                .setAclTitle('Left')
                .build(),
          )
          .setPSize(150)
          .append(
            AclBuilder()
                .append(demoBox('Right · A', Colors.purple))
                .newRow(dist: 4)
                .append(demoBox('Right · B', Colors.purple))
                .setAclBorderStyle(const AclBorderStyle.solid())
                .setAclTitle('Right')
                .build(),
            dist: 12,
          )
          .setPSize(150)
          .build(),
    ),
  ],
);
