import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/company_forms.dart';
import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Demo 1: Basic Form — Company Info
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - TomForm binding/save/discard lifecycle
/// - TomFormStringInput and TomFormStringDropdown usage
/// - Required, minLength, maxLength, pattern validators
/// - SlowValidator with pending spinner (Tax ID field)
/// - ACL layout with append(), newRow(), gap()
class Demo1BasicForm extends StatefulWidget {
  const Demo1BasicForm({super.key});

  @override
  State<Demo1BasicForm> createState() => _Demo1BasicFormState();
}

class _Demo1BasicFormState extends State<Demo1BasicForm> {
  final _profile = CompanyProfile();
  late final _form = CompanyBasicInfoForm();
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    // Pre-populate some data
    _profile.name | 'Acme Corporation';
    _profile.industry | 'tech';
    _profile.website | 'https://acme.example.com';
    // Bind form to state
    _form.bind(_profile);
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
      _status = success
          ? 'Saved! Name: ${_profile.name.get()}'
          : 'Validation failed - check fields';
    });
  }

  void _discard() {
    _form.discard();
    setState(() => _status = 'Changes discarded');
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'basicForm',
      elementProvider: _form,
      title: 'Company Information',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.industry.widget)
        .gap()
        .append((p) => p.taxId.widget)
        .newRow()
        .append((p) => p.website.widget)
        .newRow()
        .append((p) => p.description.widget)
        .expandX()
        .build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 1: Basic Form'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
                TextButton(onPressed: _discard, child: const Text('Discard')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status'),
                    const SizedBox(height: 4),
                    Text('Dirty: ${_form.isDirty}'),
                    Text('Valid: ${_form.isValid}'),
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
