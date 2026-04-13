import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/company_forms.dart';
import '../state/company_state.dart';

// ---------------------------------------------------------------------------
// Demo 3: Authorization — Field-level and Resource-based auth
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - TomAuthorization adapter setup
/// - Per-resource authorization (full, read, disabled, none)
/// - TomAuthorizationGroup for section-level authorization
/// - Dynamic auth state changes through resource adapter
/// - Authorization resolution from resource paths
class Demo3Authorization extends StatefulWidget {
  const Demo3Authorization({super.key});

  @override
  State<Demo3Authorization> createState() => _Demo3AuthorizationState();
}

/// Simple in-memory authorization adapter for the demo.
class DemoAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {
    // Default: all fields full access
    'demo3': TomAuthState.full,
    // Tax ID is read-only (sensitive data)
    'demo3.taxId': TomAuthState.read,
    // Description is hidden
    'demo3.description': TomAuthState.none,
  };

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // Check for exact match first
    if (_rules.containsKey(resourceKeyPath)) {
      return _rules[resourceKeyPath]!;
    }
    // Fall back to parent path
    final parts = resourceKeyPath.split('.');
    for (var i = parts.length - 1; i > 0; i--) {
      final parentPath = parts.sublist(0, i).join('.');
      if (_rules.containsKey(parentPath)) {
        return _rules[parentPath]!;
      }
    }
    return TomAuthState.full;
  }

  void setRule(String path, TomAuthState state) {
    _rules[path] = state;
  }

  void removeRule(String path) {
    _rules.remove(path);
  }
}

class _Demo3AuthorizationState extends State<Demo3Authorization> {
  final _profile = CompanyProfile();
  late final DemoAuthAdapter _authAdapter;
  late final CompanyBasicInfoForm _form;
  late final TomAuthorizationGroup _sectionGroup;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();

    // Set up authorization adapter
    _authAdapter = DemoAuthAdapter();
    TomAuthorization.adapter = _authAdapter;

    // Create section authorization group (auth resolved from 'demo3.section')
    _sectionGroup = TomAuthorizationGroup('section');

    // Create form with scope 'demo3'
    _form = TomScope.withScope<CompanyBasicInfoForm>('demo3', () {
      return CompanyBasicInfoForm(authGroup: _sectionGroup);
    });

    // Pre-populate data
    _profile.name | 'Acme Corporation';
    _profile.industry | 'tech';
    _profile.taxId | 'US-12345-ABC';
    _profile.website | 'https://acme.example.com';
    _profile.description | 'A leading tech company';

    _form.bind(_profile);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _toggleNameReadOnly() {
    final currentAuth = _authAdapter.resolveAuth('demo3.name');
    if (currentAuth == TomAuthState.full) {
      _authAdapter.setRule('demo3.name', TomAuthState.read);
      setState(() => _status = 'Name field: READ-ONLY');
    } else {
      _authAdapter.removeRule('demo3.name');
      setState(() => _status = 'Name field: EDITABLE');
    }
  }

  void _toggleSectionDisabled() {
    // Control auth for entire section via resource path
    final currentAuth = _authAdapter.resolveAuth('demo3.section');
    if (currentAuth == TomAuthState.full) {
      _authAdapter.setRule('demo3.section', TomAuthState.disabled);
      setState(() => _status = 'Section: DISABLED (grayed out)');
    } else {
      _authAdapter.removeRule('demo3.section');
      setState(() => _status = 'Section: ENABLED');
    }
  }

  void _cycleIndustryAuth() {
    final current = _authAdapter.resolveAuth('demo3.industry');
    TomAuthState next;
    String label;
    switch (current) {
      case TomAuthState.full:
        next = TomAuthState.read;
        label = 'READ';
      case TomAuthState.read:
        next = TomAuthState.disabled;
        label = 'DISABLED';
      case TomAuthState.disabled:
        next = TomAuthState.none;
        label = 'HIDDEN';
      case TomAuthState.none:
        next = TomAuthState.full;
        label = 'FULL';
    }
    _authAdapter.setRule('demo3.industry', next);
    setState(() => _status = 'Industry field: $label');
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'authDemo',
      elementProvider: _form,
      title: 'Authorization Demo',
      borderStyle: const AclBorderStyle.solid(),
      padding: const EdgeInsets.all(16),
    )
        .append((p) => p.name.widget)
        .expandX()
        .newRow()
        .append((p) => p.industry.widget)
        .expandX()
        .append((p) => p.taxId.widget, dist: 16)
        .expandX()
        .newRow()
        .append((p) => p.website.widget)
        .expandX()
        .newRow()
        .append((p) => p.description.widget)
        .expandX()
        .build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 3: Authorization'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auth controls
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authorization Controls',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _toggleNameReadOnly,
                          child: const Text('Toggle Name R/O'),
                        ),
                        OutlinedButton(
                          onPressed: _cycleIndustryAuth,
                          child: const Text('Cycle Industry Auth'),
                        ),
                        OutlinedButton(
                          onPressed: _toggleSectionDisabled,
                          child: const Text('Toggle Section'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Initial State:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• Tax ID: READ-ONLY (per-resource auth)'),
                    const Text('• Description: HIDDEN (auth = none)'),
                    const Text('• Other fields: EDITABLE'),
                    const SizedBox(height: 8),
                    Text('Status: $_status'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Form
            TomFormStyleScope(
              style: TomFormStyle.material3,
              child: formLayout,
            ),
          ],
        ),
      ),
    );
  }
}
