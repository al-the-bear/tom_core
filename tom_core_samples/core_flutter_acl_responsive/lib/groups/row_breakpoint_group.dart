/// Row breakpoint — a form row that splits to a stack as it narrows.
///
/// `addRowBreakpoint(atWidth:)` tells the ACL builder to keep a row's fields
/// side by side only while there is at least that much width; below it the row
/// reflows to a stack. The same builder chain therefore adapts to the viewport
/// with no app-code branching. Each cell pins a width so the two regimes show
/// side by side in the gallery. Re-cast from the verified
/// `core_flutter_form_showcase` responsive group.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/responsive_entities.dart';
import '../forms/company_form.dart';

Widget _breakpointForm(String scopeId, double width) {
  // Why: a raw SizedBox rather than TomSizedBox — the width pin is gallery
  // harness imposing the constraint this cell exists to demonstrate, not
  // chrome. One of the two raw-Flutter exceptions named in `README.md` §5.
  return SizedBox(
    width: width,
    child: FormHost<CompanyForm>(
      scopeId: scopeId,
      create: CompanyForm.new,
      bind: (form) => form.bind(CompanyProfile()),
      builder: (context, form) =>
          TomAclBuilder(id: '${scopeId}_acl', elementProvider: form)
              .setAclExpandXDefault(true)
              .setAclDefaultAppendGap(0)
              .append((p) => p.industry.widget)
              .addRowBreakpoint(atWidth: 400)
              .append((p) => p.taxId.widget, dist: 16)
              .build(context),
    ),
  );
}

/// The row-breakpoint mechanism group.
final ShowcaseGroup rowBreakpointGroup = ShowcaseGroup(
  id: 'row_breakpoint',
  title: 'Row breakpoints',
  summary: 'addRowBreakpoint(atWidth: 400): two fields share one row above '
      '400px and reflow to a stack below it — same builder, different width.',
  icon: Icons.table_rows_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Wide (520px) — side by side',
      note: 'Above the 400px breakpoint the two fields share one row.',
      code: "TomAclBuilder(id: 'bp', elementProvider: form)\n"
          '    .append((p) => p.industry.widget)\n'
          '    .addRowBreakpoint(atWidth: 400)\n'
          '    .append((p) => p.taxId.widget, dist: 16)\n'
          '    .build(context)',
      child: _breakpointForm('rsp_wide', 520),
    ),
    ShowcaseCell(
      title: 'Narrow (320px) — stacked',
      note: 'The identical layout below 400px reflows the row to a stack.',
      code: '// Same builder as above — only the available width differs.\n'
          'SizedBox(width: 320, child: formLayout)',
      child: _breakpointForm('rsp_narrow', 320),
    ),
  ],
);
