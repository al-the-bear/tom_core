import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/company_forms.dart';
import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Demo 2: Nested Forms — Address + Person
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - Nested forms (AddressForm, PersonForm inside main form)
/// - Parent-child form relationships
/// - Multiple ACL sections in one view
/// - Form composition patterns
class Demo2NestedForms extends StatefulWidget {
  const Demo2NestedForms({super.key});

  @override
  State<Demo2NestedForms> createState() => _Demo2NestedFormsState();
}

class _Demo2NestedFormsState extends State<Demo2NestedForms> {
  final _profile = CompanyProfile();
  late final _addressForm = AddressForm(fieldId: 'headquarters');
  late final _ceoForm = PersonForm(fieldId: 'ceo');
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    // Pre-populate address data
    _profile.headquarters.street | '123 Main St';
    _profile.headquarters.city | 'San Francisco';
    _profile.headquarters.state | 'CA';
    _profile.headquarters.zipCode | '94102';
    _profile.headquarters.country | 'US';

    // Pre-populate CEO data
    _profile.ceo.firstName | 'Jane';
    _profile.ceo.lastName | 'Doe';
    _profile.ceo.email | 'jane.doe@acme.example.com';
    _profile.ceo.title | 'Chief Executive Officer';

    // Bind forms to their respective state sections
    _addressForm.bind(_profile.headquarters);
    _ceoForm.bind(_profile.ceo);
  }

  @override
  void dispose() {
    _addressForm.dispose();
    _ceoForm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _status = 'Validating...');
    
    // Validate both forms
    final addressOk = await _addressForm.save();
    final ceoOk = await _ceoForm.save();
    
    setState(() {
      if (addressOk && ceoOk) {
        _status = 'Saved! CEO: ${_profile.ceo.firstName.get()} ${_profile.ceo.lastName.get()}, '
            'HQ: ${_profile.headquarters.city.get()}';
      } else {
        final errors = <String>[];
        if (!addressOk) errors.add('address');
        if (!ceoOk) errors.add('CEO info');
        _status = 'Validation failed in: ${errors.join(', ')}';
      }
    });
  }

  void _discard() {
    _addressForm.discard();
    _ceoForm.discard();
    setState(() => _status = 'Changes discarded');
  }

  @override
  Widget build(BuildContext context) {
    // Address section layout
    final addressLayout = TomAclBuilder(
      id: 'addressSection',
      elementProvider: _addressForm,
      title: 'Headquarters Address',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        .append((p) => p.street.widget)
        .expandX()
        .newRow()
        .append((p) => p.street2.widget)
        .expandX()
        .newRow()
        .append((p) => p.city.widget)
        .expandX()
        .append((p) => p.state.widget, dist: 16)
        .expandX()
        .append((p) => p.zipCode.widget, dist: 16)
        .expandX()
        .newRow()
        .append((p) => p.country.widget)
        .expandX()
        .build(context);

    // CEO section layout
    final ceoLayout = TomAclBuilder(
      id: 'ceoSection',
      elementProvider: _ceoForm,
      title: 'CEO Information',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        .append((p) => p.firstName.widget)
        .expandX()
        .append((p) => p.lastName.widget, dist: 16)
        .expandX()
        .newRow()
        .append((p) => p.email.widget)
        .expandX()
        .append((p) => p.phone.widget, dist: 16)
        .expandX()
        .newRow()
        .append((p) => p.title.widget)
        .expandX()
        .build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 2: Nested Forms'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
                  TextButton(onPressed: _discard, child: const Text('Discard')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save All')),
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
                      Text('Address Dirty: ${_addressForm.isDirty}'),
                      Text('CEO Dirty: ${_ceoForm.isDirty}'),
                    ],
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
