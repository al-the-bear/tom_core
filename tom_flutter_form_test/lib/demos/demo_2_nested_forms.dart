import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/form_actions.dart';
import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 2: Nested Forms — Address + Person
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - Nested forms (AddressForm, PersonForm) each bound to a sub-tree of
///   the global [demoState]
/// - Multiple ACL sections in one view, titles/padding from resources
/// - Field labels/hints resolved from resources (scopes: address, person)
/// - Combined save via [SaveFormAction] accepting multiple forms
/// - Button labels and status card text resolved from resources (demo2.*)
/// - Status rebuilt by [TomMultiObservableBuilder] (no setState)
class Demo2NestedForms extends StatefulWidget {
  const Demo2NestedForms({super.key});

  @override
  State<Demo2NestedForms> createState() => _Demo2NestedFormsState();
}

class _Demo2NestedFormsState extends State<Demo2NestedForms> {
  late final AddressForm _addressForm;
  late final PersonForm _ceoForm;
  final _status = TomString('Ready');

  late final _controller = TomActionController(controllerId: 'demo2');
  late final _save = SaveFormAction(
    _controller,
    forms: [_addressForm, _ceoForm],
    status: _status,
  );
  late final _discard = DiscardFormAction(
    _controller,
    forms: [_addressForm, _ceoForm],
    status: _status,
  );

  @override
  void initState() {
    super.initState();
    _addressForm = TomScope.withScope('address', () => AddressForm(fieldId: 'headquarters'));
    _ceoForm = TomScope.withScope('person', () => PersonForm(fieldId: 'ceo'));
    _addressForm.bind(demoState.companyProfile.headquarters);
    _ceoForm.bind(demoState.companyProfile.ceo);
  }

  @override
  void dispose() {
    _addressForm.dispose();
    _ceoForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addressLayout = TomAclBuilder(
      id: 'addressSection',
      elementProvider: _addressForm,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.street2.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.state.widget, dist: 16)
        .append((p) => p.zipCode.widget, dist: 16)
        .newRow()
        .append((p) => p.country.widget)
        .build(context);

    final ceoLayout = TomAclBuilder(
      id: 'ceoSection',
      elementProvider: _ceoForm,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.firstName.widget)
        .append((p) => p.lastName.widget, dist: 16)
        .newRow()
        .append((p) => p.email.widget)
        .append((p) => p.phone.widget, dist: 16)
        .newRow()
        .append((p) => p.title.widget)
        .build(context);

    return DemoScaffold(
      title: 'Demo 2: Nested Forms',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TomFormStyleScope(
          style: TomFormStyle.material3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              addressLayout,
              const SizedBox(height: 16),
              ceoLayout,
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _discard.execute(
                      TomActionContext(),
                      TomActionTransaction(label: 'discard'),
                    ),
                    child: Text(_discard.label),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _save.execute(
                      TomActionContext(),
                      TomActionTransaction(label: 'save'),
                    ),
                    child: Text(_save.label),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Listenable.merge(
                    [_addressForm.changes, _ceoForm.changes]),
                builder: (context, _) => TomMultiObservableBuilder(
                  observables: [_status],
                  builder: (context) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${TomCtr.text('demo2.status', 'label')}: ${_status.get()}'),
                          const SizedBox(height: 4),
                          Text('${TomCtr.text('demo2.status', 'addressDirty')}: ${_addressForm.isDirty}'),
                          Text('${TomCtr.text('demo2.status', 'ceoDirty')}: ${_ceoForm.isDirty}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
