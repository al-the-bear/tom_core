/// Layout group — composing fields with the fluent [TomAclBuilder].
///
/// Rather than hand-nesting Rows and Columns, a form lays its fields out with
/// the ACL builder: `append` adds a field to the current row, `newRow` starts
/// the next, and sizing/alignment/gap flags tune each cell. The builder reads
/// fields straight off the bound form via its `elementProvider`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/company_form.dart';

/// The Layout component group.
final ShowcaseGroup layoutGroup = ShowcaseGroup(
  id: 'layout',
  title: 'Layout (AclBuilder)',
  summary:
      'Fluent field layout: single-column stacks, multiple fields per '
      'row, and per-cell gaps with the TomAclBuilder engine.',
  icon: Icons.view_agenda_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Single-column stack',
      note: 'Every field on its own row — the default form rhythm.',
      code:
          "TomAclBuilder(id: 'basic', elementProvider: form)\n"
          "    .setAclExpandXDefault(true)\n"
          "    .setAclDefaultAppendGap(0)\n"
          "    .append((p) => p.name.widget)\n"
          "    .newRow()\n"
          "    .append((p) => p.website.widget)\n"
          "    .build(context)",
      child: FormHost<CompanyForm>(
        scopeId: 'lay_stack',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) =>
            TomAclBuilder(id: 'lay_stack_acl', elementProvider: form)
                .setAclExpandXDefault(true)
                .setAclDefaultAppendGap(0)
                .append((p) => p.name.widget)
                .newRow()
                .append((p) => p.website.widget)
                .build(context),
      ),
    ),
    ShowcaseCell(
      title: 'Two fields per row',
      note:
          'append twice before newRow puts both fields on one line, sharing '
          'the width.',
      code:
          "TomAclBuilder(id: 'pair', elementProvider: form)\n"
          "    .setAclExpandXDefault(true)\n"
          "    .setAclDefaultAppendGap(0)\n"
          "    .append((p) => p.industry.widget)\n"
          "    .append((p) => p.taxId.widget, dist: 16)\n"
          "    .build(context)",
      child: FormHost<CompanyForm>(
        scopeId: 'lay_pair',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) =>
            TomAclBuilder(id: 'lay_pair_acl', elementProvider: form)
                .setAclExpandXDefault(true)
                .setAclDefaultAppendGap(0)
                .append((p) => p.industry.widget)
                .append((p) => p.taxId.widget, dist: 16)
                .build(context),
      ),
    ),
    ShowcaseCell(
      title: 'Full form layout',
      note:
          'The composed CompanyForm: name, then industry + tax id, then '
          'website, then a multi-line description.',
      code:
          "TomAclBuilder(id: 'company', elementProvider: form)\n"
          "    .setAclExpandXDefault(true)\n"
          "    .setAclDefaultAppendGap(0)\n"
          "    .append((p) => p.name.widget)\n"
          "    .newRow()\n"
          "    .append((p) => p.industry.widget)\n"
          "    .append((p) => p.taxId.widget, dist: 16)\n"
          "    .newRow()\n"
          "    .append((p) => p.website.widget)\n"
          "    .newRow()\n"
          "    .append((p) => p.description.widget)\n"
          "    .build(context)",
      child: FormHost<CompanyForm>(
        scopeId: 'lay_full',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) =>
            TomAclBuilder(id: 'lay_full_acl', elementProvider: form)
                .setAclExpandXDefault(true)
                .setAclDefaultAppendGap(0)
                .append((p) => p.name.widget)
                .newRow()
                .append((p) => p.industry.widget)
                .append((p) => p.taxId.widget, dist: 16)
                .newRow()
                .append((p) => p.website.widget)
                .newRow()
                .append((p) => p.description.widget)
                .build(context),
      ),
    ),
  ],
);
