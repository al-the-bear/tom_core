/// Responsive ACL form — rows reflow AND fields re-style, from one chain.
///
/// This is the capstone: a single [TomAclBuilder] layout that combines the two
/// independent responsive mechanisms shown separately elsewhere. The builder's
/// `addRowBreakpoint(atWidth:)` reflows a shared row to a stack as the viewport
/// narrows (the *layout* axis), while the enclosing [TomFormStyleScope] feeds the
/// live width into [TomFieldStyle] `*BpOverrides` so the field anatomy — label
/// placement, fonts, gaps — re-resolves per tier (the *style* axis). One form,
/// one builder chain; both axes react to the same width with no app-code
/// branching. Re-cast from the verified `tom_flutter_form_test` breakpoint demos.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/responsive_entities.dart';
import '../forms/company_form.dart';

/// The width-reactive field style shared by both cells: label floats below
/// 400px, sits above between 400–699px, and goes inline at 700px; fonts and gaps
/// bump at each tier. The override lists ride on [TomFieldStyle]; the enclosing
/// [TomFormStyleScope] feeds the live width into `resolveFieldStyle`.
TomFormStyle get _responsiveStyle => TomFormStyle(
      defaults: const TomFieldStyle(
        labelPlacement: LabelPlacement.floating,
        labelPlacementBpOverrides: [
          (400, LabelPlacement.above),
          (700, LabelPlacement.inline),
        ],
        labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        labelStyleBpOverrides: [
          (400, TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          (700, TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
        labelFieldGap: 2,
        labelFieldGapBpOverrides: [(400, 4.0), (700, 8.0)],
      ).copyWith(
        fieldBorder: const OutlineInputBorder(),
      ),
    );

/// Builds the capstone layout at a fixed [width]: a [TomFormStyleScope] (style
/// axis) wrapping a [TomAclBuilder] whose row reflows at 480px (layout axis).
Widget _responsiveForm(String scopeId, double width) {
  // Why: a raw SizedBox rather than TomSizedBox — the width pin is gallery
  // harness imposing the constraint this cell exists to demonstrate, not
  // chrome. One of the two raw-Flutter exceptions named in `README.md` §5.
  return SizedBox(
    width: width,
    child: FormHost<CompanyForm>(
      scopeId: scopeId,
      create: CompanyForm.new,
      bind: (form) => form.bind(CompanyProfile()),
      builder: (context, form) => TomFormStyleScope(
        style: _responsiveStyle,
        child: TomAclBuilder(id: '${scopeId}_acl', elementProvider: form)
            .setAclExpandXDefault(true)
            .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
            .append((p) => p.name.widget)
            .newRow()
            .append((p) => p.industry.widget)
            .addRowBreakpoint(atWidth: 480)
            .append((p) => p.taxId.widget, dist: 16)
            .build(context),
      ),
    ),
  );
}

/// The responsive-ACL-form mechanism group.
final ShowcaseGroup responsiveAclFormGroup = ShowcaseGroup(
  id: 'responsive_acl_form',
  title: 'Responsive ACL form',
  summary: 'The capstone: one TomAclBuilder chain where addRowBreakpoint '
      'reflows a row to a stack AND TomFormStyleScope re-styles every field per '
      'tier — both axes react to the same width, no app-code branching.',
  icon: Icons.dashboard_customize_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Wide (640px) — row shared, label inline-ish',
      note: 'Above 480px the industry/taxId fields share one row; above 400px '
          'labels sit above the field with the larger font and gap.',
      code: 'TomFormStyleScope(\n'
          '  style: TomFormStyle(defaults: TomFieldStyle(\n'
          '    labelPlacement: LabelPlacement.floating,\n'
          '    labelPlacementBpOverrides: [\n'
          '      (400, LabelPlacement.above),\n'
          '      (700, LabelPlacement.inline),\n'
          '    ],\n'
          '    // …labelStyle / labelFieldGap overrides…\n'
          '  )),\n'
          '  child: TomAclBuilder(id: "cap", elementProvider: form)\n'
          '      .append((p) => p.name.widget)\n'
          '      .newRow()\n'
          '      .append((p) => p.industry.widget)\n'
          '      .addRowBreakpoint(atWidth: 480)\n'
          '      .append((p) => p.taxId.widget, dist: 16)\n'
          '      .build(context),\n'
          ')',
      child: _responsiveForm('cap_wide', 640),
    ),
    ShowcaseCell(
      title: 'Narrow (360px) — row stacked, label floating',
      note: 'Below 480px the shared row reflows to a stack; below 400px the same '
          'fields drop to floating labels with the compact font and gap. Same '
          'chain — both axes moved.',
      code: '// Identical builder + scope as above — only the available width\n'
          '// differs. The layout axis (addRowBreakpoint) and the style axis\n'
          '// (TomFieldStyle *BpOverrides) both respond to it.',
      child: _responsiveForm('cap_narrow', 360),
    ),
  ],
);
