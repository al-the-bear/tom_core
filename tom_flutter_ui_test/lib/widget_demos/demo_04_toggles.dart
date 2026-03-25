/// Comprehensive Toggle Widgets Demo
///
/// This demo showcases all Flutter toggle widgets including switches,
/// checkboxes, radio buttons, and segmented controls with their various
/// configurations and styling options.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main toggles demo screen with all toggle categories.
class TogglesDemo extends StatelessWidget {
  const TogglesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Switch',
          subtitle: 'Binary toggle controls for on/off states',
        ),
        _SwitchSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Checkbox',
          subtitle: 'Selection controls for multiple options',
        ),
        _CheckboxSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Radio',
          subtitle: 'Single selection from mutually exclusive options',
        ),
        _RadioSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'SegmentedButton',
          subtitle: 'Horizontal selection of related options',
        ),
        _SegmentedButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'ToggleButtons',
          subtitle: 'Classic toggle buttons in a row',
        ),
        _ToggleButtonsSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Custom Toggles',
          subtitle: 'Building custom toggle components',
        ),
        _CustomTogglesSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Settings Examples',
          subtitle: 'Real-world toggle patterns',
        ),
        _SettingsExamplesSection(),
        TomSizedBox(height: 48),
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
    return TomPadding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const TomSizedBox(height: 4),
          TomText(
            subtitle,
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
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const TomSizedBox(height: 4),
              TomText(
                description!,
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
                  _expanded ? 'Hide code' : 'Show code',
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
// Switch Section
// =============================================================================

class _SwitchSection extends StatefulWidget {
  const _SwitchSection();

  @override
  State<_SwitchSection> createState() => _SwitchSectionState();
}

class _SwitchSectionState extends State<_SwitchSection> {
  bool _switch1 = false;
  bool _switch2 = true;
  bool _switch3 = false;
  bool _switchWithIcon = true;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Switch',
          description: 'Simple on/off toggle with state display.',
          child: TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TomText('Notifications: ${_switch1 ? "ON" : "OFF"}'),
              TomSwitch(
                tomId: 'demo.toggle.switch.basic',
                value: _switch1,
                onChanged: (value) => setState(() => _switch1 = value),
              ),
            ],
          ),
          code: '''
TomSwitch(
  tomId: 'app.settings.notifications',
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
)''',
        ),
        _DemoCard(
          title: 'SwitchListTile',
          description: 'Switch integrated with ListTile for settings UI.',
          child: TomColumn(
            children: [
              TomSwitchListTile(
                tomId: 'demo.toggle.switchlist.darkmode',
                title: const TomText('Dark Mode'),
                subtitle: const TomText('Use dark theme'),
                value: _switch2,
                onChanged: (value) => setState(() => _switch2 = value),
                secondary: TomIcon(
                  _switch2 ? Icons.dark_mode : Icons.light_mode,
                  color: _switch2 ? Colors.indigo : Colors.orange,
                ),
              ),
              const TomDivider(),
              TomSwitchListTile(
                tomId: 'demo.toggle.switchlist.airplane',
                title: const TomText('Airplane Mode'),
                subtitle: const TomText('Disable all wireless connections'),
                value: _switch3,
                onChanged: (value) => setState(() => _switch3 = value),
                secondary: TomIcon(
                  _switch3 ? Icons.airplanemode_active : Icons.airplanemode_inactive,
                ),
              ),
            ],
          ),
          code: '''
TomSwitchListTile(
  title: TomText('Dark Mode'),
  subtitle: TomText('Use dark theme'),
  value: _darkMode,
  onChanged: (value) => setState(() => _darkMode = value),
  secondary: TomIcon(Icons.dark_mode),
)''',
        ),
        _DemoCard(
          title: 'Switch with Thumb Icon',
          description: 'Material 3 switch with icon in thumb.',
          child: TomRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TomText('Wi-Fi'),
              TomSwitch(
                tomId: 'demo.toggle.switch.wifi',
                value: _switchWithIcon,
                onChanged: (value) => setState(() => _switchWithIcon = value),
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.wifi, size: 16);
                  }
                  return const Icon(Icons.wifi_off, size: 16);
                }),
              ),
            ],
          ),
          code: '''
TomSwitch(
  tomId: 'app.settings.wifi',
  value: _wifiEnabled,
  onChanged: (value) => setState(() => _wifiEnabled = value),
  thumbIcon: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return TomIcon(Icons.wifi, size: 16);
    }
    return TomIcon(Icons.wifi_off, size: 16);
  }),
)''',
        ),
        const _SwitchStylesDemo(),
      ],
    );
  }
}

class _SwitchStylesDemo extends StatefulWidget {
  const _SwitchStylesDemo();

  @override
  State<_SwitchStylesDemo> createState() => _SwitchStylesDemoState();
}

class _SwitchStylesDemoState extends State<_SwitchStylesDemo> {
  final _switches = [true, false, true, false];

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Switch Styling',
      description: 'Custom colors and track overlay.',
      child: TomColumn(
        children: [
          // Default
          _buildSwitchRow('Default', 0, null),
          const TomSizedBox(height: 8),
          // Custom active color
          _buildSwitchRow(
            'Custom Active',
            1,
            SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.green
                    : Colors.grey;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.green.shade200
                    : Colors.grey.shade300;
              }),
            ),
          ),
          const TomSizedBox(height: 8),
          // Purple theme
          _buildSwitchRow(
            'Purple Theme',
            2,
            SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.purple
                    : Colors.grey;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.purple.shade200
                    : Colors.grey.shade300;
              }),
            ),
          ),
          const TomSizedBox(height: 8),
          // Orange theme
          _buildSwitchRow(
            'Orange Theme',
            3,
            SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.orange
                    : Colors.grey;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.orange.shade200
                    : Colors.grey.shade300;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, int index, SwitchThemeData? theme) {
    final switchWidget = TomSwitch(
      value: _switches[index],
      onChanged: (value) => setState(() => _switches[index] = value),
    );

    return TomRow(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TomText(label),
        if (theme != null)
          SwitchTheme(data: theme, child: switchWidget)
        else
          switchWidget,
      ],
    );
  }
}

// =============================================================================
// Checkbox Section
// =============================================================================

class _CheckboxSection extends StatefulWidget {
  const _CheckboxSection();

  @override
  State<_CheckboxSection> createState() => _CheckboxSectionState();
}

class _CheckboxSectionState extends State<_CheckboxSection> {
  bool _check1 = false;
  bool _check2 = true;
  bool? _tristate;
  final _checkList = [false, true, false, false];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Checkbox',
          description: 'Simple checkbox with state display.',
          child: TomRow(
            children: [
              TomCheckbox(
                tomId: 'demo.toggle.checkbox.terms',
                value: _check1,
                onChanged: (value) => setState(() => _check1 = value ?? false),
              ),
              TomText('Agree to terms: ${_check1 ? "Yes" : "No"}'),
            ],
          ),
          code: '''
TomCheckbox(
  tomId: 'app.form.terms',
  value: _isChecked,
  onChanged: (value) => setState(() => _isChecked = value ?? false),
)''',
        ),
        _DemoCard(
          title: 'CheckboxListTile',
          description: 'Checkbox integrated with ListTile.',
          child: TomColumn(
            children: [
              TomCheckboxListTile(
                tomId: 'demo.toggle.checkboxlist.email',
                title: const TomText('Email notifications'),
                subtitle: const TomText('Receive updates via email'),
                value: _check2,
                onChanged: (value) => setState(() => _check2 = value ?? false),
                secondary: const TomIcon(Icons.email),
              ),
              ..._buildTodoItems(),
            ],
          ),
          code: '''
TomCheckboxListTile(
  tomId: 'app.settings.email_notifications',
  title: TomText('Email notifications'),
  subtitle: TomText('Receive updates via email'),
  value: _emailNotifications,
  onChanged: (value) => setState(() => _emailNotifications = value),
  secondary: TomIcon(Icons.email),
)''',
        ),
        _DemoCard(
          title: 'Tristate Checkbox',
          description: 'Three-state checkbox with null representing mixed state.',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomRow(
                children: [
                  TomCheckbox(
                    tomId: 'demo.toggle.checkbox.tristate',
                    tristate: true,
                    value: _tristate,
                    onChanged: (value) => setState(() => _tristate = value),
                  ),
                  TomText(_getTriStateLabel()),
                ],
              ),
              const TomSizedBox(height: 8),
              const TomText(
                'Use case: Select all / mixed selection parent checkbox',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
TomCheckbox(
  tomId: 'app.form.select_all',
  tristate: true,
  value: _tristate, // true, false, or null
  onChanged: (value) => setState(() => _tristate = value),
)''',
        ),
        const _CheckboxStylesDemo(),
      ],
    );
  }

  List<Widget> _buildTodoItems() {
    final items = ['Buy groceries', 'Call mom', 'Finish project', 'Exercise'];
    return List.generate(items.length, (index) {
      return TomCheckboxListTile(
        title: TomText(
          items[index],
          style: TextStyle(
            decoration:
                _checkList[index] ? TextDecoration.lineThrough : null,
            color: _checkList[index] ? Colors.grey : null,
          ),
        ),
        value: _checkList[index],
        onChanged: (value) {
          setState(() => _checkList[index] = value ?? false);
        },
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    });
  }

  String _getTriStateLabel() {
    if (_tristate == null) return 'Mixed (some selected)';
    return _tristate! ? 'All selected' : 'None selected';
  }
}

class _CheckboxStylesDemo extends StatefulWidget {
  const _CheckboxStylesDemo();

  @override
  State<_CheckboxStylesDemo> createState() => _CheckboxStylesDemoState();
}

class _CheckboxStylesDemoState extends State<_CheckboxStylesDemo> {
  final _checks = [true, true, true, true, false];

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Checkbox Styling',
      description: 'Custom colors, shapes, and sizes.',
      child: TomWrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // Default
          _buildCheckbox('Default', 0, null),
          // Custom color
          _buildCheckbox(
            'Green',
            1,
            TomCheckbox(
              value: _checks[1],
              onChanged: (v) => setState(() => _checks[1] = v!),
              activeColor: Colors.green,
              checkColor: Colors.white,
            ),
          ),
          // Rounded
          _buildCheckbox(
            'Rounded',
            2,
            TomCheckbox(
              value: _checks[2],
              onChanged: (v) => setState(() => _checks[2] = v!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Circle
          _buildCheckbox(
            'Circle',
            3,
            TomCheckbox(
              value: _checks[3],
              onChanged: (v) => setState(() => _checks[3] = v!),
              shape: const CircleBorder(),
            ),
          ),
          // Disabled
          _buildCheckbox(
            'Disabled',
            4,
            TomCheckbox(
              value: _checks[4],
              onChanged: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, int index, Widget? custom) {
    return TomColumn(
      children: [
        custom ?? TomCheckbox(
          value: _checks[index],
          onChanged: (v) => setState(() => _checks[index] = v!),
        ),
        TomText(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// =============================================================================
// Radio Section
// =============================================================================

class _RadioSection extends StatefulWidget {
  const _RadioSection();

  @override
  State<_RadioSection> createState() => _RadioSectionState();
}

class _RadioSectionState extends State<_RadioSection> {
  int _radioValue = 1;
  String _selectedPlan = 'basic';
  String _selectedPayment = 'card';

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic Radio',
          description: 'Simple radio button group.',
          child: TomColumn(
            children: [
              TomRow(
                children: [
                  TomRadio<int>(
                    tomId: 'demo.toggle.radio.opt1',
                    value: 1,
                    groupValue: _radioValue,
                    onChanged: (value) => setState(() => _radioValue = value!),
                  ),
                  const TomText('Option 1'),
                  const TomSizedBox(width: 16),
                  TomRadio<int>(
                    tomId: 'demo.toggle.radio.opt2',
                    value: 2,
                    groupValue: _radioValue,
                    onChanged: (value) => setState(() => _radioValue = value!),
                  ),
                  const TomText('Option 2'),
                  const TomSizedBox(width: 16),
                  TomRadio<int>(
                    tomId: 'demo.toggle.radio.opt3',
                    value: 3,
                    groupValue: _radioValue,
                    onChanged: (value) => setState(() => _radioValue = value!),
                  ),
                  const TomText('Option 3'),
                ],
              ),
              const TomSizedBox(height: 8),
              TomText(
                'Selected: Option $_radioValue',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
TomRadio<int>(
  tomId: 'app.form.option_1',
  value: 1,
  groupValue: _selectedValue,
  onChanged: (value) => setState(() => _selectedValue = value),
)''',
        ),
        _DemoCard(
          title: 'RadioListTile',
          description: 'Radio buttons with titles and subtitles.',
          child: TomColumn(
            children: [
              TomRadioListTile<String>(
                tomId: 'demo.toggle.radiolist.basic',
                title: const TomText('Basic Plan'),
                subtitle: const TomText('\$9.99/month'),
                value: 'basic',
                groupValue: _selectedPlan,
                onChanged: (value) => setState(() => _selectedPlan = value!),
                secondary: const TomIcon(Icons.star_border),
              ),
              TomRadioListTile<String>(
                tomId: 'demo.toggle.radiolist.pro',
                title: const TomText('Pro Plan'),
                subtitle: const TomText('\$19.99/month'),
                value: 'pro',
                groupValue: _selectedPlan,
                onChanged: (value) => setState(() => _selectedPlan = value!),
                secondary: const TomIcon(Icons.star_half),
              ),
              TomRadioListTile<String>(
                tomId: 'demo.toggle.radiolist.enterprise',
                title: const TomText('Enterprise Plan'),
                subtitle: const TomText('\$49.99/month'),
                value: 'enterprise',
                groupValue: _selectedPlan,
                onChanged: (value) => setState(() => _selectedPlan = value!),
                secondary: const TomIcon(Icons.star),
              ),
            ],
          ),
          code: '''
TomRadioListTile<String>(
  tomId: 'app.plan.basic',
  title: TomText('Basic Plan'),
  subtitle: TomText('\\\$9.99/month'),
  value: 'basic',
  groupValue: _selectedPlan,
  onChanged: (value) => setState(() => _selectedPlan = value),
  secondary: TomIcon(Icons.star_border),
)''',
        ),
        _DemoCard(
          title: 'Custom Radio Design',
          description: 'Card-based radio selection.',
          child: TomRow(
            children:
                ['card', 'paypal', 'crypto'].map((payment) {
                  final isSelected = _selectedPayment == payment;
                  return TomExpanded(
                    child: TomGestureDetector(
                      onTap: () => setState(() => _selectedPayment = payment),
                      child: TomContainer(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color:
                              isSelected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                        ),
                        child: TomColumn(
                          children: [
                            TomIcon(
                  _getPaymentIcon(payment),
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                            ),
                            const TomSizedBox(height: 4),
                            TomText(
                              _getPaymentLabel(payment),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String method) {
    return switch (method) {
      'card' => Icons.credit_card,
      'paypal' => Icons.account_balance_wallet,
      'crypto' => Icons.currency_bitcoin,
      _ => Icons.payment,
    };
  }

  String _getPaymentLabel(String method) {
    return switch (method) {
      'card' => 'Card',
      'paypal' => 'PayPal',
      'crypto' => 'Crypto',
      _ => method,
    };
  }
}

// =============================================================================
// SegmentedButton Section
// =============================================================================

class _SegmentedButtonSection extends StatefulWidget {
  const _SegmentedButtonSection();

  @override
  State<_SegmentedButtonSection> createState() =>
      _SegmentedButtonSectionState();
}

class _SegmentedButtonSectionState extends State<_SegmentedButtonSection> {
  String _viewMode = 'grid';
  Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'};
  String _selectedSize = 'M';

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Single Selection',
          description: 'Choose one option from the segment.',
          child: TomColumn(
            children: [
              TomSegmentedButton<String>(
                tomId: 'demo.toggle.segment.viewmode',
                segments: const [
                  ButtonSegment(
                    value: 'list',
                    icon: TomIcon(Icons.list),
                    label: TomText('List'),
                  ),
                  ButtonSegment(
                    value: 'grid',
                    icon: TomIcon(Icons.grid_view),
                    label: TomText('Grid'),
                  ),
                  ButtonSegment(
                    value: 'table',
                    icon: TomIcon(Icons.table_chart),
                    label: TomText('Table'),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (selection) {
                  setState(() => _viewMode = selection.first);
                },
              ),
              const TomSizedBox(height: 12),
              TomText(
                'View mode: ${_viewMode.toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
TomSegmentedButton<String>(
  tomId: 'app.view.mode',
  segments: [
    ButtonSegment(value: 'list', icon: TomIcon(Icons.list), label: TomText('List')),
    ButtonSegment(value: 'grid', icon: TomIcon(Icons.grid_view), label: TomText('Grid')),
  ],
  selected: {_viewMode},
  onSelectionChanged: (selection) {
    setState(() => _viewMode = selection.first);
  },
)''',
        ),
        _DemoCard(
          title: 'Multi Selection',
          description: 'Select multiple options from the segment.',
          child: TomColumn(
            children: [
              TomSegmentedButton<String>(
                tomId: 'demo.toggle.segment.days',
                segments: const [
                  ButtonSegment(value: 'Mon', label: TomText('M')),
                  ButtonSegment(value: 'Tue', label: TomText('T')),
                  ButtonSegment(value: 'Wed', label: TomText('W')),
                  ButtonSegment(value: 'Thu', label: TomText('T')),
                  ButtonSegment(value: 'Fri', label: TomText('F')),
                  ButtonSegment(value: 'Sat', label: TomText('S')),
                  ButtonSegment(value: 'Sun', label: TomText('S')),
                ],
                selected: _selectedDays,
                onSelectionChanged: (selection) {
                  setState(() => _selectedDays = selection);
                },
                multiSelectionEnabled: true,
                emptySelectionAllowed: true,
              ),
              const TomSizedBox(height: 12),
              TomText(
                'Selected: ${_selectedDays.isEmpty ? "None" : _selectedDays.join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Styled Segments',
          description: 'Customized appearance for segments.',
          child: TomSegmentedButton<String>(
            tomId: 'demo.toggle.segment.size',
            segments: const [
              ButtonSegment(value: 'XS', label: TomText('XS')),
              ButtonSegment(value: 'S', label: TomText('S')),
              ButtonSegment(value: 'M', label: TomText('M')),
              ButtonSegment(value: 'L', label: TomText('L')),
              ButtonSegment(value: 'XL', label: TomText('XL')),
            ],
            selected: {_selectedSize},
            onSelectionChanged: (selection) {
              setState(() => _selectedSize = selection.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.indigo;
                }
                return Colors.grey.shade100;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.black87;
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ToggleButtons Section
// =============================================================================

class _ToggleButtonsSection extends StatefulWidget {
  const _ToggleButtonsSection();

  @override
  State<_ToggleButtonsSection> createState() => _ToggleButtonsSectionState();
}

class _ToggleButtonsSectionState extends State<_ToggleButtonsSection> {
  final _isSelected1 = [true, false, false];
  final _isSelected2 = [false, true, false, true];
  final _isSelected3 = [true, false, false];

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Basic ToggleButtons',
          description: 'Single selection toggle buttons.',
          child: TomToggleButtons(
            tomId: 'demo.toggle.togglebtn.align',
            isSelected: _isSelected1,
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _isSelected1.length; i++) {
                  _isSelected1[i] = i == index;
                }
              });
            },
            children: [
              TomIcon(Icons.format_align_left),
              TomIcon(Icons.format_align_center),
              TomIcon(Icons.format_align_right),
            ],
          ),
          code: '''
TomToggleButtons(
  tomId: 'app.format.align',
  isSelected: _isSelected,
  onPressed: (index) {
    setState(() {
      for (int i = 0; i < _isSelected.length; i++) {
        _isSelected[i] = i == index;
      }
    });
  },
  children: [
    TomIcon(Icons.format_align_left),
    TomIcon(Icons.format_align_center),
    TomIcon(Icons.format_align_right),
  ],
)''',
        ),
        _DemoCard(
          title: 'Multi-Select ToggleButtons',
          description: 'Allow multiple selections.',
          child: TomToggleButtons(
            tomId: 'demo.toggle.togglebtn.style',
            isSelected: _isSelected2,
            onPressed: (index) {
              setState(() => _isSelected2[index] = !_isSelected2[index]);
            },
            children: [
              TomPadding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TomText('Bold'),
              ),
              TomPadding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TomText('Italic'),
              ),
              TomPadding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TomText('Underline'),
              ),
              TomPadding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TomText('Strike'),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Styled ToggleButtons',
          description: 'Custom colors and border radius.',
          child: TomToggleButtons(
            tomId: 'demo.toggle.togglebtn.period',
            isSelected: _isSelected3,
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _isSelected3.length; i++) {
                  _isSelected3[i] = i == index;
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            selectedBorderColor: Colors.purple,
            selectedColor: Colors.white,
            fillColor: Colors.purple,
            color: Colors.purple,
            constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
            children: [
              TomText('Day'),
              TomText('Week'),
              TomText('Month'),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Custom Toggles Section
// =============================================================================

class _CustomTogglesSection extends StatefulWidget {
  const _CustomTogglesSection();

  @override
  State<_CustomTogglesSection> createState() => _CustomTogglesSectionState();
}

class _CustomTogglesSectionState extends State<_CustomTogglesSection> {
  bool _customToggle1 = false;
  bool _customToggle2 = true;
  int _thumbsRating = 0; // -1, 0, 1

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Animated Toggle',
          description: 'Custom toggle with animation.',
          child: TomGestureDetector(
            onTap: () => setState(() => _customToggle1 = !_customToggle1),
            child: TomAnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _customToggle1 ? Colors.green : Colors.grey.shade300,
              ),
              child: TomAnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment:
                    _customToggle1 ? Alignment.centerRight : Alignment.centerLeft,
                child: TomContainer(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: TomIcon(
                  _customToggle1 ? Icons.check : Icons.close,
                    color: _customToggle1 ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          code: '''
TomGestureDetector(
  onTap: () => setState(() => _isOn = !_isOn),
  child: TomAnimatedContainer(
    duration: Duration(milliseconds: 200),
    width: 80,
    height: 40,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: _isOn ? Colors.green : Colors.grey,
    ),
    child: TomAnimatedAlign(
      alignment: _isOn ? Alignment.centerRight : Alignment.centerLeft,
      child: TomContainer(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    ),
  ),
)''',
        ),
        _DemoCard(
          title: 'Icon Toggle',
          description: 'Toggle between two icons.',
          child: TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TomText('Favorite:'),
              const TomSizedBox(width: 16),
              TomIconButton(
                onPressed: () =>
                    setState(() => _customToggle2 = !_customToggle2),
                icon: TomAnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return TomScaleTransition(scale: animation, child: child);
                  },
                  child: TomIcon(
                  _customToggle2 ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(_customToggle2),
                    color: _customToggle2 ? Colors.red : Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Thumbs Rating',
          description: 'Three-state toggle for like/neutral/dislike.',
          child: TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomIconButton(
                onPressed: () {
                  setState(() {
                    _thumbsRating = _thumbsRating == -1 ? 0 : -1;
                  });
                },
                icon: TomIcon(
                  _thumbsRating == -1
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  color: _thumbsRating == -1 ? Colors.red : Colors.grey,
                  size: 28,
                ),
              ),
              const TomSizedBox(width: 32),
              TomIconButton(
                onPressed: () {
                  setState(() {
                    _thumbsRating = _thumbsRating == 1 ? 0 : 1;
                  });
                },
                icon: TomIcon(
                  _thumbsRating == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: _thumbsRating == 1 ? Colors.green : Colors.grey,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Settings Examples Section
// =============================================================================

class _SettingsExamplesSection extends StatefulWidget {
  const _SettingsExamplesSection();

  @override
  State<_SettingsExamplesSection> createState() =>
      _SettingsExamplesSectionState();
}

class _SettingsExamplesSectionState extends State<_SettingsExamplesSection> {
  // Notification settings
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _smsEnabled = false;

  // Privacy settings
  String _visibility = 'public';
  bool _locationEnabled = false;
  bool _analyticsEnabled = true;

  // Appearance settings
  String _theme = 'system';
  double _fontSize = 1.0;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _DemoCard(
          title: 'Notification Settings',
          description: 'Grouped switches for notification preferences.',
          child: TomColumn(
            children: [
              TomSwitchListTile(
                tomId: 'demo.settings.notify.push',
                title: const TomText('Push Notifications'),
                subtitle: const TomText('Receive instant notifications'),
                value: _pushEnabled,
                onChanged: (v) => setState(() => _pushEnabled = v),
                secondary: const TomIcon(Icons.notifications),
              ),
              TomSwitchListTile(
                tomId: 'demo.settings.notify.email',
                title: const TomText('Email Updates'),
                subtitle: const TomText('Weekly digest and important updates'),
                value: _emailEnabled,
                onChanged: (v) => setState(() => _emailEnabled = v),
                secondary: const TomIcon(Icons.email),
              ),
              TomSwitchListTile(
                tomId: 'demo.settings.notify.sms',
                title: const TomText('SMS Alerts'),
                subtitle: const TomText('Critical alerts via SMS'),
                value: _smsEnabled,
                onChanged: (v) => setState(() => _smsEnabled = v),
                secondary: const TomIcon(Icons.sms),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Privacy Settings',
          description: 'Radio and switch combination for privacy.',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText(
                'Profile Visibility',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TomRadioListTile<String>(
                tomId: 'demo.settings.privacy.public',
                title: const TomText('Public'),
                subtitle: const TomText('Anyone can see your profile'),
                value: 'public',
                groupValue: _visibility,
                onChanged: (v) => setState(() => _visibility = v!),
              ),
              TomRadioListTile<String>(
                tomId: 'demo.settings.privacy.friends',
                title: const TomText('Friends Only'),
                subtitle: const TomText('Only friends can see your profile'),
                value: 'friends',
                groupValue: _visibility,
                onChanged: (v) => setState(() => _visibility = v!),
              ),
              TomRadioListTile<String>(
                tomId: 'demo.settings.privacy.private',
                title: const TomText('Private'),
                subtitle: const TomText('No one can see your profile'),
                value: 'private',
                groupValue: _visibility,
                onChanged: (v) => setState(() => _visibility = v!),
              ),
              const TomDivider(),
              TomSwitchListTile(
                tomId: 'demo.settings.privacy.location',
                title: const TomText('Location Services'),
                value: _locationEnabled,
                onChanged: (v) => setState(() => _locationEnabled = v),
                secondary: const TomIcon(Icons.location_on),
              ),
              TomSwitchListTile(
                tomId: 'demo.settings.privacy.analytics',
                title: const TomText('Usage Analytics'),
                value: _analyticsEnabled,
                onChanged: (v) => setState(() => _analyticsEnabled = v),
                secondary: const TomIcon(Icons.analytics),
              ),
            ],
          ),
        ),
        _DemoCard(
          title: 'Appearance Settings',
          description: 'Theme selection with segmented button.',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const TomSizedBox(height: 8),
              TomSegmentedButton<String>(
                tomId: 'demo.settings.appearance.theme',
                segments: const [
                  ButtonSegment(
                    value: 'light',
                    icon: TomIcon(Icons.light_mode),
                    label: TomText('Light'),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: TomIcon(Icons.dark_mode),
                    label: TomText('Dark'),
                  ),
                  ButtonSegment(
                    value: 'system',
                    icon: TomIcon(Icons.settings_brightness),
                    label: TomText('System'),
                  ),
                ],
                selected: {_theme},
                onSelectionChanged: (selection) {
                  setState(() => _theme = selection.first);
                },
              ),
              const TomSizedBox(height: 16),
              const TomText(
                'Font Size',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TomRow(
                children: [
                  const TomIcon(Icons.text_decrease, size: 20),
                  TomExpanded(
                    child: TomSlider(
                      value: _fontSize,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: '${(_fontSize * 100).round()}%',
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  const TomIcon(Icons.text_increase, size: 20),
                ],
              ),
              TomCenter(
                child: TomText(
                  'Preview Text',
                  style: TextStyle(fontSize: 16 * _fontSize),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
