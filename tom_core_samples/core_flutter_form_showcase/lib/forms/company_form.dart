/// `TomForm` subclasses bound to [CompanyProfile].
///
/// These mirror the verified `tom_flutter_form_test` company forms, trimmed to
/// the flat field set the showcase teaches. The form is deliberately *flat*
/// (no nested `TomForm`) so binding a reflected [CompanyProfile] needs only the
/// kernel-level reflection emitted from `reflection_seed.dart`.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/showcase_entities.dart';

/// The industry dropdown source — a static, labelled selectable list.
final StaticSelectableSource<String> industrySource =
    StaticSelectableSource<String>([
  const SelectableItem(value: 'tech', label: 'Technology'),
  const SelectableItem(value: 'finance', label: 'Finance'),
  const SelectableItem(value: 'healthcare', label: 'Healthcare'),
  const SelectableItem(value: 'manufacturing', label: 'Manufacturing'),
  const SelectableItem(value: 'retail', label: 'Retail'),
  const SelectableItem(value: 'other', label: 'Other'),
]);

/// Simulates a server round-trip checking that a tax ID is not already taken.
/// Tax IDs starting with `X` are reported as taken after a 600 ms delay — the
/// canonical way to demonstrate an async (`SlowValidator`) pending → resolved
/// lifecycle.
///
/// Like every custom rule here the error is a *key*, prefixed `error.` so it
/// shares the namespace the `Validators` built-ins use, and its sentence lives
/// in `showcaseValidationTexts` (common/chrome_texts.dart).
final SlowValidator<String> taxIdUniquenessValidator =
    SlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (value.startsWith('X')) {
    return const ValidationError('error.taxIdTaken');
  }
  return const ValidationSuccess();
});

/// A flat company form: string input, dropdown, pattern + async validation and
/// a multi-line description. The single source of truth for the field-type,
/// validation, layout and theming cells.
@tomReflector
class CompanyForm extends TomForm<CompanyProfile> {
  /// Creates the company form in the ambient [TomScope].
  CompanyForm() : super(formId: 'company');

  @override
  void createFormElements() {
    // Fields are declared below as late finals; nothing extra to wire up.
  }

  /// Required company name (min length 2).
  late final name = TomFormStringInput(
    'name',
    '',
    form: this,
    labelTextOverride: 'Company name',
    validators: [Validators.required(), Validators.minLength(2)],
  );

  /// Industry dropdown.
  late final industry = TomFormStringDropdown(
    'industry',
    '',
    form: this,
    labelTextOverride: 'Industry',
    source: industrySource,
    validators: [Validators.required()],
  );

  /// Tax ID — pattern-checked then verified async for uniqueness.
  late final taxId = TomFormStringInput(
    'taxId',
    '',
    form: this,
    labelTextOverride: 'Tax ID',
    validators: [
      Validators.required(),
      Validators.pattern(
        RegExp(r'^[A-Z0-9-]+$'),
        errorKey: 'error.taxIdFormat',
      ),
      taxIdUniquenessValidator,
    ],
  );

  /// Website URL — pattern validated.
  late final website = TomFormStringInput(
    'website',
    '',
    form: this,
    labelTextOverride: 'Website',
    validators: [
      Validators.pattern(
        RegExp(
          r'^https?:\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
          r'[a-zA-Z]{2,}(?::\d{1,5})?(?:\/[^\s]*)?$',
        ),
        errorKey: 'error.invalidUrl',
      ),
    ],
    keyboardType: TextInputType.url,
  );

  /// Multi-line description, length-capped at 500.
  late final description = TomFormStringInput(
    'description',
    '',
    form: this,
    labelTextOverride: 'Description',
    maxLength: 500,
    maxLines: 4,
    validators: [Validators.maxLength(500)],
  );
}
