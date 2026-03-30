/// Demo 04: Toggle & Switch Suite
///
/// Comprehensive demonstration of all Tom toggle widgets.
/// Widgets covered: TomSwitch, TomSwitchListTile, TomCupertinoSwitch,
/// TomCheckbox, TomCheckboxListTile, TomCupertinoCheckbox,
/// TomRadio, TomRadioListTile, TomCupertinoRadio, TomToggleButtons.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Toggle & Switch Suite demo.
class ToggleDemo extends StatelessWidget {
  const ToggleDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ToggleDemoContent();
  }
}

class _ToggleDemoContent extends StatefulWidget {
  const _ToggleDemoContent();

  @override
  State<_ToggleDemoContent> createState() => _ToggleDemoContentState();
}

class _ToggleDemoContentState extends State<_ToggleDemoContent> {
  // ===========================================================================
  // Section 1: Switch state
  // ===========================================================================
  bool _switchDefault = false;
  bool _switchThumbIcon = true;
  final bool _switchDisabled = false;
  bool _switchCustomGreen = true;
  bool _switchCustomOrange = false;

  // SwitchListTile state
  bool _notifications = true;
  bool _darkMode = false;
  bool _locationServices = true;

  // CupertinoSwitch state
  bool _cupertinoSwitch = false;
  bool _cupertinoSwitchThemed = true;

  // ===========================================================================
  // Section 2: Checkbox state
  // ===========================================================================
  bool _checkDefault = false;
  bool? _checkTristate; // null = indeterminate
  bool _checkCustomColor = true;
  final bool _checkDisabled = true;

  // CheckboxListTile state
  bool _categoryTechnology = true;
  bool _categoryScience = false;
  bool _categoryBusiness = true;
  bool _checkboxLeading = false;

  // CupertinoCheckbox state
  bool _cupertinoCheck = false;
  bool _cupertinoCheckActive = true;

  // ===========================================================================
  // Section 3: Radio state
  // ===========================================================================
  String? _paymentMethod = 'credit';
  String? _shirtSize = 'medium';

  // RadioListTile state
  String? _shippingMethod = 'standard';

  // CupertinoRadio state
  String? _cupertinoOption = 'a';

  // ===========================================================================
  // Section 4: ToggleButtons state
  // ===========================================================================
  final List<bool> _viewSelection = [true, false, false, false]; // single select
  final List<bool> _formatSelection = [true, false, true, false]; // multi select
  final List<bool> _alignSelection = [false, true, false]; // vertical single

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  bool _aclSwitch = false;
  bool _aclCheckbox = false;
  String? _aclRadio = 'option1';

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Switch Controls
            _SectionHeader(tomId: 'demo04.section.switch'),
            const TomSizedBox(height: 16),
            _buildSwitchSection(),
            const TomSizedBox(height: 24),
            _buildSwitchListTileSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoSwitchSection(),
            const TomSizedBox(height: 32),

            // Section 2: Checkbox Controls
            _SectionHeader(tomId: 'demo04.section.checkbox'),
            const TomSizedBox(height: 16),
            _buildCheckboxSection(),
            const TomSizedBox(height: 24),
            _buildCheckboxListTileSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoCheckboxSection(),
            const TomSizedBox(height: 32),

            // Section 3: Radio Controls
            _SectionHeader(tomId: 'demo04.section.radio'),
            const TomSizedBox(height: 16),
            _buildRadioSection(),
            const TomSizedBox(height: 24),
            _buildRadioListTileSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoRadioSection(),
            const TomSizedBox(height: 32),

            // Section 4: Toggle Button Groups
            _SectionHeader(tomId: 'demo04.section.toggleButtons'),
            const TomSizedBox(height: 16),
            _buildToggleButtonsSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo
            _SectionHeader(tomId: 'demo04.section.acl'),
            const TomSizedBox(height: 16),
            _buildAclToggleSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Switch Controls
  // ===========================================================================

  Widget _buildSwitchSection() {
    return _DemoCard(
      tomId: 'demo04.switch',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Default state
          TomText(tomId: 'demo04.switch.defaultLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomText(
                text: _switchDefault ? 'On' : 'Off',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const TomSizedBox(width: 8),
              TomSwitch(
                value: _switchDefault,
                onChanged: (v) => setState(() => _switchDefault = v),
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // With thumb icon
          TomText(tomId: 'demo04.switch.thumbIconLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomSwitch(
                value: _switchThumbIcon,
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.check, size: 16);
                  }
                  return const Icon(Icons.close, size: 16);
                }),
                onChanged: (v) => setState(() => _switchThumbIcon = v),
              ),
              const TomSizedBox(width: 8),
              TomText(
                text: _switchThumbIcon ? 'Enabled' : 'Disabled',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Disabled
          TomText(tomId: 'demo04.switch.disabledLabel'),
          const TomSizedBox(height: 8),
          TomSwitch(
            value: _switchDisabled,
            onChanged: null,
          ),
          const TomSizedBox(height: 16),

          // Custom colors
          TomText(tomId: 'demo04.switch.customColorLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomSwitch(
                value: _switchCustomGreen,
                activeTrackColor: Colors.green,
                onChanged: (v) => setState(() => _switchCustomGreen = v),
              ),
              const TomSizedBox(width: 16),
              TomSwitch(
                value: _switchCustomOrange,
                activeTrackColor: Colors.orange,
                onChanged: (v) => setState(() => _switchCustomOrange = v),
              ),
            ],
          ),
          const TomSizedBox(height: 12),

          // Status display
          TomText(
            text: 'Default: ${_switchDefault ? "ON" : "OFF"}, '
                'Thumb Icon: ${_switchThumbIcon ? "ON" : "OFF"}, '
                'Green: ${_switchCustomGreen ? "ON" : "OFF"}, '
                'Orange: ${_switchCustomOrange ? "ON" : "OFF"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchListTileSection() {
    return _DemoCard(
      tomId: 'demo04.switchListTile',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomSwitchListTile(
            tomId: 'demo04.switchListTile.notifications',
            value: _notifications,
            secondary: const TomIcon(icon: Icons.notifications),
            subtitle: TomText(tomId: 'demo04.switchListTile.notifications.subtitle'),
            onChanged: (v) => setState(() => _notifications = v),
          ),
          const TomDivider(height: 1),
          TomSwitchListTile(
            tomId: 'demo04.switchListTile.darkMode',
            value: _darkMode,
            secondary: const TomIcon(icon: Icons.dark_mode),
            subtitle: TomText(tomId: 'demo04.switchListTile.darkMode.subtitle'),
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          const TomDivider(height: 1),
          TomSwitchListTile(
            tomId: 'demo04.switchListTile.location',
            value: _locationServices,
            secondary: const TomIcon(icon: Icons.location_on),
            subtitle: TomText(tomId: 'demo04.switchListTile.location.subtitle'),
            onChanged: (v) => setState(() => _locationServices = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoSwitchSection() {
    return _DemoCard(
      tomId: 'demo04.cupertinoSwitch',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo04.cupertinoSwitch.defaultLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomCupertinoSwitch(
                value: _cupertinoSwitch,
                onChanged: (v) => setState(() => _cupertinoSwitch = v),
              ),
              const TomSizedBox(width: 16),
              TomText(
                text: _cupertinoSwitch ? 'On' : 'Off',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          TomText(tomId: 'demo04.cupertinoSwitch.themedLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              TomCupertinoSwitch(
                value: _cupertinoSwitchThemed,
                activeTrackColor: CupertinoColors.activeGreen,
                onChanged: (v) => setState(() => _cupertinoSwitchThemed = v),
              ),
              const TomSizedBox(width: 16),
              TomText(
                text: _cupertinoSwitchThemed ? 'Active' : 'Inactive',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Checkbox Controls
  // ===========================================================================

  Widget _buildCheckboxSection() {
    return _DemoCard(
      tomId: 'demo04.checkbox',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // States row
          TomText(tomId: 'demo04.checkbox.statesLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              // Default checkbox
              TomCheckbox(
                value: _checkDefault,
                onChanged: (v) => setState(() => _checkDefault = v ?? false),
              ),
              TomText(
                text: _checkDefault ? 'Checked' : 'Unchecked',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const TomSizedBox(width: 24),

              // Tristate checkbox
              TomCheckbox(
                value: _checkTristate,
                tristate: true,
                onChanged: (v) => setState(() => _checkTristate = v),
              ),
              TomText(
                text: _checkTristate == null
                    ? 'Indeterminate'
                    : _checkTristate! ? 'Checked' : 'Unchecked',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Variants
          TomText(tomId: 'demo04.checkbox.variantsLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              // Custom color
              TomCheckbox(
                value: _checkCustomColor,
                activeColor: Colors.green,
                checkColor: Colors.white,
                onChanged: (v) => setState(() => _checkCustomColor = v ?? false),
              ),
              TomText(tomId: 'demo04.checkbox.customColor'),
              const TomSizedBox(width: 16),

              // Rounded shape
              TomCheckbox(
                value: true,
                shape: const CircleBorder(),
                onChanged: (v) {},
              ),
              TomText(tomId: 'demo04.checkbox.rounded'),
              const TomSizedBox(width: 16),

              // Disabled
              TomCheckbox(
                value: _checkDisabled,
                onChanged: null,
              ),
              TomText(tomId: 'demo04.checkbox.disabled'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxListTileSection() {
    return _DemoCard(
      tomId: 'demo04.checkboxListTile',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo04.checkboxListTile.categoriesLabel'),
          const TomSizedBox(height: 8),
          TomCheckboxListTile(
            tomId: 'demo04.checkboxListTile.technology',
            value: _categoryTechnology,
            subtitle: TomText(tomId: 'demo04.checkboxListTile.technology.subtitle'),
            secondary: const TomIcon(icon: Icons.computer),
            onChanged: (v) => setState(() => _categoryTechnology = v ?? false),
          ),
          const TomDivider(height: 1),
          TomCheckboxListTile(
            tomId: 'demo04.checkboxListTile.science',
            value: _categoryScience,
            subtitle: TomText(tomId: 'demo04.checkboxListTile.science.subtitle'),
            secondary: const TomIcon(icon: Icons.science),
            onChanged: (v) => setState(() => _categoryScience = v ?? false),
          ),
          const TomDivider(height: 1),
          TomCheckboxListTile(
            tomId: 'demo04.checkboxListTile.business',
            value: _categoryBusiness,
            subtitle: TomText(tomId: 'demo04.checkboxListTile.business.subtitle'),
            secondary: const TomIcon(icon: Icons.business),
            onChanged: (v) => setState(() => _categoryBusiness = v ?? false),
          ),
          const TomSizedBox(height: 16),

          // Leading vs trailing demo
          TomText(tomId: 'demo04.checkboxListTile.positionLabel'),
          const TomSizedBox(height: 8),
          TomCheckboxListTile(
            tomId: 'demo04.checkboxListTile.leading',
            value: _checkboxLeading,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _checkboxLeading = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoCheckboxSection() {
    return _DemoCard(
      tomId: 'demo04.cupertinoCheckbox',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              TomCupertinoCheckbox(
                value: _cupertinoCheck,
                onChanged: (v) => setState(() => _cupertinoCheck = v ?? false),
              ),
              const TomSizedBox(width: 8),
              TomText(
                text: _cupertinoCheck ? 'Checked' : 'Unchecked',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const TomSizedBox(width: 24),
              TomCupertinoCheckbox(
                value: _cupertinoCheckActive,
                activeColor: CupertinoColors.activeGreen,
                onChanged: (v) => setState(() => _cupertinoCheckActive = v ?? false),
              ),
              const TomSizedBox(width: 8),
              TomText(
                text: _cupertinoCheckActive ? 'Checked' : 'Unchecked',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Radio Controls
  // ===========================================================================

  Widget _buildRadioSection() {
    return _DemoCard(
      tomId: 'demo04.radio',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment method (vertical)
          TomText(tomId: 'demo04.radio.paymentLabel'),
          const TomSizedBox(height: 8),
          ..._buildPaymentRadios(),
          const TomSizedBox(height: 16),

          // Shirt size (horizontal)
          TomText(tomId: 'demo04.radio.sizeLabel'),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              _buildSizeRadio('small', 'S'),
              _buildSizeRadio('medium', 'M'),
              _buildSizeRadio('large', 'L'),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            text: 'Payment: $_paymentMethod, Size: $_shirtSize',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentRadios() {
    const methods = ['credit', 'paypal', 'bank', 'cash'];
    return methods.map((method) {
      return TomRow(
        children: [
          TomRadio<String>(
            value: method,
            groupValue: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          const TomSizedBox(width: 4),
          TomText(tomId: 'demo04.radio.payment.$method'),
        ],
      );
    }).toList();
  }

  Widget _buildSizeRadio(String value, String label) {
    return TomRow(
      mainAxisSize: MainAxisSize.min,
      children: [
        TomRadio<String>(
          value: value,
          groupValue: _shirtSize,
          onChanged: (v) => setState(() => _shirtSize = v),
        ),
        TomText(text: label),
        const TomSizedBox(width: 12),
      ],
    );
  }

  Widget _buildRadioListTileSection() {
    return _DemoCard(
      tomId: 'demo04.radioListTile',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'demo04.radioListTile.shippingLabel'),
          const TomSizedBox(height: 8),
          TomRadioListTile<String>(
            tomId: 'demo04.radioListTile.standard',
            value: 'standard',
            groupValue: _shippingMethod,
            subtitle: TomText(tomId: 'demo04.radioListTile.standard.subtitle'),
            secondary: const TomIcon(icon: Icons.local_shipping),
            onChanged: (v) => setState(() => _shippingMethod = v),
          ),
          const TomDivider(height: 1),
          TomRadioListTile<String>(
            tomId: 'demo04.radioListTile.express',
            value: 'express',
            groupValue: _shippingMethod,
            subtitle: TomText(tomId: 'demo04.radioListTile.express.subtitle'),
            secondary: const TomIcon(icon: Icons.flight),
            onChanged: (v) => setState(() => _shippingMethod = v),
          ),
          const TomDivider(height: 1),
          TomRadioListTile<String>(
            tomId: 'demo04.radioListTile.nextDay',
            value: 'nextDay',
            groupValue: _shippingMethod,
            subtitle: TomText(tomId: 'demo04.radioListTile.nextDay.subtitle'),
            secondary: const TomIcon(icon: Icons.rocket_launch),
            onChanged: (v) => setState(() => _shippingMethod = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoRadioSection() {
    return _DemoCard(
      tomId: 'demo04.cupertinoRadio',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              _buildCupertinoRadioOption('a', 'Option A'),
              const TomSizedBox(width: 16),
              _buildCupertinoRadioOption('b', 'Option B'),
              const TomSizedBox(width: 16),
              _buildCupertinoRadioOption('c', 'Option C'),
            ],
          ),
          const TomSizedBox(height: 12),
          TomText(
            text: 'Selected: ${_cupertinoOption?.toUpperCase() ?? "none"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoRadioOption(String value, String label) {
    return TomRow(
      mainAxisSize: MainAxisSize.min,
      children: [
        TomCupertinoRadio<String>(
          value: value,
          groupValue: _cupertinoOption,
          onChanged: (v) => setState(() => _cupertinoOption = v),
        ),
        const TomSizedBox(width: 4),
        TomText(text: label),
      ],
    );
  }

  // ===========================================================================
  // Section 4: Toggle Button Groups
  // ===========================================================================

  Widget _buildToggleButtonsSection() {
    return _DemoCard(
      tomId: 'demo04.toggleButtons',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single select (exclusive)
          TomText(tomId: 'demo04.toggleButtons.singleLabel'),
          const TomSizedBox(height: 8),
          TomToggleButtons(
            isSelected: _viewSelection,
            borderRadius: BorderRadius.circular(8),
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _viewSelection.length; i++) {
                  _viewSelection[i] = i == index;
                }
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.calendar_today), Text('Day')],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.calendar_view_week), Text('Week')],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.calendar_month), Text('Month')],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.trending_up), Text('Year')],
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Multi select (non-exclusive)
          TomText(tomId: 'demo04.toggleButtons.multiLabel'),
          const TomSizedBox(height: 8),
          TomToggleButtons(
            isSelected: _formatSelection,
            borderRadius: BorderRadius.circular(8),
            onPressed: (index) {
              setState(() => _formatSelection[index] = !_formatSelection[index]);
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('B', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('U', style: TextStyle(decoration: TextDecoration.underline)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('S', style: TextStyle(decoration: TextDecoration.lineThrough)),
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Vertical layout
          TomText(tomId: 'demo04.toggleButtons.verticalLabel'),
          const TomSizedBox(height: 8),
          TomToggleButtons(
            isSelected: _alignSelection,
            direction: Axis.vertical,
            borderRadius: BorderRadius.circular(8),
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _alignSelection.length; i++) {
                  _alignSelection[i] = i == index;
                }
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_align_left, size: 18),
                    SizedBox(width: 8),
                    Text('Left'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_align_center, size: 18),
                    SizedBox(width: 8),
                    Text('Center'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_align_right, size: 18),
                    SizedBox(width: 8),
                    Text('Right'),
                  ],
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Custom styled toggle buttons
          TomText(tomId: 'demo04.toggleButtons.customLabel'),
          const TomSizedBox(height: 8),
          TomToggleButtons(
            isSelected: _viewSelection,
            borderRadius: BorderRadius.circular(20),
            selectedColor: Colors.white,
            fillColor: Theme.of(context).colorScheme.primary,
            borderColor: Theme.of(context).colorScheme.outline,
            selectedBorderColor: Theme.of(context).colorScheme.primary,
            onPressed: (index) {
              setState(() {
                for (int i = 0; i < _viewSelection.length; i++) {
                  _viewSelection[i] = i == index;
                }
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.calendar_today),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.calendar_view_week),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.calendar_month),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.trending_up),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo
  // ===========================================================================

  Widget _buildAclToggleSection() {
    return _DemoCard(
      tomId: 'demo04.aclToggle',
      child: AclBuilder()
          // Row 1: Label + Switch
          .append(TomText(tomId: 'demo04.aclToggle.enableLabel'))
          .append(
            TomSwitch(
              value: _aclSwitch,
              onChanged: (v) => setState(() => _aclSwitch = v),
            ),
            dist: 16,
          )
          .newRow(dist: 16)
          // Row 2: Label + Checkbox
          .append(TomText(tomId: 'demo04.aclToggle.agreeLabel'))
          .append(
            TomCheckbox(
              value: _aclCheckbox,
              onChanged: (v) => setState(() => _aclCheckbox = v ?? false),
            ),
            dist: 16,
          )
          .newRow(dist: 16)
          // Row 3: Radio options
          .append(TomText(tomId: 'demo04.aclToggle.chooseLabel'))
          .gap()
          .newRow(dist: 8)
          .append(
            TomRow(
              children: [
                TomRadio<String>(
                  value: 'option1',
                  groupValue: _aclRadio,
                  onChanged: (v) => setState(() => _aclRadio = v),
                ),
                TomText(tomId: 'demo04.aclToggle.option1'),
                const TomSizedBox(width: 16),
                TomRadio<String>(
                  value: 'option2',
                  groupValue: _aclRadio,
                  onChanged: (v) => setState(() => _aclRadio = v),
                ),
                TomText(tomId: 'demo04.aclToggle.option2'),
                const TomSizedBox(width: 16),
                TomRadio<String>(
                  value: 'option3',
                  groupValue: _aclRadio,
                  onChanged: (v) => setState(() => _aclRadio = v),
                ),
                TomText(tomId: 'demo04.aclToggle.option3'),
              ],
            ),
          )
          .newRow(dist: 16)
          // Row 4: Action buttons
          .append(
            TomTextButton(
              tomId: 'demo04.aclToggle.reset',
              onPressed: () {
                setState(() {
                  _aclSwitch = false;
                  _aclCheckbox = false;
                  _aclRadio = 'option1';
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'demo04.aclToggle.apply',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget for demo sections.
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({
    required this.tomId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
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
    );
  }
}

/// Demo card widget for individual widget showcases.
class _DemoCard extends StatelessWidget {
  final String tomId;
  final Widget child;

  const _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      elevation: 2,
      child: TomPadding(
        padding: const EdgeInsets.all(20),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomContainer(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomIcon(
                    tomId: '$tomId.icon',
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.description',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            TomDivider(color: theme.colorScheme.outlineVariant),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
