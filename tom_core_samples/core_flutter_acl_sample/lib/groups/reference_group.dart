/// Reference constraints group — size and align one component off another.
///
/// A component in a later row can borrow its geometry from an **anchor** in an
/// earlier row: `sameWidthAs(anchor)` matches its width and
/// `alignLeftToLeft(anchor)` lines up their left edges. This is how label/field
/// columns stay aligned without a fixed pixel grid. Maps to the verified
/// `reference_constraints_demo`. (The anchor must live in a *different* row from
/// the component that references it for horizontal constraints.)
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The reference-constraints capability group.
final ShowcaseGroup referenceGroup = ShowcaseGroup(
  id: 'reference',
  title: 'Reference constraints',
  summary: 'sameWidthAs and alignLeftToLeft link a component to an anchor in '
      'an earlier row, keeping label/field columns aligned without a grid.',
  icon: Icons.linear_scale_outlined,
  cells: (context) {
    // The anchors must be stable instances so later rows can reference them
    // by identity (the ACL engine keys constraints off the widget object).
    final anchorLabel = demoBox('Anchor label', Colors.deepOrange);
    final anchorField = demoBox('Anchor field (wide)', Colors.blueGrey);
    return [
      ShowcaseCell(
        title: 'Linked width + left edge',
        note: 'Row 2 borrows the width and left edge of the row-1 anchors, so '
            'the two columns line up exactly.',
        code: 'final anchorLabel = demoBox(...);\n'
            'final anchorField = demoBox(...);\n'
            '\n'
            'AclBuilder()\n'
            '    .setAclDefaultRowVerticalAlignment(\n'
            '        AclRowCrossAlignment.center)\n'
            '    .append(anchorLabel)\n'
            '    .append(anchorField, dist: 12)\n'
            '    .newRow(dist: 10)\n'
            "    .append(demoBox('Linked label', teal))\n"
            '    .sameWidthAs(anchorLabel)\n'
            '    .alignLeftToLeft(anchorLabel)\n'
            "    .append(demoBox('Linked field', orange), dist: 12)\n"
            '    .sameWidthAs(anchorField)\n'
            '    .alignRightToRight(anchorField)\n'
            '    .build()',
        child: AclBuilder()
            .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
            .append(anchorLabel)
            .append(anchorField, dist: 12)
            .newRow(dist: 10)
            .append(demoBox('Linked label', Colors.teal))
            .sameWidthAs(anchorLabel)
            .alignLeftToLeft(anchorLabel)
            .append(demoBox('Linked field', Colors.orange), dist: 12)
            .sameWidthAs(anchorField)
            .alignRightToRight(anchorField)
            .build(),
      ),
    ];
  },
);
