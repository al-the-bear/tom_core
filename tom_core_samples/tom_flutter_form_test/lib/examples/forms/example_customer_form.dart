import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../state/phase2a_state.dart';

/// Family-agnostic form for a single [Customer].
///
/// All fields are produced through [TomFormFieldFamily] factories so the same
/// form class works for both Material and Cupertino — the only difference
/// between the two example screens is the `family` value passed in here.
///
/// Resource paths follow the `exampleCustomer.*` convention so the static
/// resource map in `examples/shared/example_resources.dart` and the static
/// authorization map in `examples/shared/example_authorization.dart` resolve
/// labels and per-field auth automatically.
///
/// The `example` prefix is part of the id rather than a scope above it
/// because a form id *is* a scope id, and a scope id may not contain the
/// '.' that scope paths are joined with — `TomScopeBase(scopeId: 'a.b')`
/// would otherwise address the same resources as the unrelated chain
/// 'a' → 'b'.
@tomReflector
class ExampleCustomerForm extends TomForm<Customer> {
  ExampleCustomerForm({required TomFormFieldFamily family})
    : _family = family,
      super(formId: 'exampleCustomer');

  final TomFormFieldFamily _family;

  late final fullName = _family.stringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    validators: [TomValidators.required(), TomValidators.minLength(2)],
  );

  late final email = _family.stringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    validators: [TomValidators.required(), TomValidators.email()],
  );

  late final phone = _family.stringInput(
    'phone',
    '',
    form: this,
    labelTextOverride: 'Phone',
  );

  late final company = _family.stringInput(
    'company',
    '',
    form: this,
    labelTextOverride: 'Company',
  );

  /// Tier picker — modelled as a search-style picker over a small static
  /// source so both Material and Cupertino render natively without needing
  /// a family-specific dropdown widget.
  late final tier = _family.searchInput<String>(
    'tier',
    '',
    form: this,
    source: _tierSource,
    labelTextOverride: 'Tier',
    validators: [TomValidators.required()],
  );

  @override
  void createFormElements() {}
}

final _tierSource = TomStaticSelectableSource<String>(const [
  TomSelectableItem(value: 'standard', label: 'Standard'),
  TomSelectableItem(value: 'silver', label: 'Silver'),
  TomSelectableItem(value: 'gold', label: 'Gold'),
  TomSelectableItem(value: 'platinum', label: 'Platinum'),
]);

/// `TomListForm` that owns a list of [Customer] records and produces an
/// [ExampleCustomerForm] of the chosen family for each row.
@tomReflector
class ExampleCustomerListForm
    extends TomListForm<Customer, ExampleCustomerForm> {
  ExampleCustomerListForm({required TomFormFieldFamily family})
    : super(
        listId: 'exampleCustomer',
        formFactory: (_) => ExampleCustomerForm(family: family),
      );

  @override
  Customer createItem() {
    final c = Customer();
    c.fullName | 'New customer';
    c.email | '';
    c.phone | '';
    c.company | '';
    c.tier | 'standard';
    return c;
  }
}
