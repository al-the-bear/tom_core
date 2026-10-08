/// Validation group — the validator families and how their results surface.
///
/// TomValidators are attached per field. Synchronous ones (required, minLength,
/// pattern) resolve instantly; an async [TomSlowValidator] resolves through a
/// pending → resolved lifecycle. `autoValidate` revalidates as the user types;
/// otherwise validation runs on submit. A [TomErrorView] renders a form's
/// aggregated errors.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/company_form.dart';
import '../forms/order_item_form.dart';

/// The Validation component group.
final ShowcaseGroup validationGroup = ShowcaseGroup(
  id: 'validation',
  title: 'Validation',
  summary:
      'required, minLength and pattern validators, an async '
      'TomSlowValidator, live autoValidate, and the TomErrorView summary.',
  icon: Icons.rule_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Required + minLength',
      note:
          'Leave it empty or type one character, then move focus away to '
          'see the message.',
      code:
          "validators: [\n"
          "  TomValidators.required(),\n"
          "  TomValidators.minLength(2),\n"
          "]",
      child: FormHost<CompanyForm>(
        scopeId: 'val_required',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.name.widget,
      ),
    ),
    ShowcaseCell(
      title: 'Pattern',
      note:
          'A RegExp validator with a named errorKey. Type a non-URL to see '
          'the message that error.invalidUrl resolves to.',
      code:
          "validators: [\n"
          "  TomValidators.pattern(\n"
          "    RegExp(r'^https?:\\/\\/...'),\n"
          "    errorKey: 'error.invalidUrl',\n"
          "  ),\n"
          "]",
      child: FormHost<CompanyForm>(
        scopeId: 'val_pattern',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.website.widget,
      ),
    ),
    ShowcaseCell(
      title: 'Async (TomSlowValidator)',
      note:
          'A simulated server check (600 ms). Tax IDs starting with "X" '
          'resolve to taken; watch the pending spinner.',
      code:
          "final taxIdUniquenessValidator =\n"
          "    TomSlowValidator<String>((value) async {\n"
          "  await Future.delayed(Duration(milliseconds: 600));\n"
          "  if (value.startsWith('X')) {\n"
          "    return TomValidationError('error.taxIdTaken');\n"
          "  }\n"
          "  return TomValidationSuccess();\n"
          "});",
      child: FormHost<CompanyForm>(
        scopeId: 'val_async',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => form.taxId.widget,
      ),
    ),
    ShowcaseCell(
      title: 'Live autoValidate',
      note:
          'With autoValidate the quantity field revalidates on every '
          'keystroke — type letters to see the integer error immediately.',
      code:
          "TomFormStringInput(\n"
          "  'quantity',\n"
          "  '1',\n"
          "  form: this,\n"
          "  labelTextOverride: 'Qty',\n"
          "  autoValidate: true,\n"
          "  validators: [TomValidators.required(), positiveInteger],\n"
          ")",
      child: FormHost<OrderItemForm>(
        scopeId: 'val_autovalidate',
        create: OrderItemForm.new,
        bind: (form) => form.bind(OrderItem()),
        builder: (context, form) => form.quantity.widget,
      ),
    ),
    ShowcaseCell(
      title: 'TomErrorView summary',
      note:
          'Aggregates every field error on a form. Empty until validation '
          'runs: press Validate, or edit the name, to populate it.',
      code:
          "TomErrorView(\n"
          "  form: form,\n"
          "  title: 'Please fix the following',\n"
          ")",
      child: FormHost<CompanyForm>(
        scopeId: 'val_errorview',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            form.name.widget,
            TomSizedBox(height: 8),
            TomElevatedButton(label: 'Validate', onPressed: form.validate),
            TomSizedBox(height: 8),
            TomErrorView(form: form, title: 'Please fix the following'),
          ],
        ),
      ),
    ),
  ],
);
