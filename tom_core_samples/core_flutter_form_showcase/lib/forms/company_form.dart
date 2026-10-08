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
final TomStaticSelectableSource<String> industrySource =
    TomStaticSelectableSource<String>([
      const TomSelectableItem(value: 'tech', label: 'Technology'),
      const TomSelectableItem(value: 'finance', label: 'Finance'),
      const TomSelectableItem(value: 'healthcare', label: 'Healthcare'),
      const TomSelectableItem(value: 'manufacturing', label: 'Manufacturing'),
      const TomSelectableItem(value: 'retail', label: 'Retail'),
      const TomSelectableItem(value: 'other', label: 'Other'),
    ]);

/// Simulates a server round-trip checking that a tax ID is not already taken.
/// Tax IDs starting with `X` are reported as taken after a 600 ms delay — the
/// canonical way to demonstrate an async (`TomSlowValidator`) pending → resolved
/// lifecycle.
///
/// Like every custom rule here the error is a *key*, prefixed `error.` so it
/// shares the namespace the `TomValidators` built-ins use, and its sentence lives
/// in `showcaseValidationTexts` (common/chrome_texts.dart).
final TomSlowValidator<String> taxIdUniquenessValidator =
    TomSlowValidator<String>((value) async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (value.startsWith('X')) {
        return const TomValidationError('error.taxIdTaken');
      }
      return const TomValidationSuccess();
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
    validators: [TomValidators.required(), TomValidators.minLength(2)],
  );

  /// Industry dropdown.
  late final industry = TomFormStringDropdown(
    'industry',
    '',
    form: this,
    labelTextOverride: 'Industry',
    source: industrySource,
    validators: [TomValidators.required()],
  );

  /// Tax ID — pattern-checked then verified async for uniqueness.
  late final taxId = TomFormStringInput(
    'taxId',
    '',
    form: this,
    labelTextOverride: 'Tax ID',
    validators: [
      TomValidators.required(),
      TomValidators.pattern(
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
      TomValidators.pattern(
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
    validators: [TomValidators.maxLength(500)],
  );
}
