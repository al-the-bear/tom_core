/// Tom Input Widgets Demo
///
/// This demo showcases Tom input widgets from tom_flutter_ui with their
/// Tom-specific features:
/// - tomId: Widget identification for tracking/analytics
/// - tomGroup: Group-based visibility and authorization
/// - Resource-resolved labels and hints (for i18n)
/// - All standard Flutter input parameters
///
/// Each input type is demonstrated with:
/// - Basic usage with Tom features
/// - Validation states (error, success, warning)
/// - Decoration options
/// - Input formatters
/// - Accessibility considerations
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main inputs demo screen with all input categories.
class InputsDemo extends StatelessWidget {
  const InputsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'TomTextField',
          subtitle: 'Tom-wrapped text input fields with resource resolution',
        ),
        _TextFieldSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomTextFormField',
          subtitle: 'Tom-wrapped form fields with validation support',
        ),
        _TextFormFieldSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Input Decorations',
          subtitle: 'Styling and decorating text inputs',
        ),
        _InputDecorationSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Password Fields',
          subtitle: 'Secure text entry with visibility toggle',
        ),
        _PasswordFieldSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Multi-line Text',
          subtitle: 'TextFields for longer text content',
        ),
        _MultilineTextSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Input Formatters',
          subtitle: 'Restricting and formatting input text',
        ),
        _InputFormattersSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Search Fields',
          subtitle: 'Optimized inputs for search functionality',
        ),
        _SearchFieldSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Date & Time Pickers',
          subtitle: 'Specialized inputs for date and time selection',
        ),
        _DateTimePickerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Form Examples',
          subtitle: 'Complete form implementations with validation',
        ),
        _FormExamplesSection(),
        TomSizedBox(height: 48),
      ],
    );
  }
}

String _slugify(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return normalized.replaceAll(RegExp(r'^_+|_+$'), '');
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
    final sectionId = 'section.inputs.${_slugify(title)}';
    return TomPadding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            null,
            tomId: sectionId,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(
            null,
            tomId: '$sectionId.subtitle',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const TomSizedBox(height: 8),
          TomContainer(
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
    final cardId = 'demo.input.card.${_slugify(title)}';
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              null,
              tomId: cardId,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const TomSizedBox(height: 4),
              TomText(
                null,
                tomId: '$cardId.description',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const TomSizedBox(height: 16),
            child,
            if (code != null) ...[
              const TomSizedBox(height: 16),
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
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomInkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: TomPadding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TomRow(
              children: [
                TomIcon(
                  _expanded ? Icons.code_off : Icons.code,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const TomSizedBox(width: 8),
                TomText(
                  null,
                  tomId: _expanded ? 'demo.code.hide' : 'demo.code.show',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const TomSpacer(),
                TomIcon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const TomSizedBox(height: 8),
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomSelectableText(
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic TomTextField',
          description: 'Simple text input with optional controller.',
          child: TomColumn(
            children: [
              TomTextField(
                tomId: 'demo.input.basic',
                controller: _basicController,
              ),
              const TomSizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: _basicController,
                builder: (context, value, _) => TomText(
                  'Current value: "${value.text}"',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          code: '''
TomTextField(
  controller: _textController,
  decoration: InputDecoration(
    hintText: 'Enter text here',
  ),
)''',
        ),
        _DemoCard(
          title: 'TomTextField with Label',
          description: 'Floating label that animates when focused.',
          child: TomTextField(
            tomId: 'demo.input.username',
            controller: _labelController,
          ),
          code: '''
TomTextField(
  decoration: InputDecoration(
    labelText: 'Username',
    hintText: 'Enter your username',
  ),
)''',
        ),
        _DemoCard(
          title: 'TomTextField with Prefix & Suffix',
          description: 'Add icons or text before/after the input.',
          child: TomColumn(
            children: [
              TomTextField(
                tomId: 'demo.input.email',
                decoration: const InputDecoration(
                  prefixIcon: TomIcon(Icons.email),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                tomId: 'demo.input.website',
                decoration: const InputDecoration(
                  prefixText: 'https://',
                  suffixText: '.com',
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                tomId: 'demo.input.search',
                controller: _prefixController,
                decoration: InputDecoration(
                  prefixIcon: const TomIcon(Icons.search),
                  suffixIcon: TomIconButton(
                    icon: const TomIcon(Icons.clear),
                    onPressed: () => _prefixController.clear(),
                  ),
                ),
              ),
            ],
          ),
          code: '''
TomTextField(
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: TomIcon(Icons.email),
    suffixIcon: TomIconButton(
      icon: TomIcon(Icons.clear),
      onPressed: () => controller.clear(),
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'TomTextField States',
          description: 'Enabled, disabled, and read-only states.',
          child: TomColumn(
            children: [
              const TomTextField(
                tomId: 'demo.input.enabled',
                decoration: InputDecoration(
                  helperText: 'This field is editable',
                ),
              ),
              const TomSizedBox(height: 16),
              const TomTextField(
                tomId: 'demo.input.disabled',
                enabled: false,
                decoration: InputDecoration(
                  helperText: 'This field is disabled',
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                tomId: 'demo.input.readonly',
                readOnly: true,
                controller: TextEditingController(text: 'Read-only value'),
                decoration: const InputDecoration(
                  helperText: 'This field is read-only',
                ),
              ),
            ],
          ),
          code: '''
// Disabled
TomTextField(
  enabled: false,
  decoration: InputDecoration(labelText: 'Disabled'),
)

// Read-only
TomTextField(
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Validation',
          description: 'TomTextFormField with validator function.',
          child: TomForm(
            key: _formKey,
            child: TomColumn(
              children: [
                TomTextFormField(
                  tomId: 'demo.form.email',
                  controller: _emailController,
                  decoration: const InputDecoration(
                    prefixIcon: TomIcon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const TomSizedBox(height: 16),
                TomTextFormField(
                  tomId: 'demo.form.phone',
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    prefixIcon: TomIcon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const TomSizedBox(height: 16),
                TomFilledButton(
                  tomId: 'demo.form.submit',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        TomSnackBar(
                          content: TomText(null, tomId: 'demo.02.auto.text.1'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          code: '''
TomTextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: TomIcon(Icons.email),
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
      child: TomColumn(
        children: [
          // Success state
          TomTextFormField(
            tomId: 'demo.form.success',
            initialValue: 'valid@email.com',
            decoration: InputDecoration(
              prefixIcon: const TomIcon(Icons.check_circle, color: Colors.green),
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
          const TomSizedBox(height: 16),
          // Error state
          TomTextFormField(
            tomId: 'demo.form.error',
            initialValue: 'invalid-email',
            decoration: InputDecoration(
              prefixIcon: const TomIcon(Icons.error, color: Colors.red),
              errorText: 'Please enter a valid email address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const TomSizedBox(height: 16),
          // Warning state
          TomTextFormField(
            tomId: 'demo.form.warning',
            initialValue: 'weak_password',
            decoration: InputDecoration(
              prefixIcon: const TomIcon(Icons.warning, color: Colors.orange),
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Border Styles',
          description: 'Different border variants for text fields.',
          child: TomColumn(
            children: [
              TomTextField(
                tomId: 'demo.deco.outline',
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              const TomTextField(
                tomId: 'demo.deco.underline',
                decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                ),
              ),
              const TomSizedBox(height: 16),
              const TomTextField(
                tomId: 'demo.deco.noborder',
                decoration: InputDecoration(
                  filled: true,
                  border: InputBorder.none,
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                tomId: 'demo.deco.stadium',
                decoration: InputDecoration(
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
TomTextField(
  decoration: InputDecoration(
    labelText: 'Label',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)

// Filled with stadium shape
TomTextField(
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
          child: TomColumn(
            children: [
              TomTextField(
                decoration: InputDecoration(
                  labelText: 'Default Fill',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
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
              const TomSizedBox(height: 16),
              TomTextField(
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
          child: TomColumn(
            children: [
              const TomTextField(
                tomId: 'demo.deco.counter',
                maxLength: 50,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
                tomId: 'demo.deco.maxlength',
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              const TomTextField(
                tomId: 'demo.deco.customcounter',
                maxLength: 280,
                buildCounter: _buildCustomCounter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          code: '''
TomTextField(
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

  return TomText(
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Password Field',
          description: 'Toggle visibility with suffix icon.',
          child: TomTextField(
            tomId: 'demo.password.basic',
            obscureText: _obscureText1,
            decoration: InputDecoration(
              prefixIcon: const TomIcon(Icons.lock),
              suffixIcon: TomIconButton(
                icon: TomIcon(
                  _obscureText1 ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureText1 = !_obscureText1),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          code: '''
TomTextField(
  obscureText: _obscureText,
  decoration: InputDecoration(
    labelText: 'Password',
    prefixIcon: TomIcon(Icons.lock),
    suffixIcon: TomIconButton(
      icon: TomIcon(
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
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomTextField(
                controller: _passwordController,
                obscureText: _obscureText2,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  labelText: 'Create Password',
                  prefixIcon: const TomIcon(Icons.lock),
                  suffixIcon: TomIconButton(
                    icon: TomIcon(
                  _obscureText2 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText2 = !_obscureText2),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const TomSizedBox(height: 8),
              if (_passwordController.text.isNotEmpty) ...[
                TomClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TomLinearProgressIndicator(
                    value: _passwordStrength,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_getStrengthColor()),
                    minHeight: 8,
                  ),
                ),
                const TomSizedBox(height: 4),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TomText(
                      'Strength: ${_getStrengthText()}',
                      style: TextStyle(
                        color: _getStrengthColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TomText(
                      '${(_passwordStrength * 100).toInt()}%',
                      style: TextStyle(color: _getStrengthColor()),
                    ),
                  ],
                ),
                const TomSizedBox(height: 8),
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
    return TomPadding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TomRow(
        children: [
          TomIcon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const TomSizedBox(width: 8),
          TomText(
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Multi-line TextField',
          description: 'Expandable text area for longer content.',
          child: TomColumn(
            children: [
              TomTextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Fixed 3 lines',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
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
              const TomSizedBox(height: 16),
              TomTextField(
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
TomTextField(
  maxLines: 3,
  decoration: InputDecoration(
    labelText: 'Fixed 3 lines',
    alignLabelWithHint: true,
    border: OutlineInputBorder(),
  ),
)

// Expandable
TomTextField(
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
          child: TomTextField(
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Digit Only Input',
          description: 'Using FilteringTextInputFormatter for numbers.',
          child: TomColumn(
            children: [
              TomTextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Numbers Only',
                  hintText: 'Only digits allowed',
                  prefixIcon: const TomIcon(Icons.pin),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const TomSizedBox(height: 16),
              TomTextField(
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
TomTextField(
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
  ],
)

// Allow decimals
TomTextField(
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[\\d.]')),
  ],
)''',
        ),
        _DemoCard(
          title: 'Uppercase Input',
          description: 'Auto-convert text to uppercase.',
          child: TomTextField(
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

TomTextField(
  inputFormatters: [UpperCaseTextFormatter()],
)''',
        ),
        _DemoCard(
          title: 'Phone Number Formatter',
          description: 'Auto-format input as phone number.',
          child: TomTextField(
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
              PhoneNumberFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '(555) 123-4567',
              prefixIcon: const TomIcon(Icons.phone),
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
          child: TomTextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              CreditCardFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Card Number',
              hintText: '1234 5678 9012 3456',
              prefixIcon: const TomIcon(Icons.credit_card),
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Search Field',
          description: 'TextField styled for search functionality.',
          child: TomTextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const TomIcon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? TomIconButton(
                        icon: const TomIcon(Icons.clear),
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
TomTextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: 'Search...',
    prefixIcon: TomIcon(Icons.search),
    suffixIcon: _searchController.text.isNotEmpty
        ? TomIconButton(
            icon: TomIcon(Icons.clear),
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
          child: TomSearchAnchor(
            searchController: _searchBarController,
            builder: (context, controller) {
              return TomSearchBar(
                controller: controller,
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                leading: const TomIcon(Icons.search),
                hintText: 'Search topics...',
                trailing: [
                  if (controller.text.isNotEmpty)
                    TomIconButton(
                      icon: const TomIcon(Icons.close),
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
                (suggestion) => TomListTile(
                  leading: const TomIcon(Icons.topic),
                  title: TomText(suggestion),
                  onTap: () {
                    controller.closeView(suggestion);
                  },
                ),
              );
            },
          ),
          code: '''
TomSearchAnchor(
  searchController: _controller,
  builder: (context, controller) {
    return TomSearchBar(
      controller: controller,
      onTap: () => controller.openView(),
      leading: TomIcon(Icons.search),
      hintText: 'Search...',
    );
  },
  suggestionsBuilder: (context, controller) {
    return suggestions
        .where((s) => s.contains(controller.text))
        .map((s) => TomListTile(
              title: TomText(s),
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Date Picker',
          description: 'TextField that triggers date picker dialog.',
          child: TomTextField(
            readOnly: true,
            onTap: _pickDate,
            controller: TextEditingController(
              text: _selectedDate != null ? _formatDate(_selectedDate!) : '',
            ),
            decoration: InputDecoration(
              labelText: 'Select Date',
              hintText: 'Tap to select',
              prefixIcon: const TomIcon(Icons.calendar_today),
              suffixIcon: TomIconButton(
                icon: const TomIcon(Icons.clear),
                onPressed: () => setState(() => _selectedDate = null),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          code: '''
TomTextField(
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
    prefixIcon: TomIcon(Icons.calendar_today),
  ),
)''',
        ),
        _DemoCard(
          title: 'Time Picker',
          description: 'TextField that triggers time picker dialog.',
          child: TomTextField(
            readOnly: true,
            onTap: _pickTime,
            controller: TextEditingController(
              text: _selectedTime?.format(context) ?? '',
            ),
            decoration: InputDecoration(
              labelText: 'Select Time',
              hintText: 'Tap to select',
              prefixIcon: const TomIcon(Icons.access_time),
              suffixIcon: TomIconButton(
                icon: const TomIcon(Icons.clear),
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
          child: TomTextField(
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
              prefixIcon: const TomIcon(Icons.date_range),
              suffixIcon: TomIconButton(
                icon: const TomIcon(Icons.clear),
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
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Login Form',
          description: 'Complete login form with validation.',
          child: TomForm(
            key: _loginFormKey,
            child: TomColumn(
              children: [
                TomTextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const TomIcon(Icons.email),
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
                const TomSizedBox(height: 16),
                TomTextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const TomIcon(Icons.lock),
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
                const TomSizedBox(height: 8),
                TomRow(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TomTextButton(
                      onPressed: () {},
                      child: const TomText(null, tomId: 'demo.02.auto.text.2'),
                    ),
                  ],
                ),
                const TomSizedBox(height: 16),
                TomSizedBox(
                  width: double.infinity,
                  child: TomFilledButton(
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
                                    TomSnackBar(
                                      content: TomText(null, tomId: 'demo.02.auto.text.3'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                    child:
                        _loginLoading
                            ? const TomSizedBox(
                              width: 20,
                              height: 20,
                              child: TomCircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const TomText(null, tomId: 'demo.02.auto.text.4'),
                  ),
                ),
              ],
            ),
          ),
        ),
        _DemoCard(
          title: 'Registration Form',
          description: 'Complete signup form with multiple fields.',
          child: TomForm(
            key: _signupFormKey,
            child: TomColumn(
              children: [
                TomRow(
                  children: [
                    TomExpanded(
                      child: TomTextFormField(
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
                    const TomSizedBox(width: 16),
                    TomExpanded(
                      child: TomTextFormField(
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
                const TomSizedBox(height: 16),
                TomTextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const TomIcon(Icons.email),
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
                const TomSizedBox(height: 16),
                TomTextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const TomIcon(Icons.lock),
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
                const TomSizedBox(height: 16),
                TomTextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const TomIcon(Icons.lock_outline),
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
                const TomSizedBox(height: 16),
                TomRow(
                  children: [
                    TomCheckbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() => _agreeToTerms = value ?? false);
                      },
                    ),
                    TomExpanded(
                      child: TomGestureDetector(
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
                const TomSizedBox(height: 16),
                TomSizedBox(
                  width: double.infinity,
                  child: TomFilledButton(
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
                                    TomSnackBar(
                                      content: TomText(null, tomId: 'demo.02.auto.text.5'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                    child:
                        _signupLoading
                            ? const TomSizedBox(
                              width: 20,
                              height: 20,
                              child: TomCircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const TomText(null, tomId: 'demo.02.auto.text.6'),
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
