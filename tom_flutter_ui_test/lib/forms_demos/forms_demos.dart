/// Forms/Actions Demos
///
/// Demonstrates the form system from `tom_flutter_ui/lib/src/forms/`.
/// Shows TomForm, TomTextField, TomEmailField, TomPasswordField,
/// TomIntField, TomDoubleField — the reflection-based form framework
/// for declarative form creation with built-in validation.
///
/// Note: The TomForm base class requires `@tomReflector` code generation.
/// These demos show the field widgets and validation patterns directly.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Forms Overview Demo
// =============================================================================

/// Overview of the TomForm module and its field types.
class FormsOverviewDemo extends StatefulWidget {
  const FormsOverviewDemo({super.key});

  @override
  State<FormsOverviewDemo> createState() => _FormsOverviewDemoState();
}

class _FormsOverviewDemoState extends State<FormsOverviewDemo> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _ratingController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _usernameError;
  String? _ageError;
  String? _ratingError;

  Map<String, Object>? _savedValues;
  bool _formValid = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  void _validateAll() {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _usernameError = _validateRequired(_usernameController.text, 'Username');
      _ageError = _validateInt(_ageController.text, min: 0, max: 150);
      _ratingError = _validateDouble(_ratingController.text, min: 0, max: 5);

      _formValid = _emailError == null &&
          _passwordError == null &&
          _usernameError == null &&
          _ageError == null &&
          _ratingError == null;
    });
  }

  void _saveForm() {
    _validateAll();
    if (_formValid) {
      setState(() {
        _savedValues = {
          'email': _emailController.text,
          'password': _passwordController.text,
          'username': _usernameController.text,
          'age': int.tryParse(_ageController.text) ?? 0,
          'rating': double.tryParse(_ratingController.text) ?? 0.0,
        };
      });
    }
  }

  void _resetForm() {
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
      _ageController.clear();
      _ratingController.clear();
      _emailError = null;
      _passwordError = null;
      _usernameError = null;
      _ageError = null;
      _ratingError = null;
      _savedValues = null;
      _formValid = false;
    });
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
    );
    if (!emailRegex.hasMatch(value)) return 'Invalid email address';
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateRequired(String value, String fieldName) {
    if (value.isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validateInt(String value, {int? min, int? max}) {
    if (value.isEmpty) return null;
    final intVal = int.tryParse(value);
    if (intVal == null) return 'Must be a whole number';
    if (min != null && intVal < min) return 'Must be at least $min';
    if (max != null && intVal > max) return 'Must be at most $max';
    return null;
  }

  String? _validateDouble(String value, {double? min, double? max}) {
    if (value.isEmpty) return null;
    final doubleVal = double.tryParse(value);
    if (doubleVal == null) return 'Must be a number';
    if (min != null && doubleVal < min) return 'Must be at least $min';
    if (max != null && doubleVal > max) return 'Must be at most $max';
    return null;
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
                    'The forms module (tom_flutter_ui/lib/src/forms/) provides '
                    'a reflection-based form framework with declarative field '
                    'creation and built-in validation.\n\n'
                    'Available field types:\n'
                    '• TomTextField — standard text input\n'
                    '• TomEmailField — email with validation\n'
                    '• TomPasswordField — obscured text\n'
                    '• TomIntField — integer with min/max\n'
                    '• TomDoubleField — decimal with min/max',
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
                  // Email field (TomEmailField equivalent)
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      helperText: 'TomEmailField — validates email format',
                      errorText: _emailError,
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Password field (TomPasswordField equivalent)
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'TomPasswordField — obscured, min 6 chars',
                      errorText: _passwordError,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Username field (TomTextField equivalent)
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      helperText: 'TomTextField — required text field',
                      errorText: _usernameError,
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Age field (TomIntField equivalent)
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      helperText: 'TomIntField — integer, range 0–150',
                      errorText: _ageError,
                      prefixIcon: const Icon(Icons.cake),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rating field (TomDoubleField equivalent)
                  TextField(
                    controller: _ratingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Rating',
                      helperText: 'TomDoubleField — decimal, range 0.0–5.0',
                      errorText: _ratingError,
                      prefixIcon: const Icon(Icons.star),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _validateAll,
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
