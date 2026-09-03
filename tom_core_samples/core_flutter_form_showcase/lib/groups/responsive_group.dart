/// Responsive group — breakpoint-driven row reflow.
///
/// `addRowBreakpoint(atWidth:)` tells the ACL builder to keep a row's fields
/// side by side only while there is at least that much width; below it the row
/// reflows to a stack. The same form definition therefore adapts to the
/// viewport. Here each cell pins a width so the two regimes show side by side.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/company_form.dart';

Widget _breakpointForm(String scopeId, double width) {
  // Why: TomSizedBox, not SizedBox — the sample lays out exclusively with Tom
  // widgets (G-UI-1), and this box is quoted by the narrow cell's snippet, so
  // a raw one would teach the rule's opposite.
  return TomSizedBox(
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

/// The Responsive component group.
final ShowcaseGroup responsiveGroup = ShowcaseGroup(
  id: 'responsive',
  title: 'Responsive breakpoints',
  summary: 'One row with addRowBreakpoint(atWidth: 400): two fields stay side '
      'by side above 400px and reflow to a stack below it.',
  icon: Icons.aspect_ratio_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Wide (520px) — side by side',
      note: 'Above the 400px breakpoint the two fields share one row.',
      code: "TomAclBuilder(id: 'bp', elementProvider: form)\n"
          "    .setAclExpandXDefault(true)\n"
          "    .setAclDefaultAppendGap(0)\n"
          "    .append((p) => p.industry.widget)\n"
          "    .addRowBreakpoint(atWidth: 400)\n"
          "    .append((p) => p.taxId.widget, dist: 16)\n"
          "    .build(context)",
      child: _breakpointForm('rsp_wide', 520),
    ),
    ShowcaseCell(
      title: 'Narrow (320px) — stacked',
      note: 'The identical layout below 400px reflows the row to a stack.',
      code: "// Same builder as above — only the available width differs.\n"
          "TomSizedBox(width: 320, child: formLayout)",
      child: _breakpointForm('rsp_narrow', 320),
    ),
  ],
);
