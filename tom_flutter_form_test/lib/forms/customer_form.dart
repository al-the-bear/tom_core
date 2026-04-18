import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'address_form.dart';

// ---------------------------------------------------------------------------
// CustomerForm — nested composition used by Demos B and C
// ---------------------------------------------------------------------------

/// Customer record with nested billing and shipping addresses.
///
/// Fields are created inside [createFormElements] so their scope includes
/// this form's formId. Without that step, a `late final` field would be
/// lazily initialised outside the form's own scope (under the outer
/// `TomScope.withScope(...)` call only) and its basePath would be
/// `<outerScope>.<fieldId>` — causing the two nested AddressForms
/// (billing + shipping) to collide on identical basePaths.
@tomReflector
class CustomerForm extends TomForm<TomClass> {
  final TomAuthorizationGroup? billingGroup;
  final TomAuthorizationGroup? shippingGroup;

  CustomerForm({this.billingGroup, this.shippingGroup})
      : super(formId: 'customer');

  late final TomFormStringInput fullName;
  late final TomFormStringInput email;
  late final TomFormStringInput phone;
  late final TomFormStringDropdown customerTier;

  /// Classic field mixed alongside new spec-conforming fields. Demo C
  /// exposes this to demonstrate Classic ↔ new field coexistence inside
  /// the same form.
  // ignore: deprecated_member_use
  late final TomFormStringInputClassic notes;

  late final AddressForm billing;
  late final AddressForm shipping;

  @override
  void createFormElements() {
    fullName = TomFormStringInput(
      'fullName',
      '',
      validators: [Validators.required(), Validators.minLength(2)],
    );

    email = TomFormStringInput(
      'email',
      '',
      validators: [Validators.required(), Validators.email()],
      keyboardType: TextInputType.emailAddress,
    );

    phone = TomFormStringInput(
      'phone',
      '',
      keyboardType: TextInputType.phone,
    );

    customerTier = TomFormStringDropdown(
      'customerTier',
      'standard',
      source: _tierSource,
      validators: [Validators.required()],
    );

    // ignore: deprecated_member_use
    notes = TomFormStringInputClassic(
      'notes',
      '',
      labelText: 'Customer notes (Classic)',
      hintText: 'Free-form notes — rendered by the legacy Classic field',
    );

    billing = AddressForm(
      fieldId: 'billing',
      authGroup: billingGroup,
    );

    shipping = AddressForm(
      fieldId: 'shipping',
      authGroup: shippingGroup,
    );
  }
}

final _tierSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'standard', label: 'Standard'),
  const SelectableItem(value: 'silver', label: 'Silver'),
  const SelectableItem(value: 'gold', label: 'Gold'),
  const SelectableItem(value: 'platinum', label: 'Platinum'),
]);
