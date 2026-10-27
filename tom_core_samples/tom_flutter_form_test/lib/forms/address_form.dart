import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// AddressForm — reusable nested form for billing / shipping
// ---------------------------------------------------------------------------

/// Reusable nested postal-address form.
///
/// Field declarations pass `form: this`, so their basePath anchors on
/// whatever path this AddressForm instance lives at — e.g.
/// `demoC.customer.billing.street` or `demoC.customer.shipping.street`.
@tomReflector
class AddressForm extends TomForm<TomClass> {
  AddressForm({required String tomId, TomAuthorizationGroup? authGroup})
    : super(formId: tomId) {
    tomGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final street = TomFormStringInput(
    'street',
    '',
    form: this,
    validators: [TomValidators.required()],
  );

  late final city = TomFormStringInput(
    'city',
    '',
    form: this,
    validators: [TomValidators.required()],
  );

  late final state = TomFormStringInput('state', '', form: this);

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    form: this,
    validators: [TomValidators.required()],
    keyboardType: TextInputType.text,
  );

  late final country = TomFormStringDropdown(
    'country',
    'US',
    form: this,
    source: _countrySource,
    validators: [TomValidators.required()],
  );
}

// ---------------------------------------------------------------------------
// Shared selection source for the address `country` field.
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
