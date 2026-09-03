import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 3: Authorization — Field-level and Resource-based auth
// ---------------------------------------------------------------------------

/// Demonstrates:
/// - TomAuthorization adapter setup
/// - Per-resource authorization (full, read, disabled, none)
/// - TomAuthorizationGroup for section-level authorization
/// - Dynamic auth state changes through resource adapter
/// - Authorization resolution from resource paths
/// - Container title / padding / borderStyle from resources
class Demo3Authorization extends StatefulWidget {
  const Demo3Authorization({super.key});

  @override
  State<Demo3Authorization> createState() => _Demo3AuthorizationState();
}

/// Simple in-memory authorization adapter for the demo.
class DemoAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {
    'demo3': TomAuthState.full,
    'demo3.taxId': TomAuthState.read,
    'demo3.description': TomAuthState.none,
  };

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    if (_rules.containsKey(resourceKeyPath)) {
      return _rules[resourceKeyPath]!;
    }
    final parts = resourceKeyPath.split('.');
    for (var i = parts.length - 1; i > 0; i--) {
      final parentPath = parts.sublist(0, i).join('.');
      if (_rules.containsKey(parentPath)) {
        return _rules[parentPath]!;
      }
    }
    return TomAuthState.full;
  }

  void setRule(String path, TomAuthState state) => _rules[path] = state;
  void removeRule(String path) => _rules.remove(path);
}

class _Demo3AuthorizationState extends State<Demo3Authorization> {
  late final DemoAuthAdapter _authAdapter;
  late final CompanyBasicInfoForm _form;
  late final TomAuthorizationGroup _sectionGroup;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();

    _authAdapter = DemoAuthAdapter();
    TomAuthorization.adapter = _authAdapter;

    _sectionGroup = TomAuthorizationGroup('section');

    _form = TomScope.withScope<CompanyBasicInfoForm>('demo3', () {
      return CompanyBasicInfoForm(authGroup: _sectionGroup);
    });

    _form.bind(demoState.companyProfile);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _toggleNameReadOnly() {
    final current = _authAdapter.resolveAuth('demo3.name');
    if (current == TomAuthState.full) {
      _authAdapter.setRule('demo3.name', TomAuthState.read);
      setState(() => _status = 'Name field: READ-ONLY');
    } else {
      _authAdapter.removeRule('demo3.name');
      setState(() => _status = 'Name field: EDITABLE');
    }
  }

  void _toggleSectionDisabled() {
    final current = _authAdapter.resolveAuth('demo3.section');
    if (current == TomAuthState.full) {
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
    final formLayout = TomAclBuilder(id: 'authDemo', elementProvider: _form)
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.industry.widget)
        .append((p) => p.taxId.widget, dist: 16)
        .newRow()
        .append((p) => p.website.widget)
        .newRow()
        .append((p) => p.description.widget)
        .build(context);

    return DemoScaffold(
      title: 'Demo 3: Authorization',
      child: SingleChildScrollView(
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
            TomFormStyleScope(style: TomFormStyle.material3, child: formLayout),
          ],
        ),
      ),
    );
  }
}
