/// Forms/Actions Demos
///
/// Demonstrates the form system from `tom_flutter_ui/lib/src/forms/`.
/// Shows TomFormStringInput — the Phase 1 concrete string field — used
/// in different configurations: plain text, email, password, and numeric
/// input via keyboard type.
///
/// Note: TomForm uses @tomReflector code generation for automatic field
/// discovery.  Here we demonstrate the form field classes standalone
/// (without TomForm) so that reflection setup is not required.
/// In a production app with reflection enabled, fields are created
/// inside a TomForm subclass and managed as a group.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Forms Overview Demo
// =============================================================================

/// Overview of the TomForm module demonstrating the actual field classes.
///
/// Each field is an instance of its concrete type (TomEmailFormField,
/// TomPasswordFormField, etc.).  The demo exercises validate(), save(),
/// reset() and getField() — the same APIs used in production forms.
class FormsOverviewDemo extends StatefulWidget {
  const FormsOverviewDemo({super.key});

  @override
  State<FormsOverviewDemo> createState() => _FormsOverviewDemoState();
}

class _FormsOverviewDemoState extends State<FormsOverviewDemo> {
  // ── Real form field instances ──────────────────────────────────────────
  late final TomFormStringInput _email;
  late final TomFormStringInput _password;
  late final TomFormStringInput _username;
  late final TomFormStringInput _age;
  late final TomFormStringInput _rating;

  late final List<TomField> _fields;

  Map<String, Object>? _savedValues;
  bool _formValid = false;

  @override
  void initState() {
    super.initState();

    // Create field instances with explicit labels and decoration params.
    // In production these come from resource lookup; here we pass them
    // directly to show the override mechanism.
    _email = TomFormStringInput(
      'email',
      '',
      labelTextOverride: 'Email',
      hintTextOverride: 'TomFormStringInput — validates email format',
      prefixIcon: const Icon(Icons.email),
      keyboardType: TextInputType.emailAddress,
      validators: [Validators.required(), Validators.email()],
    );

    _password = TomFormStringInput(
      'password',
      '',
      labelTextOverride: 'Password',
      hintTextOverride: 'TomFormStringInput — obscured, min 6 chars',
      prefixIcon: const Icon(Icons.lock),
      obscureText: true,
      validators: [
        Validators.required(),
        Validators.minLength(6),
      ],
    );

    _username = TomFormStringInput(
      'username',
      '',
      labelTextOverride: 'Username',
      hintTextOverride: 'TomFormStringInput — required text field',
      prefixIcon: const Icon(Icons.person),
      validators: [Validators.required()],
    );

    _age = TomFormStringInput(
      'age',
      '',
      labelTextOverride: 'Age',
      hintTextOverride: 'TomFormStringInput — integer input',
      prefixIcon: const Icon(Icons.cake),
      keyboardType: TextInputType.number,
    );

    _rating = TomFormStringInput(
      'rating',
      '',
      labelTextOverride: 'Rating',
      hintTextOverride: 'TomFormStringInput — decimal input',
      prefixIcon: const Icon(Icons.star),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );

    _fields = [_email, _password, _username, _age, _rating];
  }

  Future<void> _validateAll() async {
    bool valid = true;
    for (final field in _fields) {
      final result = await field.validate();
      if (result is ValidationError) valid = false;
    }
    setState(() => _formValid = valid);
  }

  Future<void> _saveForm() async {
    await _validateAll();
    if (_formValid) {
      setState(() {
        _savedValues = {
          for (final field in _fields) field.fieldId: field.get(),
        };
        // Commit all fields (marks current value as initial)
        for (final field in _fields) {
          field.commit();
        }
      });
    }
  }

  void _resetForm() {
    for (final field in _fields) {
      field.reset();
    }
    setState(() {
      _savedValues = null;
      _formValid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TomSingleChildScrollView(
      tomId: 'formsOverviewScroll',
      padding: const EdgeInsets.all(16),
      child: TomColumn(
        tomId: 'formsOverviewColumn',
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Module Info ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TomForm Module',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The forms module provides a reflection-based form '
                    'framework with declarative field creation and built-in '
                    'validation.\n\n'
                    'Fields shown below are real instances of '
                    'TomFormStringInput configured for different input types:\n'
                    '• Username — required text field\n'
                    '• Email — email format validation\n'
                    '• Password — obscured text, min length\n'
                    '• Age — numeric keyboard input\n'
                    '• Rating — decimal keyboard input\n\n'
                    'Each field supports the resource lookup pattern for '
                    'labels, hints, and descriptions.  Explicit '
                    'parameters override resource values.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Demo Form ───────────────────────────────────────────
          Text(
            'Form Fields Demo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Render each field using its widget property
                  for (final field in _fields) ...[
                    field.widget,
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _validateAll();
                          setState(() {});
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Validate'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saveForm,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),

                  // Saved values display
                  if (_savedValues != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Saved Values:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ..._savedValues!.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
