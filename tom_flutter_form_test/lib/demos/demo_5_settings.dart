import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/company_forms.dart';
import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Demo 5: Settings Form — Dropdowns and Compact Layout
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - Multiple TomFormStringDropdown fields
/// - Compact form style (TomFormStyle.compact)
/// - StaticSelectableSource with descriptions
/// - Settings-style form layout
/// - Locale/currency pattern validators
class Demo5SettingsForm extends StatefulWidget {
  const Demo5SettingsForm({super.key});

  @override
  State<Demo5SettingsForm> createState() => _Demo5SettingsFormState();
}

class _Demo5SettingsFormState extends State<Demo5SettingsForm> {
  final _profile = CompanyProfile();
  late final _form = CompanySettingsForm();
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _form.bind(_profile.settings);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _status = 'Validating...');
    final success = await _form.save();
    setState(() {
      if (success) {
        final tz = _profile.settings.timezone.get();
        final cur = _profile.settings.currency.get();
        _status = 'Saved! Timezone: $tz, Currency: $cur';
      } else {
        _status = 'Validation failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'settingsForm',
      elementProvider: _form,
      title: 'Company Settings',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        // Row 1: Timezone and Locale
        .append((p) => p.timezone.widget)
        .expandX()
        .append((p) => p.locale.widget, dist: 16)
        .expandX()
        .newRow()
        // Row 2: Currency and Date Format
        .append((p) => p.currency.widget)
        .expandX()
        .append((p) => p.dateFormat.widget, dist: 16)
        .expandX()
        .newRow()
        // Row 3: Notification settings
        .append((p) => p.notificationEmail.widget)
        .expandX()
        .append((p) => p.notificationFrequency.widget, dist: 16)
        .expandX()
        .build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 5: Settings Form'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
            // Form with compact style
            TomFormStyleScope(
              style: TomFormStyle.compact,
              child: formLayout,
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _form.discard();
                    setState(() => _status = 'Changes discarded');
                  },
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
            const SizedBox(height: 8),
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status'),
                    const SizedBox(height: 4),
                    Text('Dirty: ${_form.isDirty}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
