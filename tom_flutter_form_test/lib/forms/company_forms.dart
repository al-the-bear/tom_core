import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Industry Selection Source
// ---------------------------------------------------------------------------

final _industrySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'tech', label: 'Technology'),
  const SelectableItem(value: 'finance', label: 'Finance'),
  const SelectableItem(value: 'healthcare', label: 'Healthcare'),
  const SelectableItem(value: 'manufacturing', label: 'Manufacturing'),
  const SelectableItem(value: 'retail', label: 'Retail'),
  const SelectableItem(value: 'other', label: 'Other'),
]);

// ---------------------------------------------------------------------------
// Country Selection Source
// ---------------------------------------------------------------------------

final _countrySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'US', label: 'United States'),
  const SelectableItem(value: 'CA', label: 'Canada'),
  const SelectableItem(value: 'GB', label: 'United Kingdom'),
  const SelectableItem(value: 'DE', label: 'Germany'),
  const SelectableItem(value: 'FR', label: 'France'),
  const SelectableItem(value: 'JP', label: 'Japan'),
  const SelectableItem(value: 'AU', label: 'Australia'),
]);

// ---------------------------------------------------------------------------
// Timezone Selection Source
// ---------------------------------------------------------------------------

final _timezoneSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'UTC', label: 'UTC'),
  const SelectableItem(
    value: 'America/New_York',
    label: 'Eastern Time (US)',
    description: 'UTC-5',
  ),
  const SelectableItem(
    value: 'America/Los_Angeles',
    label: 'Pacific Time (US)',
    description: 'UTC-8',
  ),
  const SelectableItem(
    value: 'Europe/London',
    label: 'London',
    description: 'UTC+0',
  ),
  const SelectableItem(
    value: 'Europe/Berlin',
    label: 'Berlin',
    description: 'UTC+1',
  ),
  const SelectableItem(
    value: 'Asia/Tokyo',
    label: 'Tokyo',
    description: 'UTC+9',
  ),
]);

// ---------------------------------------------------------------------------
// Notification Frequency Source
// ---------------------------------------------------------------------------

final _notificationFrequencySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'realtime', label: 'Real-time'),
  const SelectableItem(value: 'hourly', label: 'Hourly digest'),
  const SelectableItem(value: 'daily', label: 'Daily digest'),
  const SelectableItem(value: 'weekly', label: 'Weekly digest'),
]);

// ---------------------------------------------------------------------------
// Slow Validators (demonstrates async validation)
// ---------------------------------------------------------------------------

/// Simulates server-side validation checking if a tax ID is already taken.
final _taxIdValidator = SlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  // Simulate: tax IDs starting with 'X' are already taken
  if (value.startsWith('X')) {
    return const ValidationError('taxIdTaken');
  }
  return const ValidationSuccess();
});

/// Simulates checking if an email domain has valid MX records.
final _emailDomainValidator = SlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(milliseconds: 800));
  // Simulate: test.invalid domain always fails
  if (value.endsWith('@test.invalid')) {
    return const ValidationError('invalidEmailDomain');
  }
  return const ValidationSuccess();
});

// ---------------------------------------------------------------------------
// Company Basic Info Form — Demonstrates authorization, slow validation
// ---------------------------------------------------------------------------

@tomReflector
class CompanyBasicInfoForm extends TomForm<CompanyProfile> {
  CompanyBasicInfoForm({TomAuthorizationGroup? authGroup})
      : super(formId: 'companyBasicInfo') {
    authorizationGroup = authGroup;
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
    validators: [Validators.required(), Validators.minLength(2)],
  );

  /// Industry dropdown selection.
  late final industry = TomFormStringDropdown(
    'industry',
    '',
    source: _industrySource,
    validators: [Validators.required()],
  );

  /// Tax ID with slow validation (simulates server check).
  late final taxId = TomFormStringInput(
    'taxId',
    '',
    validators: [
      Validators.required(),
      Validators.pattern(RegExp(r'^[A-Z0-9-]+$'), errorKey: 'taxIdFormat'),
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
      Validators.pattern(
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
    validators: [Validators.maxLength(500)],
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
    authorizationGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final street = TomFormStringInput(
    'street',
    '',
    validators: [Validators.required()],
  );

  late final street2 = TomFormStringInput(
    'street2',
    '',
  );

  late final city = TomFormStringInput(
    'city',
    '',
    validators: [Validators.required()],
  );

  late final state = TomFormStringInput(
    'state',
    '',
  );

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    validators: [Validators.required()],
    keyboardType: TextInputType.text,
  );

  late final country = TomFormStringDropdown(
    'country',
    'US',
    source: _countrySource,
    validators: [Validators.required()],
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
    authorizationGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final firstName = TomFormStringInput(
    'firstName',
    '',
    validators: [Validators.required()],
  );

  late final lastName = TomFormStringInput(
    'lastName',
    '',
    validators: [Validators.required()],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    validators: [Validators.required(), Validators.email(), _emailDomainValidator],
    keyboardType: TextInputType.emailAddress,
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    keyboardType: TextInputType.phone,
  );

  late final title = TomFormStringInput(
    'title',
    '',
  );
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
    authorizationGroup = authGroup;
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
      Validators.pattern(RegExp(r'^[a-z]{2}_[A-Z]{2}$'), errorKey: 'invalidLocale'),
    ],
  );

  late final currency = TomFormStringInput(
    'currency',
    'USD',
    validators: [
      Validators.required(),
      Validators.pattern(RegExp(r'^[A-Z]{3}$'), errorKey: 'invalidCurrency'),
    ],
  );

  late final dateFormat = TomFormStringInput(
    'dateFormat',
    'yyyy-MM-dd',
  );

  late final notificationEmail = TomFormStringInput(
    'notificationEmail',
    '',
    validators: [Validators.email()],
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
