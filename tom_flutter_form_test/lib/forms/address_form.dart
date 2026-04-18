import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// AddressForm — reusable nested form for billing / shipping
// ---------------------------------------------------------------------------

/// Reusable nested postal-address form.
///
/// Consumers instantiate with a `fieldId` such as `billing` or `shipping`.
/// The form tree (`customer.billing`, `customer.shipping`) mirrors the
/// state tree on `CustomerProfile`.
///
/// Fields are created inside [createFormElements] so they pick up the
/// form's own scope (outer.formId) when their `basePath` is built —
/// without that, late-final fields would init under the outer scope only
/// and billing/shipping sections would clash on identical basePaths.
@tomReflector
class AddressForm extends TomForm<TomClass> {
  AddressForm({
    required String fieldId,
    TomForm<TomClass>? parent,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: fieldId, parentForm: parent) {
    authorizationGroup = authGroup;
  }

  late final TomFormStringInput street;
  late final TomFormStringInput city;
  late final TomFormStringInput state;
  late final TomFormStringInput zipCode;
  late final TomFormStringDropdown country;

  @override
  void createFormElements() {
    street = TomFormStringInput(
      'street',
      '',
      validators: [Validators.required()],
    );
    city = TomFormStringInput(
      'city',
      '',
      validators: [Validators.required()],
    );
    state = TomFormStringInput('state', '');
    zipCode = TomFormStringInput(
      'zipCode',
      '',
      validators: [Validators.required()],
      keyboardType: TextInputType.text,
    );
    country = TomFormStringDropdown(
      'country',
      'US',
      source: countrySource,
      validators: [Validators.required()],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared selection source for the address `country` field.
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
