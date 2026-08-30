/// Borders & titles group — framing a container with a border and a caption.
///
/// `setAclBorderStyle(AclBorderStyle.solid(...))` draws a border around the
/// whole container; `setAclTitle` adds a caption and `setAclTitlePosition`
/// places it (`topLeft` / `topCenter` / `topRight`). Maps to the verified
/// `bordered_groups_demo` / `border_styles_demo` / `groups_demo`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The borders & titles capability group.
final ShowcaseGroup bordersTitlesGroup = ShowcaseGroup(
  id: 'borders_titles',
  title: 'Borders & titles',
  summary: 'setAclBorderStyle frames a container; setAclTitle + '
      'setAclTitlePosition add and place a caption on the border.',
  icon: Icons.crop_square_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Titled, bordered group',
      code: 'AclBuilder()\n'
          "    .append(demoBox('Name', indigo))\n"
          "    .append(demoBox('Email', cyan))\n"
          '    .setAclBorderStyle(const AclBorderStyle.solid())\n'
          "    .setAclTitle('Contact')\n"
          '    .build()',
      child: AclBuilder()
          .append(demoBox('Name', Colors.indigo))
          .append(demoBox('Email', Colors.cyan))
          .setAclBorderStyle(const AclBorderStyle.solid())
          .setAclTitle('Contact')
          .build(),
    ),
    ShowcaseCell(
      title: 'Rounded border, centred title',
      code: 'AclBuilder()\n'
          "    .append(demoBox('Street', teal))\n"
          "    .append(demoBox('City', teal))\n"
          '    .setAclBorderStyle(\n'
          '      const AclBorderStyle.solid(rounded: true, borderRadius: 12),\n'
          '    )\n'
          "    .setAclTitle('Address')\n"
          '    .setAclTitlePosition(AclTitlePosition.topCenter)\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('Street', Colors.teal))
          .append(demoBox('City', Colors.teal))
          .setAclBorderStyle(
            const AclBorderStyle.solid(rounded: true, borderRadius: 12),
          )
          .setAclTitle('Address')
          .setAclTitlePosition(AclTitlePosition.topCenter)
          .build(),
    ),
    ShowcaseCell(
      title: 'Coloured, thicker border with right title',
      code: 'AclBuilder()\n'
          "    .append(demoBox('Amount', deepPurple))\n"
          '    .setAclBorderStyle(\n'
          '      const AclBorderStyle.solid(color: Colors.deepPurple,\n'
          '          lineWidth: 2),\n'
          '    )\n'
          "    .setAclTitle('Payment')\n"
          '    .setAclTitlePosition(AclTitlePosition.topRight)\n'
          '    .build()',
      child: AclBuilder()
          .append(demoBox('Amount', Colors.deepPurple))
          .setAclBorderStyle(
            const AclBorderStyle.solid(
              color: Colors.deepPurple,
              lineWidth: 2,
            ),
          )
          .setAclTitle('Payment')
          .setAclTitlePosition(AclTitlePosition.topRight)
          .build(),
    ),
  ],
);
