/// Theming group — the same form under different [TomFormStyle] presets.
///
/// A [TomFormStyleScope] pushes a style onto everything beneath it. The three
/// shipped presets — material3, compact and bordered — change label placement,
/// gaps and borders without touching the form definition, so the identical
/// CompanyForm renders three ways purely by swapping the scope's `style`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/company_form.dart';

Widget _styledForm(String scopeId, TomFormStyle style) {
  return FormHost<CompanyForm>(
    scopeId: scopeId,
    create: CompanyForm.new,
    bind: (form) => form.bind(CompanyProfile()),
    builder: (context, form) => TomFormStyleScope(
      style: style,
      child: TomAclBuilder(id: '${scopeId}_acl', elementProvider: form)
          .setAclExpandXDefault(true)
          .setAclDefaultAppendGap(0)
          .append((p) => p.name.widget)
          .newRow()
          .append((p) => p.industry.widget)
          .build(context),
    ),
  );
}

/// The Theming component group.
final ShowcaseGroup themingGroup = ShowcaseGroup(
  id: 'theming',
  title: 'Theming (form styles)',
  summary: 'One CompanyForm rendered under the material3, compact and '
      'bordered presets, switched purely through a TomFormStyleScope.',
  icon: Icons.palette_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomFormStyle.material3',
      note: 'The default: standard label placement and gaps.',
      code: "TomFormStyleScope(\n"
          "  style: TomFormStyle.material3,\n"
          "  child: formLayout,\n"
          ")",
      child: _styledForm('thm_material3', TomFormStyle.material3),
    ),
    ShowcaseCell(
      title: 'TomFormStyle.compact',
      note: 'Floating labels and reduced label/error gaps for dense forms.',
      code: "TomFormStyleScope(\n"
          "  style: TomFormStyle.compact,\n"
          "  child: formLayout,\n"
          ")",
      child: _styledForm('thm_compact', TomFormStyle.compact),
    ),
    ShowcaseCell(
      title: 'TomFormStyle.bordered',
      note: 'Outlined borders with floating labels and error-border visuals.',
      code: "TomFormStyleScope(\n"
          "  style: TomFormStyle.bordered,\n"
          "  child: formLayout,\n"
          ")",
      child: _styledForm('thm_bordered', TomFormStyle.bordered),
    ),
  ],
);
