import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'address_form.dart';

// ---------------------------------------------------------------------------
// CustomerForm — nested composition used by Demos B and C
// ---------------------------------------------------------------------------

/// Customer record with nested billing and shipping addresses.
///
/// Fields are declared at the class level and pass `form: this`, so the
/// field's basePath anchors on this form's own basePath — e.g.
/// `demoC.customer.fullName`.
///
/// Nested `AddressForm` children are built inside [createFormElements]
/// (rather than at their declaration site) for a separate reason:
/// passing `parent: this` would expose the parent-form reference through
/// TomClass reflection, creating a `member <-> parent` cycle that blows
/// the stack on the first `TomClass.mute()` walk. Instantiating them
/// inside the form's own scope (pushed by
/// `TomForm.prepareForSelfObservation`) gives each address section the
/// right `demoC.customer.billing` / `demoC.customer.shipping` basePath
/// without ever handing it a parent-form reference.
@tomReflector
class CustomerForm extends TomForm<TomClass> {
  final TomAuthorizationGroup? billingGroup;
  final TomAuthorizationGroup? shippingGroup;

  CustomerForm({this.billingGroup, this.shippingGroup})
    : super(formId: 'customer');

  late final fullName = TomFormStringInput(
    'fullName',
    '',
    form: this,
    validators: [Validators.required(), Validators.minLength(2)],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    validators: [Validators.required(), Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    form: this,
    keyboardType: TextInputType.phone,
  );

  late final customerTier = TomFormStringDropdown(
    'customerTier',
    'standard',
    form: this,
    source: _tierSource,
    validators: [Validators.required()],
  );

  /// Classic field mixed alongside new spec-conforming fields. Demo C
  /// exposes this to demonstrate Classic ↔ new field coexistence inside
  /// the same form.
  // ignore: deprecated_member_use
  late final notes = TomFormStringInputClassic(
    'notes',
    '',
    form: this,
    labelText: 'Customer notes (Classic)',
    hintText: 'Free-form notes — rendered by the legacy Classic field',
  );

  // Nested forms — created in createFormElements, see class doc for why.
  late AddressForm billing;
  late AddressForm shipping;

  @override
  void createFormElements() {
    billing = AddressForm(tomId: 'billing', authGroup: billingGroup);
    shipping = AddressForm(tomId: 'shipping', authGroup: shippingGroup);
  }
}

final _tierSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'standard', label: 'Standard'),
  const SelectableItem(value: 'silver', label: 'Silver'),
  const SelectableItem(value: 'gold', label: 'Gold'),
  const SelectableItem(value: 'platinum', label: 'Platinum'),
]);
