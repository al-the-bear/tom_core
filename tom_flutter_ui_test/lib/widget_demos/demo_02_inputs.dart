/// Comprehensive Text Input Widgets Demo
///
/// This demo showcases all Flutter text input widgets with their various
/// configurations, validations, and styling options. Each input type is
/// demonstrated with:
/// - Basic usage
/// - Validation states (error, success, warning)
/// - Decoration options
/// - Input formatters
/// - Accessibility considerations
/// - Code examples
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main inputs demo screen with all input categories.
class InputsDemo extends StatelessWidget {
  const InputsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'TextField',
          subtitle: 'Basic text input fields for single-line text',
        ),
        _TextFieldSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'TextFormField',
          subtitle: 'Text fields with form validation support',
        ),
        _TextFormFieldSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Input Decorations',
          subtitle: 'Styling and decorating text inputs',
        ),
        _InputDecorationSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Password Fields',
          subtitle: 'Secure text entry with visibility toggle',
        ),
        _PasswordFieldSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Multi-line Text',
          subtitle: 'TextFields for longer text content',
        ),
        _MultilineTextSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Input Formatters',
          subtitle: 'Restricting and formatting input text',
        ),
        _InputFormattersSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Search Fields',
          subtitle: 'Optimized inputs for search functionality',
        ),
        _SearchFieldSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Date & Time Pickers',
          subtitle: 'Specialized inputs for date and time selection',
        ),
        _DateTimePickerSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Form Examples',
          subtitle: 'Complete form implementations with validation',
        ),
        _FormExamplesSection(),
        SizedBox(height: 48),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Demo Card
// =============================================================================

class _DemoCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final String? code;

  const _DemoCard({
    required this.title,
    this.description,
    required this.child,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
            if (code != null) ...[
              const SizedBox(height: 16),
              _CodeSnippet(code: code!),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Code Snippet
// =============================================================================

class _CodeSnippet extends StatefulWidget {
  final String code;

  const _CodeSnippet({required this.code});

  @override
  State<_CodeSnippet> createState() => _CodeSnippetState();
}

class _CodeSnippetState extends State<_CodeSnippet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.code_off : Icons.code,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _expanded ? 'Hide code' : 'Show code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.code.trim(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// TextField Section
// =============================================================================

class _TextFieldSection extends StatefulWidget {
  const _TextFieldSection();

  @override
  State<_TextFieldSection> createState() => _TextFieldSectionState();
}

class _TextFieldSectionState extends State<_TextFieldSection> {
  final _basicController = TextEditingController();
  final _hintController = TextEditingController();
  final _labelController = TextEditingController();
  final _prefixController = TextEditingController();

  @override
  void dispose() {
    _basicController.dispose();
    _hintController.dispose();
    _labelController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic TextField',
          description: 'Simple text input with optional controller.',
          child: Column(
            children: [
              TextField(
                controller: _basicController,
                decoration: const InputDecoration(
                  hintText: 'Enter text here',
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: _basicController,
                builder: (context, value, _) => Text(
                  'Current value: "${value.text}"',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          code: '''
TextField(
  controller: _textController,
  decoration: InputDecoration(
    hintText: 'Enter text here',
  ),
)''',
        ),
        _DemoCard(
          title: 'TextField with Label',
          description: 'Floating label that animates when focused.',
          child: TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Enter your username',
            ),
          ),
          code: '''
TextField(
  decoration: InputDecoration(
    labelText: 'Username',
    hintText: 'Enter your username',
  ),
)''',
        ),
        _DemoCard(
          title: 'TextField with Prefix & Suffix',
          description: 'Add icons or text before/after the input.',
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Website',
                  prefixText: 'https://',
                  suffixText: '.com',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _prefixController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _prefixController.clear(),
                  ),
                ),
              ),
            ],
          ),
          code: '''
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email),
    suffixIcon: IconButton(
      icon: Icon(Icons.clear),
      onPressed: () => controller.clear(),
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'TextField States',
          description: 'Enabled, disabled, and read-only states.',
          child: Column(
            children: [
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Enabled',
                  helperText: 'This field is editable',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Disabled',
                  helperText: 'This field is disabled',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: 'Read-only value'),
                decoration: const InputDecoration(
                  labelText: 'Read Only',
                  helperText: 'This field is read-only',
                ),
              ),
            ],
          ),
          code: '''
// Disabled
TextField(
  enabled: false,
  decoration: InputDecoration(labelText: 'Disabled'),
)

// Read-only
TextField(
  readOnly: true,
  controller: TextEditingController(text: 'Value'),
  decoration: InputDecoration(labelText: 'Read Only'),
)''',
        ),
      ],
    );
  }
}

// =============================================================================
// TextFormField Section
// =============================================================================

class _TextFormFieldSection extends StatefulWidget {
  const _TextFormFieldSection();

  @override
  State<_TextFormFieldSection> createState() => _TextFormFieldSectionState();
}

class _TextFormFieldSectionState extends State<_TextFormFieldSection> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic Validation',
          description: 'TextFormField with validator function.',
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '1234567890',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Form is valid!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
          code: '''
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email),
  ),
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // Add email regex validation
    return null;
  },
  autovalidateMode: AutovalidateMode.onUserInteraction,
)''',
        ),
        const _ValidationStatesDemo(),
      ],
    );
  }
}

class _ValidationStatesDemo extends StatelessWidget {
  const _ValidationStatesDemo();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Validation States',
      description: 'Visual feedback for different validation states.',
      child: Column(
        children: [
          // Success state
          TextFormField(
            initialValue: 'valid@email.com',
            decoration: InputDecoration(
              labelText: 'Success State',
              prefixIcon: const Icon(Icons.check_circle, color: Colors.green),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Email is valid',
              helperStyle: const TextStyle(color: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
          // Error state
          TextFormField(
            initialValue: 'invalid-email',
            decoration: InputDecoration(
              labelText: 'Error State',
              prefixIcon: const Icon(Icons.error, color: Colors.red),
              errorText: 'Please enter a valid email address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Warning state
          TextFormField(
            initialValue: 'weak_password',
            decoration: InputDecoration(
              labelText: 'Warning State',
              prefixIcon: const Icon(Icons.warning, color: Colors.orange),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              helperText: 'Password is weak. Consider adding numbers.',
              helperStyle: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Input Decoration Section
// =============================================================================

class _InputDecorationSection extends StatelessWidget {
  const _InputDecorationSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Border Styles',
          description: 'Different border variants for text fields.',
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Outline Border',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Underline Border (Default)',
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'No Border',
                  filled: true,
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Stadium Border',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          code: '''
// Outline border
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)

// Filled with stadium shape
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'Fill Colors',
          description: 'Customize the background fill of text fields.',
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Default Fill',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Fill Color',
                  filled: true,
                  fillColor: Colors.blue.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Surface Container',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Counter & Max Length',
          description: 'Character counting and length limits.',
          child: Column(
            children: [
              const TextField(
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'With Counter',
                  hintText: 'Max 50 characters',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  labelText: 'Enforced Max Length',
                  hintText: 'Cannot exceed 100 characters',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                maxLength: 280,
                buildCounter: _buildCustomCounter,
                decoration: InputDecoration(
                  labelText: 'Custom Counter',
                  hintText: 'Tweet-style counter',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          code: '''
TextField(
  maxLength: 50,
  decoration: InputDecoration(
    labelText: 'With Counter',
    border: OutlineInputBorder(),
  ),
)''',
        ),
      ],
    );
  }
}

Widget? _buildCustomCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) {
  final remaining = (maxLength ?? 0) - currentLength;
  final color =
      remaining < 20
          ? (remaining < 0 ? Colors.red : Colors.orange)
          : Colors.grey;

  return Text(
    '$remaining',
    style: TextStyle(
      color: color,
      fontWeight: remaining < 20 ? FontWeight.bold : FontWeight.normal,
    ),
  );
}

// =============================================================================
// Password Field Section
// =============================================================================

class _PasswordFieldSection extends StatefulWidget {
  const _PasswordFieldSection();

  @override
  State<_PasswordFieldSection> createState() => _PasswordFieldSectionState();
}

class _PasswordFieldSectionState extends State<_PasswordFieldSection> {
  bool _obscureText1 = true;
  bool _obscureText2 = true;
  final _passwordController = TextEditingController();
  double _passwordStrength = 0;

  void _checkPasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  Color _getStrengthColor() {
    if (_passwordStrength <= 0.25) return Colors.red;
    if (_passwordStrength <= 0.5) return Colors.orange;
    if (_passwordStrength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthText() {
    if (_passwordStrength <= 0.25) return 'Weak';
    if (_passwordStrength <= 0.5) return 'Fair';
    if (_passwordStrength <= 0.75) return 'Good';
    return 'Strong';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic Password Field',
          description: 'Toggle visibility with suffix icon.',
          child: TextField(
            obscureText: _obscureText1,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText1 ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureText1 = !_obscureText1),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          code: '''
TextField(
  obscureText: _obscureText,
  decoration: InputDecoration(
    labelText: 'Password',
    prefixIcon: Icon(Icons.lock),
    suffixIcon: IconButton(
      icon: Icon(
        _obscureText ? Icons.visibility_off : Icons.visibility,
      ),
      onPressed: () => setState(() => _obscureText = !_obscureText),
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'Password with Strength Indicator',
          description: 'Real-time password strength feedback.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: _obscureText2,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  labelText: 'Create Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText2 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText2 = !_obscureText2),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (_passwordController.text.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_getStrengthColor()),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength: ${_getStrengthText()}',
                      style: TextStyle(
                        color: _getStrengthColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(_passwordStrength * 100).toInt()}%',
                      style: TextStyle(color: _getStrengthColor()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildRequirement(
                  'At least 8 characters',
                  _passwordController.text.length >= 8,
                ),
                _buildRequirement(
                  'Contains uppercase letter',
                  _passwordController.text.contains(RegExp(r'[A-Z]')),
                ),
                _buildRequirement(
                  'Contains number',
                  _passwordController.text.contains(RegExp(r'[0-9]')),
                ),
                _buildRequirement(
                  'Contains special character',
                  _passwordController.text
                      .contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Multi-line Text Section
// =============================================================================

class _MultilineTextSection extends StatelessWidget {
  const _MultilineTextSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Multi-line TextField',
          description: 'Expandable text area for longer content.',
          child: Column(
            children: [
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Fixed 3 lines',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Expandable (2-5 lines)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Unlimited lines',
                  alignLabelWithHint: true,
                  hintText: 'This text field can grow indefinitely...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          code: '''
// Fixed height
TextField(
  maxLines: 3,
  decoration: InputDecoration(
    labelText: 'Fixed 3 lines',
    alignLabelWithHint: true,
    border: OutlineInputBorder(),
  ),
)

// Expandable
TextField(
  minLines: 2,
  maxLines: 5,
  decoration: InputDecoration(
    labelText: 'Expandable',
    alignLabelWithHint: true,
  ),
)''',
        ),
        _DemoCard(
          title: 'Rich Text Area',
          description: 'Text area with character count and helper text.',
          child: TextField(
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              hintText: 'Enter a detailed description...',
              helperText: 'Add any relevant details',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Input Formatters Section
// =============================================================================

class _InputFormattersSection extends StatelessWidget {
  const _InputFormattersSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Digit Only Input',
          description: 'Using FilteringTextInputFormatter for numbers.',
          child: Column(
            children: [
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Numbers Only',
                  hintText: 'Only digits allowed',
                  prefixIcon: const Icon(Icons.pin),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Decimal Numbers',
                  hintText: 'Numbers and decimal point',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          code: '''
// Digits only
TextField(
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
  ],
)

// Allow decimals
TextField(
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[\\d.]')),
  ],
)''',
        ),
        _DemoCard(
          title: 'Uppercase Input',
          description: 'Auto-convert text to uppercase.',
          child: TextField(
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [UpperCaseTextFormatter()],
            decoration: InputDecoration(
              labelText: 'License Plate',
              hintText: 'AUTO-UPPERCASE',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          code: '''
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

TextField(
  inputFormatters: [UpperCaseTextFormatter()],
)''',
        ),
        _DemoCard(
          title: 'Phone Number Formatter',
          description: 'Auto-format input as phone number.',
          child: TextField(
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
              PhoneNumberFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '(555) 123-4567',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          code: '''
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}''',
        ),
        _DemoCard(
          title: 'Credit Card Formatter',
          description: 'Format input as credit card number with spaces.',
          child: TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              CreditCardFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Card Number',
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom formatter to convert text to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Custom formatter for US phone numbers.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Custom formatter for credit card numbers.
class CreditCardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// =============================================================================
// Search Field Section
// =============================================================================

class _SearchFieldSection extends StatefulWidget {
  const _SearchFieldSection();

  @override
  State<_SearchFieldSection> createState() => _SearchFieldSectionState();
}

class _SearchFieldSectionState extends State<_SearchFieldSection> {
  final _searchController = TextEditingController();
  final _searchBarController = SearchController();

  final _suggestions = [
    'Flutter',
    'Dart',
    'Widgets',
    'Material Design',
    'Cupertino',
    'Animation',
    'State Management',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic Search Field',
          description: 'TextField styled for search functionality.',
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                      : null,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          code: '''
TextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: 'Search...',
    prefixIcon: Icon(Icons.search),
    suffixIcon: _searchController.text.isNotEmpty
        ? IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => _searchController.clear(),
          )
        : null,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'SearchBar (Material 3)',
          description: 'Material 3 search bar with suggestions.',
          child: SearchAnchor(
            searchController: _searchBarController,
            builder: (context, controller) {
              return SearchBar(
                controller: controller,
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                leading: const Icon(Icons.search),
                hintText: 'Search topics...',
                trailing: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => controller.clear(),
                    ),
                ],
              );
            },
            suggestionsBuilder: (context, controller) {
              final query = controller.text.toLowerCase();
              final filtered =
                  _suggestions
                      .where((s) => s.toLowerCase().contains(query))
                      .toList();

              return filtered.map(
                (suggestion) => ListTile(
                  leading: const Icon(Icons.topic),
                  title: Text(suggestion),
                  onTap: () {
                    controller.closeView(suggestion);
                  },
                ),
              );
            },
          ),
          code: '''
SearchAnchor(
  searchController: _controller,
  builder: (context, controller) {
    return SearchBar(
      controller: controller,
      onTap: () => controller.openView(),
      leading: Icon(Icons.search),
      hintText: 'Search...',
    );
  },
  suggestionsBuilder: (context, controller) {
    return suggestions
        .where((s) => s.contains(controller.text))
        .map((s) => ListTile(
              title: Text(s),
              onTap: () => controller.closeView(s),
            ));
  },
)''',
        ),
      ],
    );
  }
}

// =============================================================================
// Date & Time Picker Section
// =============================================================================

class _DateTimePickerSection extends StatefulWidget {
  const _DateTimePickerSection();

  @override
  State<_DateTimePickerSection> createState() => _DateTimePickerSectionState();
}

class _DateTimePickerSectionState extends State<_DateTimePickerSection> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTimeRange? _selectedDateRange;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );
    if (range != null) {
      setState(() => _selectedDateRange = range);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Date Picker',
          description: 'TextField that triggers date picker dialog.',
          child: TextField(
            readOnly: true,
            onTap: _pickDate,
            controller: TextEditingController(
              text: _selectedDate != null ? _formatDate(_selectedDate!) : '',
            ),
            decoration: InputDecoration(
              labelText: 'Select Date',
              hintText: 'Tap to select',
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _selectedDate = null),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          code: '''
TextField(
  readOnly: true,
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  },
  decoration: InputDecoration(
    labelText: 'Select Date',
    prefixIcon: Icon(Icons.calendar_today),
  ),
)''',
        ),
        _DemoCard(
          title: 'Time Picker',
          description: 'TextField that triggers time picker dialog.',
          child: TextField(
            readOnly: true,
            onTap: _pickTime,
            controller: TextEditingController(
              text: _selectedTime?.format(context) ?? '',
            ),
            decoration: InputDecoration(
              labelText: 'Select Time',
              hintText: 'Tap to select',
              prefixIcon: const Icon(Icons.access_time),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _selectedTime = null),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        _DemoCard(
          title: 'Date Range Picker',
          description: 'Select a start and end date.',
          child: TextField(
            readOnly: true,
            onTap: _pickDateRange,
            controller: TextEditingController(
              text:
                  _selectedDateRange != null
                      ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                      : '',
            ),
            decoration: InputDecoration(
              labelText: 'Select Date Range',
              hintText: 'Tap to select',
              prefixIcon: const Icon(Icons.date_range),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _selectedDateRange = null),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Form Examples Section
// =============================================================================

class _FormExamplesSection extends StatefulWidget {
  const _FormExamplesSection();

  @override
  State<_FormExamplesSection> createState() => _FormExamplesSectionState();
}

class _FormExamplesSectionState extends State<_FormExamplesSection> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  bool _loginLoading = false;
  bool _signupLoading = false;
  bool _agreeToTerms = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Login Form',
          description: 'Complete login form with validation.',
          child: Form(
            key: _loginFormKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _loginLoading
                            ? null
                            : () async {
                              if (_loginFormKey.currentState!.validate()) {
                                setState(() => _loginLoading = true);
                                await Future.delayed(
                                  const Duration(seconds: 2),
                                );
                                if (mounted) {
                                  setState(() => _loginLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Login successful!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                    child:
                        _loginLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text('Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
        _DemoCard(
          title: 'Registration Form',
          description: 'Complete signup form with multiple fields.',
          child: Form(
            key: _signupFormKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: 'At least 8 characters with numbers and symbols',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    // In real app, compare with password field
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() => _agreeToTerms = value ?? false);
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _agreeToTerms = !_agreeToTerms);
                        },
                        child: const Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(color: Colors.blue),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _signupLoading || !_agreeToTerms
                            ? null
                            : () async {
                              if (_signupFormKey.currentState!.validate()) {
                                setState(() => _signupLoading = true);
                                await Future.delayed(
                                  const Duration(seconds: 2),
                                );
                                if (mounted) {
                                  setState(() => _signupLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Account created!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                    child:
                        _signupLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
