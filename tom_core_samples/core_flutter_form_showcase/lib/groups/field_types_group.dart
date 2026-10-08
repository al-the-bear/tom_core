/// Field-types group — the building blocks every other group composes.
///
/// Each cell renders one bound field straight from a [CompanyForm] or
/// [OrderItemForm]. The field widgets read and write the reflected entity they
/// were bound to, so what you see is the real form machinery, not a mock-up.
library;

import 'package:flutter/material.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/company_form.dart';
import '../forms/order_item_form.dart';

/// The Field-types component group.
final ShowcaseGroup fieldTypesGroup = ShowcaseGroup(
  id: 'field_types',
  title: 'Field types',
  summary:
      'The four string-backed field widgets — text input, dropdown, '
      'type-ahead search and multi-line — each bound to a reflected entity.',
  icon: Icons.text_fields_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomFormStringInput',
      note: 'A plain text field. Bound to CompanyProfile.name via the form.',
      code:
          "TomFormStringInput(\n"
          "  'name',\n"
          "  '',\n"
          "  form: this,\n"
          "  labelTextOverride: 'Company name',\n"
          "  validators: [TomValidators.required(), TomValidators.minLength(2)],\n"
          ")",
      child: FormHost<CompanyForm>(
        scopeId: 'ft_text',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.name.widget,
      ),
    ),
    ShowcaseCell(
      title: 'TomFormStringDropdown',
      note: 'A dropdown over a TomStaticSelectableSource of labelled values.',
      code:
          "TomFormStringDropdown(\n"
          "  'industry',\n"
          "  '',\n"
          "  form: this,\n"
          "  labelTextOverride: 'Industry',\n"
          "  source: industrySource,\n"
          "  validators: [TomValidators.required()],\n"
          ")",
      child: FormHost<CompanyForm>(
        scopeId: 'ft_dropdown',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.industry.widget,
      ),
    ),
    ShowcaseCell(
      title: 'TomFormSearchInput',
      note:
          'A type-ahead picker. Selecting a catalogue entry auto-fills the '
          'sibling unit-price field.',
      code:
          "TomFormSearchInput<String>(\n"
          "  'productName',\n"
          "  '',\n"
          "  form: this,\n"
          "  source: productSource(),\n"
          "  labelTextOverride: 'Product',\n"
          "  hintTextOverride: 'Type to search the catalogue…',\n"
          "  validators: [TomValidators.required()],\n"
          ")",
      child: FormHost<OrderItemForm>(
        scopeId: 'ft_search',
        create: OrderItemForm.new,
        bind: (form) => form.bind(OrderItem()),
        builder: (context, form) => form.productName.widget,
      ),
    ),
    ShowcaseCell(
      title: 'Multi-line input',
      note: 'The same TomFormStringInput with maxLines and maxLength set.',
      code:
          "TomFormStringInput(\n"
          "  'description',\n"
          "  '',\n"
          "  form: this,\n"
          "  labelTextOverride: 'Description',\n"
          "  maxLength: 500,\n"
          "  maxLines: 4,\n"
          "  validators: [TomValidators.maxLength(500)],\n"
          ")",
      child: FormHost<CompanyForm>(
        scopeId: 'ft_multiline',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.description.widget,
      ),
    ),
  ],
);
