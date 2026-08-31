/// ACL group — the advanced container layout engine.
///
/// The ACL (Advanced Container Layout) engine is `tom_flutter_ui`'s fluent
/// alternative to nested Rows/Columns: a builder that composes components with
/// preferred/min/max sizing, growth flags, alignment, borders and titles.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The ACL component group.
final ShowcaseGroup aclGroup = ShowcaseGroup(
  id: 'acl',
  title: 'Advanced container layout',
  summary: 'The fluent AclBuilder engine: rows, preferred sizing and '
      'titled/bordered groups composed without nested Rows and Columns.',
  icon: Icons.account_tree_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Basic row',
      code: "AclBuilder()\n"
          "    .append(demoBox('A', Colors.red))\n"
          "    .append(demoBox('B', Colors.green))\n"
          "    .append(demoBox('C', Colors.blue))\n"
          "    .build()",
      child: AclBuilder()
          .append(demoBox('A', Colors.red))
          .append(demoBox('B', Colors.green))
          .append(demoBox('C', Colors.blue))
          .build(),
    ),
    ShowcaseCell(
      title: 'Preferred sizing (setPSize)',
      note: 'The first cell is given a 200px preferred width; the rest share '
          'the remainder.',
      code: "AclBuilder()\n"
          "    .append(demoBox('200px preferred', Colors.teal))\n"
          "    .setPSize(200)\n"
          "    .append(demoBox('rest', Colors.orange))\n"
          "    .append(demoBox('rest', Colors.purple))\n"
          "    .build()",
      child: AclBuilder()
          .append(demoBox('200px preferred', Colors.teal))
          .setPSize(200)
          .append(demoBox('rest', Colors.orange))
          .append(demoBox('rest', Colors.purple))
          .build(),
    ),
    ShowcaseCell(
      title: 'Titled & bordered group',
      code: "AclBuilder()\n"
          "    .append(demoBox('Name', Colors.indigo))\n"
          "    .append(demoBox('Email', Colors.cyan))\n"
          "    .setAclBorderStyle(const AclBorderStyle.solid())\n"
          "    .setAclTitle('Contact')\n"
          "    .build()",
      child: AclBuilder()
          .append(demoBox('Name', Colors.indigo))
          .append(demoBox('Email', Colors.cyan))
          .setAclBorderStyle(const AclBorderStyle.solid())
          .setAclTitle('Contact')
          .build(),
    ),
  ],
);
