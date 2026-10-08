import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Industry Selection Source
// ---------------------------------------------------------------------------

final _industrySource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'tech', label: 'Technology'),
  const TomSelectableItem(value: 'finance', label: 'Finance'),
  const TomSelectableItem(value: 'healthcare', label: 'Healthcare'),
  const TomSelectableItem(value: 'manufacturing', label: 'Manufacturing'),
  const TomSelectableItem(value: 'retail', label: 'Retail'),
  const TomSelectableItem(value: 'other', label: 'Other'),
]);

// ---------------------------------------------------------------------------
// Country Selection Source
// ---------------------------------------------------------------------------

final _countrySource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'US', label: 'United States'),
  const TomSelectableItem(value: 'CA', label: 'Canada'),
  const TomSelectableItem(value: 'GB', label: 'United Kingdom'),
  const TomSelectableItem(value: 'DE', label: 'Germany'),
  const TomSelectableItem(value: 'FR', label: 'France'),
  const TomSelectableItem(value: 'JP', label: 'Japan'),
  const TomSelectableItem(value: 'AU', label: 'Australia'),
]);

// ---------------------------------------------------------------------------
// Timezone Selection Source
// ---------------------------------------------------------------------------

final _timezoneSource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'UTC', label: 'UTC'),
  const TomSelectableItem(
    value: 'America/New_York',
    label: 'Eastern Time (US)',
    description: 'UTC-5',
  ),
  const TomSelectableItem(
    value: 'America/Los_Angeles',
    label: 'Pacific Time (US)',
    description: 'UTC-8',
  ),
  const TomSelectableItem(
    value: 'Europe/London',
    label: 'London',
    description: 'UTC+0',
  ),
  const TomSelectableItem(
    value: 'Europe/Berlin',
    label: 'Berlin',
    description: 'UTC+1',
  ),
  const TomSelectableItem(
    value: 'Asia/Tokyo',
    label: 'Tokyo',
    description: 'UTC+9',
  ),
]);

// ---------------------------------------------------------------------------
// Notification Frequency Source
// ---------------------------------------------------------------------------

final _notificationFrequencySource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'realtime', label: 'Real-time'),
  const TomSelectableItem(value: 'hourly', label: 'Hourly digest'),
  const TomSelectableItem(value: 'daily', label: 'Daily digest'),
  const TomSelectableItem(value: 'weekly', label: 'Weekly digest'),
]);

// ---------------------------------------------------------------------------
// Slow TomValidators (demonstrates async validation)
// ---------------------------------------------------------------------------

/// Simulates server-side validation checking if a tax ID is already taken.
final _taxIdValidator = TomSlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  // Simulate: tax IDs starting with 'X' are already taken
  if (value.startsWith('X')) {
    return const TomValidationError('taxIdTaken');
  }
  return const TomValidationSuccess();
});

/// Simulates checking if an email domain has valid MX records.
final _emailDomainValidator = TomSlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(milliseconds: 800));
  // Simulate: test.invalid domain always fails
  if (value.endsWith('@test.invalid')) {
    return const TomValidationError('invalidEmailDomain');
  }
  return const TomValidationSuccess();
});

// ---------------------------------------------------------------------------
// Company Basic Info Form — Demonstrates authorization, slow validation
// ---------------------------------------------------------------------------

@tomReflector
class CompanyBasicInfoForm extends TomForm<CompanyProfile> {
  CompanyBasicInfoForm({TomAuthorizationGroup? authGroup})
    : super(formId: 'companyBasicInfo') {
    tomGroup = authGroup;
  }

  @override
  void createFormElements() {
    // Fields are created inside the form's scope for proper resource resolution
  }

  // --- Fields ---

  /// Required company name.
  late final name = TomFormStringInput(
    'name',
    '',
    validators: [TomValidators.required(), TomValidators.minLength(2)],
  );

  /// Industry dropdown selection.
  late final industry = TomFormStringDropdown(
    'industry',
    '',
    source: _industrySource,
    validators: [TomValidators.required()],
  );

  /// Tax ID with slow validation (simulates server check).
  late final taxId = TomFormStringInput(
    'taxId',
    '',
    validators: [
      TomValidators.required(),
      TomValidators.pattern(RegExp(r'^[A-Z0-9-]+$'), errorKey: 'taxIdFormat'),
      _taxIdValidator,
    ],
  );

  /// Website URL with pattern validation.
  ///
  /// Requires a full http(s) URL with a dotted domain whose labels don't
  /// start or end with a hyphen, a TLD of at least two letters, an optional
  /// port (1-5 digits), and an optional path/query/fragment with no
  /// whitespace. Anchored with `$` so trailing garbage is rejected.
  late final website = TomFormStringInput(
    'website',
    '',
    validators: [
      TomValidators.pattern(
        RegExp(
          r'^https?:\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
          r'[a-zA-Z]{2,}(?::\d{1,5})?(?:\/[^\s]*)?$',
        ),
        errorKey: 'invalidUrl',
      ),
    ],
    keyboardType: TextInputType.url,
  );

  /// Description with maxLength.
  late final description = TomFormStringInput(
    'description',
    '',
    maxLength: 500,
    maxLines: 4,
    validators: [TomValidators.maxLength(500)],
  );
}

// ---------------------------------------------------------------------------
// Address Form — Reusable nested form
// ---------------------------------------------------------------------------

@tomReflector
class AddressForm extends TomForm<Address> {
  AddressForm({
    required String tomId,
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: tomId, parentForm: parent) {
    tomGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final street = TomFormStringInput(
    'street',
    '',
    validators: [TomValidators.required()],
  );

  late final street2 = TomFormStringInput('street2', '');

  late final city = TomFormStringInput(
    'city',
    '',
    validators: [TomValidators.required()],
  );

  late final state = TomFormStringInput('state', '');

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    validators: [TomValidators.required()],
    keyboardType: TextInputType.text,
  );

  late final country = TomFormStringDropdown(
    'country',
    'US',
    source: _countrySource,
    validators: [TomValidators.required()],
  );
}

// ---------------------------------------------------------------------------
// Person Form — Reusable nested form for CEO, managers, etc.
// ---------------------------------------------------------------------------

@tomReflector
class PersonForm extends TomForm<Person> {
  PersonForm({
    required String tomId,
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: tomId, parentForm: parent) {
    tomGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final firstName = TomFormStringInput(
    'firstName',
    '',
    validators: [TomValidators.required()],
  );

  late final lastName = TomFormStringInput(
    'lastName',
    '',
    validators: [TomValidators.required()],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    validators: [
      TomValidators.required(),
      TomValidators.email(),
      _emailDomainValidator,
    ],
    keyboardType: TextInputType.emailAddress,
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    keyboardType: TextInputType.phone,
  );

  late final title = TomFormStringInput('title', '');
}

// ---------------------------------------------------------------------------
// Settings Form — Nested form with dropdowns
// ---------------------------------------------------------------------------

@tomReflector
class CompanySettingsForm extends TomForm<CompanySettings> {
  CompanySettingsForm({
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: 'settings', parentForm: parent) {
    tomGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final timezone = TomFormStringDropdown(
    'timezone',
    'UTC',
    source: _timezoneSource,
  );

  late final locale = TomFormStringInput(
    'locale',
    'en_US',
    validators: [
      TomValidators.pattern(
        RegExp(r'^[a-z]{2}_[A-Z]{2}$'),
        errorKey: 'invalidLocale',
      ),
    ],
  );

  late final currency = TomFormStringInput(
    'currency',
    'USD',
    validators: [
      TomValidators.required(),
      TomValidators.pattern(RegExp(r'^[A-Z]{3}$'), errorKey: 'invalidCurrency'),
    ],
  );

  late final dateFormat = TomFormStringInput('dateFormat', 'yyyy-MM-dd');

  late final notificationEmail = TomFormStringInput(
    'notificationEmail',
    '',
    validators: [TomValidators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final notificationFrequency = TomFormStringDropdown(
    'notificationFrequency',
    'daily',
    source: _notificationFrequencySource,
  );
}

// ---------------------------------------------------------------------------
// Full Company Profile Form — Composite form with nested forms
// ---------------------------------------------------------------------------

@tomReflector
class CompanyProfileForm extends TomForm<CompanyProfile> {
  CompanyProfileForm() : super(formId: 'companyProfile');

  @override
  void createFormElements() {
    // Nested forms are created in the parent form's scope
  }

  // Nested forms
  late final basicInfo = CompanyBasicInfoForm();
  late final headquarters = AddressForm(tomId: 'headquarters');
  late final ceo = PersonForm(tomId: 'ceo');
  late final settings = CompanySettingsForm();
}
