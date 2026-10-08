/// A flat `TomForm` bound to [CompanyProfile].
///
/// This is the form behind the breakpoint-field-style and row-breakpoint
/// screens: a string input, a dropdown, and two pattern-validated inputs.
/// Mirrors the verified `tom_flutter_form_test` company form, trimmed to the
/// fields the responsive screens lay out. The form is deliberately *flat* (no
/// nested `TomForm`) so binding a reflected [CompanyProfile] needs only
/// kernel-level reflection emitted from `reflection_seed.dart`.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/responsive_entities.dart';

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

/// A flat company form: string input, dropdown and two pattern-validated
/// inputs. The single source of truth for the breakpoint-field-style and
/// row-breakpoint cells.
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

  /// Tax ID — pattern-checked.
  ///
  /// The `errorKey` keeps the framework's `error.*` prefix (`TomValidators`
  /// built-ins emit `error.required`, `error.minLength`, …) so a custom rule
  /// lands in the same namespace and resolves through the same chain. Its
  /// message lives in `companyValidationTexts`; the key on its own would render
  /// as literal text, which is why `validation_message_test.dart` asserts the
  /// sentence rather than the presence of an error.
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
}
