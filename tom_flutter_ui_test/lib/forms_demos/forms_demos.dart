/// Forms/Actions Demos
///
/// Demonstrates the form system from `tom_flutter_ui/lib/src/forms/`.
/// Shows TomForm, TomStringFormField, TomEmailFormField, TomPasswordFormField,
/// TomIntFormField, TomDoubleFormField — the reflection-based form framework
/// for declarative form creation with built-in validation.
///
/// Note: TomForm uses @tomReflector code generation for automatic field
/// discovery.  Here we demonstrate the form field classes standalone
/// (without TomForm) so that reflection setup is not required.
/// In a production app with reflection enabled, fields are created
/// inside a TomForm subclass and managed as a group.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';
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
  late final TomEmailFormField _email;
  late final TomPasswordFormField _password;
  late final TomStringFormField _username;
  late final TomIntFormField _age;
  late final TomDoubleFormField _rating;

  late final List<TomField> _fields;

  Map<String, Object>? _savedValues;
  bool _formValid = false;

  @override
  void initState() {
    super.initState();

    // Create field instances with explicit labels and decoration params.
    // In production these come from resource lookup; here we pass them
    // directly to show the override mechanism.
    _email = TomEmailFormField(
      'email',
      '',
      labelText: 'Email',
      helperText: 'TomEmailFormField — validates email format',
      prefixIcon: const Icon(Icons.email),
    );

    _password = TomPasswordFormField(
      'password',
      '',
      labelText: 'Password',
      helperText: 'TomPasswordFormField — obscured, min 6 chars',
      prefixIcon: const Icon(Icons.lock),
      valueValidator: (value) {
        if (value.isEmpty) return 'password.errors.required';
        if (value.length < 6) return 'password.errors.tooShort';
        return null;
      },
    );

    _username = TomStringFormField(
      'username',
      '',
      labelText: 'Username',
      helperText: 'TomStringFormField — required text field',
      prefixIcon: const Icon(Icons.person),
      valueValidator: (value) {
        if (value.isEmpty) return 'username.errors.required';
        return null;
      },
    );

    _age = TomIntFormField(
      'age',
      0,
      min: 0,
      max: 150,
      labelText: 'Age',
      helperText: 'TomIntFormField — integer, range 0–150',
      prefixIcon: const Icon(Icons.cake),
    );

    _rating = TomDoubleFormField(
      'rating',
      0.0,
      min: 0.0,
      max: 5.0,
      labelText: 'Rating',
      helperText: 'TomDoubleFormField — decimal, range 0.0–5.0',
      prefixIcon: const Icon(Icons.star),
    );

    _fields = [_email, _password, _username, _age, _rating];
  }

  void _validateAll() {
    bool valid = true;
    for (final field in _fields) {
      valid = field.validate() && valid;
    }
    setState(() => _formValid = valid);
  }

  void _saveForm() {
    _validateAll();
    if (_formValid) {
      setState(() {
        _savedValues = {
          for (final field in _fields) field.fieldName: field.save(),
        };
      });
    }
  }

  void _resetForm() {
    for (final field in _fields) {
      if (field is TomTextFormFieldBase) field.reset();
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
                    'Fields shown below are real instances of:\n'
                    '• TomStringFormField — standard text input\n'
                    '• TomEmailFormField — email with validation\n'
                    '• TomPasswordFormField — obscured text\n'
                    '• TomIntFormField — integer with min/max\n'
                    '• TomDoubleFormField — decimal with min/max\n\n'
                    'Each field supports the resource lookup pattern for '
                    'labels, helper text, hints, and icons.  Explicit '
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
                  // Render each field using its getField() method
                  for (final field in _fields) ...[
                    field.getField(),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _validateAll();
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
