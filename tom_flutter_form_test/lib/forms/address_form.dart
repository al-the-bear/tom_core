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
  AddressForm({
    required String tomId,
    TomAuthorizationGroup? authGroup,
  }) : super(formId: tomId) {
    authorizationGroup = authGroup;
  }

  @override
  void createFormElements() {}

  late final street = TomFormStringInput(
    'street',
    '',
    form: this,
    validators: [Validators.required()],
  );

  late final city = TomFormStringInput(
    'city',
    '',
    form: this,
    validators: [Validators.required()],
  );

  late final state = TomFormStringInput(
    'state',
    '',
    form: this,
  );

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    form: this,
    validators: [Validators.required()],
    keyboardType: TextInputType.text,
  );

  late final country = TomFormStringDropdown(
    'country',
    'US',
    form: this,
    source: _countrySource,
    validators: [Validators.required()],
  );
}

// ---------------------------------------------------------------------------
// Shared selection source for the address `country` field.
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
