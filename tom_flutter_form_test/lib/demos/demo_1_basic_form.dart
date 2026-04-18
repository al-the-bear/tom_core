import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/form_actions.dart';
import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 1: Basic Form — Company Info
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - TomForm bound to global [demoState]
/// - TomFormStringInput and TomFormStringDropdown usage
/// - Required, minLength, maxLength, pattern validators
/// - SlowValidator with pending spinner (Tax ID field)
/// - ACL layout with append(), newRow(), gap()
/// - Resources: title / padding / borderStyle / field labels resolved from
///   demo_resources.json (scope: companyBasicInfo)
/// - Save / Discard via [SaveFormAction] / [DiscardFormAction]
/// - Button labels and status card text resolved from resources (demo1.*)
/// - Status card rebuilt by [TomMultiObservableBuilder] (no setState)
class Demo1BasicForm extends StatefulWidget {
  const Demo1BasicForm({super.key});

  @override
  State<Demo1BasicForm> createState() => _Demo1BasicFormState();
}

class _Demo1BasicFormState extends State<Demo1BasicForm> {
  late final CompanyBasicInfoForm _form;
  final _status = TomString('Ready');

  late final _controller = TomActionController(controllerId: 'demo1');
  late final _save = SaveFormAction(_controller, forms: [_form], status: _status);
  late final _discard = DiscardFormAction(_controller, forms: [_form], status: _status);

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('companyBasicInfo', () => CompanyBasicInfoForm());
    _form.bind(demoState.companyProfile);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'basicForm',
      elementProvider: _form,
    )
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .setAclDefaultAppendGap(0)
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.industry.widget)
        .addRowBreakpoint(atWidth: 400)
        .append((p) => p.taxId.widget, dist: 16)
        .newRow()
        .append((p) => p.website.widget)
        .newRow()
        .append((p) => p.description.widget)
        .build(context);

    return DemoScaffold(
      title: 'Demo 1: Basic Form',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TomFormStyleScope(
              style: TomFormStyle.material3,
              child: formLayout,
            ),
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
              listenable: _form.changes,
              builder: (context, _) => TomMultiObservableBuilder(
                observables: [_status],
                builder: (context) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${TomCtr.text('demo1.status', 'label')}: ${_status.get()}'),
                        const SizedBox(height: 4),
                        Text('${TomCtr.text('demo1.status', 'dirty')}: ${_form.isDirty}'),
                        Text('${TomCtr.text('demo1.status', 'valid')}: ${_form.isValid}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
