import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/form_actions.dart';
import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 5: Settings Form — Dropdowns and Compact Layout
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - Multiple TomFormStringDropdown fields
/// - Compact form style (TomFormStyle.compact)
/// - StaticSelectableSource with descriptions (timezone)
/// - Locale / currency pattern validators
/// - Field labels/hints resolved from resources (scope: companySettings)
/// - Container title / padding / borderStyle from resources
/// - Button labels and status card text resolved from resources (demo5.*)
/// - Save / Discard via [SaveFormAction] / [DiscardFormAction]
/// - Status rebuilt by [TomMultiObservableBuilder] (no setState)
class Demo5SettingsForm extends StatefulWidget {
  const Demo5SettingsForm({super.key});

  @override
  State<Demo5SettingsForm> createState() => _Demo5SettingsFormState();
}

class _Demo5SettingsFormState extends State<Demo5SettingsForm> {
  late final CompanySettingsForm _form;
  final _status = TomString('Ready');

  late final _controller = TomActionController(controllerId: 'demo5');
  late final _save = SaveFormAction(_controller, forms: [_form], status: _status);
  late final _discard = DiscardFormAction(_controller, forms: [_form], status: _status);

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('companySettings', () => CompanySettingsForm());
    _form.bind(demoState.companyProfile.settings);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'settingsForm',
      elementProvider: _form,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.timezone.widget)
        .append((p) => p.locale.widget, dist: 16)
        .newRow()
        .append((p) => p.currency.widget)
        .append((p) => p.dateFormat.widget, dist: 16)
        .newRow()
        .append((p) => p.notificationEmail.widget)
        .append((p) => p.notificationFrequency.widget, dist: 16)
        .build(context);

    return DemoScaffold(
      title: 'Demo 5: Settings Form',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Form Features:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('• Dropdown fields with StaticSelectableSource'),
                    Text('• SelectableItem with descriptions (timezone)'),
                    Text('• Pattern validation for locale (e.g., en_US)'),
                    Text('• Pattern validation for currency (e.g., USD)'),
                    Text('• Compact form style'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TomFormStyleScope(
              style: TomFormStyle.compact,
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
            TomMultiObservableBuilder(
              observables: [_form, _status],
              builder: (context) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${TomCtr.text('demo5.status', 'label')}: ${_status.get()}'),
                      const SizedBox(height: 4),
                      Text('${TomCtr.text('demo5.status', 'dirty')}: ${_form.isDirty}'),
                    ],
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
