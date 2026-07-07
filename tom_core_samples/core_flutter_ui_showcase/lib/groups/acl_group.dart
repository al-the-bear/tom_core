/// ACL group — the advanced container layout engine.
///
/// The ACL (Advanced Container Layout) engine is `tom_flutter_ui`'s fluent
/// alternative to nested Rows/Columns: a builder that composes components with
/// preferred/min/max sizing, growth flags, alignment, borders and titles.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

Widget _box(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TomText(text: label),
    );

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
          "    .append(boxA)\n"
          "    .append(boxB)\n"
          "    .append(boxC)\n"
          "    .build()",
      child: AclBuilder()
          .append(_box('A', Colors.red))
          .append(_box('B', Colors.green))
          .append(_box('C', Colors.blue))
          .build(),
    ),
    ShowcaseCell(
      title: 'Preferred sizing (setPSize)',
      note: 'The first cell is given a 200px preferred width; the rest share '
          'the remainder.',
      code: "AclBuilder()\n"
          "    .append(wide).setPSize(200)\n"
          "    .append(narrowA)\n"
          "    .append(narrowB)\n"
          "    .build()",
      child: AclBuilder()
          .append(_box('200px preferred', Colors.teal))
          .setPSize(200)
          .append(_box('rest', Colors.orange))
          .append(_box('rest', Colors.purple))
          .build(),
    ),
    ShowcaseCell(
      title: 'Titled & bordered group',
      code: "AclBuilder()\n"
          "    .append(boxA)\n"
          "    .append(boxB)\n"
          "    .setAclBorderStyle(const AclBorderStyle.solid())\n"
          "    .setAclTitle('Contact')\n"
          "    .build()",
      child: AclBuilder()
          .append(_box('Name', Colors.indigo))
          .append(_box('Email', Colors.cyan))
          .setAclBorderStyle(const AclBorderStyle.solid())
          .setAclTitle('Contact')
          .build(),
    ),
  ],
);
