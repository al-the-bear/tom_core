import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'address_form.dart';

// ---------------------------------------------------------------------------
// CustomerForm — nested composition used by Demos B and C
// ---------------------------------------------------------------------------

/// Customer record with nested billing and shipping addresses.
///
/// Nested-form identity path: `customer.billing.*`, `customer.shipping.*`.
/// Mirrors the shape of `CustomerProfile` so `bind(customer)` round-trips.
///
/// Demos B and C both instantiate this form — Demo B attaches a per-section
/// `TomAuthorizationGroup` so authorization panels can control billing and
/// shipping as units. Demo C wraps each section in its own
/// `TomFormStyleScope` to demonstrate per-section theming.
@tomReflector
class CustomerForm extends TomForm<TomClass> {
  final TomAuthorizationGroup? billingGroup;
  final TomAuthorizationGroup? shippingGroup;

  CustomerForm({this.billingGroup, this.shippingGroup})
      : super(formId: 'customer');

  @override
  void createFormElements() {}

  // --- Top-level fields -----------------------------------------------------

  late final fullName = TomFormStringInput(
    'fullName',
    '',
    validators: [Validators.required(), Validators.minLength(2)],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    validators: [Validators.required(), Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    keyboardType: TextInputType.phone,
  );

  late final customerTier = TomFormStringDropdown(
    'customerTier',
    'standard',
    source: _tierSource,
    validators: [Validators.required()],
  );

  /// Classic field mixed alongside new spec-conforming fields. Demo C exposes
  /// this to demonstrate Classic ↔ new field coexistence inside the same
  /// form.
  // ignore: deprecated_member_use
  late final notes = TomFormStringInputClassic(
    'notes',
    '',
    labelText: 'Customer notes (Classic)',
    hintText: 'Free-form notes — rendered by the legacy Classic field',
  );

  // --- Nested address forms -------------------------------------------------

  late final billing = AddressForm(
    fieldId: 'billing',
    parent: this,
    authGroup: billingGroup,
  );

  late final shipping = AddressForm(
    fieldId: 'shipping',
    parent: this,
    authGroup: shippingGroup,
  );
}

final _tierSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'standard', label: 'Standard'),
  const SelectableItem(value: 'silver', label: 'Silver'),
  const SelectableItem(value: 'gold', label: 'Gold'),
  const SelectableItem(value: 'platinum', label: 'Platinum'),
]);
