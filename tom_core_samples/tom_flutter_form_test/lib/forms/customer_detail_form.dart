import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase2a_state.dart';

// ---------------------------------------------------------------------------
// CustomerDetailForm — used by Demo H-A (Master-Detail).
// ---------------------------------------------------------------------------

/// Detail form for Demo H-A's `tom_flutter_ui` master-detail pattern.
///
/// Exercises `TomFormStringInput` / `TomFormStringDropdown` fields with a
/// stable `formId`: the SAME `customerDetail` form instance is re-bound to a
/// different [Customer] every time the master selection changes. Only the
/// data binding moves — the form identity, resources, and authorization
/// stay constant — the form-identity-in-master-detail pattern.
@tomReflector
class CustomerDetailForm extends TomForm<Customer> {
  CustomerDetailForm() : super(formId: 'customerDetail');

  late final fullName = TomFormStringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    validators: [TomValidators.required(), TomValidators.minLength(2)],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    keyboardType: TextInputType.emailAddress,
    validators: [TomValidators.required(), TomValidators.email()],
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    form: this,
    labelTextOverride: 'Phone',
    keyboardType: TextInputType.phone,
  );

  late final company = TomFormStringInput(
    'company',
    '',
    form: this,
    labelTextOverride: 'Company',
  );

  late final tier = TomFormStringDropdown(
    'tier',
    'standard',
    form: this,
    source: _tierSource,
    validators: [TomValidators.required()],
  );

  @override
  void createFormElements() {
    // All fields declared at class level with `form: this` — nothing to
    // build inside the form's scope here.
  }
}

final _tierSource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'standard', label: 'Standard'),
  const TomSelectableItem(value: 'silver', label: 'Silver'),
  const TomSelectableItem(value: 'gold', label: 'Gold'),
  const TomSelectableItem(value: 'platinum', label: 'Platinum'),
]);
