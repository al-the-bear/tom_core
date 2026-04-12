import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Industry Selection Source
// ---------------------------------------------------------------------------

final industrySource = StaticSelectableSource<String>([
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

final countrySource = StaticSelectableSource<String>([
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

final timezoneSource = StaticSelectableSource<String>([
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

final notificationFrequencySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'realtime', label: 'Real-time'),
  const SelectableItem(value: 'hourly', label: 'Hourly digest'),
  const SelectableItem(value: 'daily', label: 'Daily digest'),
  const SelectableItem(value: 'weekly', label: 'Weekly digest'),
]);

// ---------------------------------------------------------------------------
// Slow Validators (demonstrates async validation)
// ---------------------------------------------------------------------------

/// Simulates server-side validation checking if a tax ID is already taken.
final taxIdValidator = SlowValidator<String>((value) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  // Simulate: tax IDs starting with 'X' are already taken
  if (value.startsWith('X')) {
    return const ValidationError('taxIdTaken');
  }
  return const ValidationSuccess();
});

/// Simulates checking if an email domain has valid MX records.
final emailDomainValidator = SlowValidator<String>((value) async {
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
    labelTextOverride: 'Company Name',
    hintTextOverride: 'Enter company name',
    validators: [Validators.required(), Validators.minLength(2)],
  );

  /// Industry dropdown selection.
  late final industry = TomFormStringDropdown(
    'industry',
    '',
    source: industrySource,
    labelTextOverride: 'Industry',
    hintTextOverride: 'Select industry',
    validators: [Validators.required()],
  );

  /// Tax ID with slow validation (simulates server check).
  late final taxId = TomFormStringInput(
    'taxId',
    '',
    labelTextOverride: 'Tax ID',
    hintTextOverride: 'Enter tax identification number',
    descriptionTextOverride: 'Unique tax identification number',
    validators: [
      Validators.required(),
      Validators.pattern(RegExp(r'^[A-Z0-9-]+$'), errorKey: 'taxIdFormat'),
      taxIdValidator,
    ],
  );

  /// Website URL with pattern validation.
  late final website = TomFormStringInput(
    'website',
    '',
    labelTextOverride: 'Website',
    hintTextOverride: 'https://example.com',
    validators: [
      Validators.pattern(
        RegExp(r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
        errorKey: 'invalidUrl',
      ),
    ],
    keyboardType: TextInputType.url,
  );

  /// Description with maxLength.
  late final description = TomFormStringInput(
    'description',
    '',
    labelTextOverride: 'Description',
    hintTextOverride: 'Brief company description',
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
    required String fieldId,
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: fieldId, parentForm: parent) {
    authorizationGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final street = TomFormStringInput(
    'street',
    '',
    labelTextOverride: 'Street Address',
    hintTextOverride: 'Enter street address',
    validators: [Validators.required()],
  );

  late final street2 = TomFormStringInput(
    'street2',
    '',
    labelTextOverride: 'Street Address 2',
    hintTextOverride: 'Apt, Suite, Unit, etc. (optional)',
  );

  late final city = TomFormStringInput(
    'city',
    '',
    labelTextOverride: 'City',
    hintTextOverride: 'Enter city',
    validators: [Validators.required()],
  );

  late final state = TomFormStringInput(
    'state',
    '',
    labelTextOverride: 'State/Province',
    hintTextOverride: 'Enter state or province',
  );

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    labelTextOverride: 'ZIP/Postal Code',
    hintTextOverride: 'Enter ZIP or postal code',
    validators: [Validators.required()],
    keyboardType: TextInputType.text,
  );

  late final country = TomFormStringDropdown(
    'country',
    'US',
    source: countrySource,
    labelTextOverride: 'Country',
    validators: [Validators.required()],
  );
}

// ---------------------------------------------------------------------------
// Person Form — Reusable nested form for CEO, managers, etc.
// ---------------------------------------------------------------------------

@tomReflector
class PersonForm extends TomForm<Person> {
  PersonForm({
    required String fieldId,
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: fieldId, parentForm: parent) {
    authorizationGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final firstName = TomFormStringInput(
    'firstName',
    '',
    labelTextOverride: 'First Name',
    hintTextOverride: 'Enter first name',
    validators: [Validators.required()],
  );

  late final lastName = TomFormStringInput(
    'lastName',
    '',
    labelTextOverride: 'Last Name',
    hintTextOverride: 'Enter last name',
    validators: [Validators.required()],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    labelTextOverride: 'Email',
    hintTextOverride: 'Enter email address',
    validators: [Validators.required(), Validators.email(), emailDomainValidator],
    keyboardType: TextInputType.emailAddress,
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    labelTextOverride: 'Phone',
    hintTextOverride: 'Enter phone number',
    keyboardType: TextInputType.phone,
  );

  late final title = TomFormStringInput(
    'title',
    '',
    labelTextOverride: 'Job Title',
    hintTextOverride: 'Enter job title',
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
    source: timezoneSource,
    labelTextOverride: 'Timezone',
  );

  late final locale = TomFormStringInput(
    'locale',
    'en_US',
    labelTextOverride: 'Locale',
    hintTextOverride: 'e.g., en_US, de_DE',
    validators: [
      Validators.pattern(RegExp(r'^[a-z]{2}_[A-Z]{2}$'), errorKey: 'invalidLocale'),
    ],
  );

  late final currency = TomFormStringInput(
    'currency',
    'USD',
    labelTextOverride: 'Currency',
    hintTextOverride: 'e.g., USD, EUR, GBP',
    validators: [
      Validators.required(),
      Validators.pattern(RegExp(r'^[A-Z]{3}$'), errorKey: 'invalidCurrency'),
    ],
  );

  late final dateFormat = TomFormStringInput(
    'dateFormat',
    'yyyy-MM-dd',
    labelTextOverride: 'Date Format',
    hintTextOverride: 'e.g., yyyy-MM-dd, MM/dd/yyyy',
  );

  late final notificationEmail = TomFormStringInput(
    'notificationEmail',
    '',
    labelTextOverride: 'Notification Email',
    hintTextOverride: 'Email for notifications',
    validators: [Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final notificationFrequency = TomFormStringDropdown(
    'notificationFrequency',
    'daily',
    source: notificationFrequencySource,
    labelTextOverride: 'Notification Frequency',
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
  late final headquarters = AddressForm(fieldId: 'headquarters');
  late final ceo = PersonForm(fieldId: 'ceo');
  late final settings = CompanySettingsForm();
}
