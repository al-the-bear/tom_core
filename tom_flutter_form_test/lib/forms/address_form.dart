import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// AddressForm — reusable nested form for billing / shipping
// ---------------------------------------------------------------------------

/// Reusable nested postal-address form.
///
/// Consumers instantiate with a `fieldId` such as `billing` or `shipping`;
/// the same class therefore drives both sections of [CustomerForm]. The
/// form tree (`customer.billing`, `customer.shipping`) deliberately mirrors
/// the state tree on [CustomerProfile].
@tomReflector
class AddressForm extends TomForm<TomClass> {
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
    validators: [Validators.required()],
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
    source: countrySource,
    validators: [Validators.required()],
  );
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
