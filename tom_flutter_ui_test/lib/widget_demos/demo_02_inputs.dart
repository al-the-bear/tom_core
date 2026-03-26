/// Demo 02: Text Input Gallery
///
/// Comprehensive demonstration of all Tom text input widgets.
/// Widgets covered: TomTextField, TomTextFormField, TomSearchBar,
/// TomAutocomplete, TomSearchAnchor, TomCupertinoTextField,
/// TomCupertinoSearchTextField, TomCupertinoTextFormFieldRow,
/// TomCalendarDatePicker, TomInputDatePickerFormField, TomYearPicker,
/// TomCupertinoDatePicker, TomCupertinoTimerPicker.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Text Inputs demo.
class InputsDemo extends StatelessWidget {
  const InputsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InputsDemoContent();
  }
}

class _InputsDemoContent extends StatefulWidget {
  const _InputsDemoContent();

  @override
  State<_InputsDemoContent> createState() => _InputsDemoContentState();
}

class _InputsDemoContentState extends State<_InputsDemoContent> {
  // State for interactive demos
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  bool _obscurePassword = true;
  DateTime _selectedDate = DateTime.now();
  Duration _selectedDuration = const Duration(hours: 1, minutes: 30);
  int _selectedYear = DateTime.now().year;
  String? _selectedCountry;

  // Sample data for autocomplete - resolved from resources
  List<String> _getCountries() {
    return [
      TomUIResources.resolveText('demo02.countries', 'us'),
      TomUIResources.resolveText('demo02.countries', 'uk'),
      TomUIResources.resolveText('demo02.countries', 'ca'),
      TomUIResources.resolveText('demo02.countries', 'au'),
      TomUIResources.resolveText('demo02.countries', 'de'),
      TomUIResources.resolveText('demo02.countries', 'fr'),
      TomUIResources.resolveText('demo02.countries', 'jp'),
      TomUIResources.resolveText('demo02.countries', 'br'),
      TomUIResources.resolveText('demo02.countries', 'in'),
      TomUIResources.resolveText('demo02.countries', 'cn'),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Formats a duration using resource-based unit labels.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final h = TomUIResources.resolveText('demo02.duration', 'hours');
    final m = TomUIResources.resolveText('demo02.duration', 'minutes');
    final s = TomUIResources.resolveText('demo02.duration', 'seconds');
    return '$hours$h $minutes$m $seconds$s';
  }

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Standard Text Fields
            _SectionHeader(
              tomId: 'demo02.section.standard',
            ),
            const TomSizedBox(height: 16),
            _buildTextFieldSection(),
            const TomSizedBox(height: 24),
            _buildTextFormFieldSection(),
            const TomSizedBox(height: 32),

            // Section 2: Search & Autocomplete
            _SectionHeader(
              tomId: 'demo02.section.search',
            ),
            const TomSizedBox(height: 16),
            _buildSearchBarSection(),
            const TomSizedBox(height: 24),
            _buildAutocompleteSection(),
            const TomSizedBox(height: 32),

            // Section 3: Cupertino Text Inputs
            _SectionHeader(
              tomId: 'demo02.section.cupertino',
            ),
            const TomSizedBox(height: 16),
            _buildCupertinoTextFieldSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoSearchSection(),
            const TomSizedBox(height: 32),

            // Section 4: Date & Time Pickers
            _SectionHeader(
              tomId: 'demo02.section.datetime',
            ),
            const TomSizedBox(height: 16),
            _buildCalendarSection(),
            const TomSizedBox(height: 24),
            _buildCupertinoDateTimeSection(),
            const TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo (RTL/LTR)
            _SectionHeader(
              tomId: 'demo02.section.acl',
            ),
            const TomSizedBox(height: 16),
            _buildAclTextFieldSection(),
            const TomSizedBox(height: 24),
            _buildAclDatePickerSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Standard Text Fields
  // ===========================================================================

  Widget _buildTextFieldSection() {
    return _DemoCard(
      tomId: 'demo02.textfield',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic text field
          TomTextField(
            tomId: 'demo02.textfield.basic',
            controller: _nameController,
          ),
          const TomSizedBox(height: 16),

          // Text field with prefix and suffix
          TomTextField(
            tomId: 'demo02.textfield.price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              suffixText: 'USD',
            ),
          ),
          const TomSizedBox(height: 16),

          // Password field with visibility toggle
          TomTextField(
            tomId: 'demo02.textfield.password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: TomIconButton(
                tomId: 'demo02.textfield.passwordToggle',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          const TomSizedBox(height: 16),

          // Multiline text field
          TomTextField(
            tomId: 'demo02.textfield.multiline',
            maxLines: 4,
            minLines: 2,
          ),
          const TomSizedBox(height: 16),

          // Disabled text field
          TomTextField(
            tomId: 'demo02.textfield.disabled',
            enabled: false,
          ),

          const TomSizedBox(height: 16),

          // Read-only text field
          TomTextField(
            tomId: 'demo02.textfield.readonly',
            readOnly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormFieldSection() {
    return _DemoCard(
      tomId: 'demo02.formfield',
      child: Form(
        key: _formKey,
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email validation
            TomTextFormField(
              tomId: 'demo02.formfield.email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const TomSizedBox(height: 16),

            // Required field
            TomTextFormField(
              tomId: 'demo02.formfield.required',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),
            const TomSizedBox(height: 16),

            // Phone number with formatting
            TomTextFormField(
              tomId: 'demo02.formfield.phone',
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const TomSizedBox(height: 24),

            // Validate button
            TomElevatedButton(
              tomId: 'demo02.formfield.validate',
              onPressed: () {
                _formKey.currentState?.validate();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 2: Search & Autocomplete
  // ===========================================================================

  Widget _buildSearchBarSection() {
    return _DemoCard(
      tomId: 'demo02.searchbar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic search bar
          TomSearchBar(
            tomId: 'demo02.searchbar.basic',
            controller: _searchController,
            onChanged: (value) {
              // Handle search
            },
            leading: const Icon(Icons.search),
            trailing: [
              TomIconButton(
                tomId: 'demo02.searchbar.mic',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Search anchor with suggestions
          TomSearchAnchor(
            tomId: 'demo02.searchbar.anchor',
            suggestionsBuilder: (context, controller) {
              final query = controller.text.toLowerCase();
              final suggestions = _getCountries()
                  .where((c) => c.toLowerCase().contains(query))
                  .toList();
              return suggestions.map((item) => ListTile(
                    title: Text(item),
                    onTap: () {
                      controller.closeView(item);
                    },
                  ));
            },
            builder: (context, controller) {
              return TomSearchBar(
                tomId: 'demo02.searchbar.anchorBar',
                controller: controller,
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                leading: const Icon(Icons.search),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteSection() {
    return _DemoCard(
      tomId: 'demo02.autocomplete',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country autocomplete
          TomAutocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              final countries = _getCountries();
              return countries.where((c) =>
                  c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (selection) {
              setState(() => _selectedCountry = selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TomTextField(
                tomId: 'demo02.autocomplete.country',
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.public),
                ),
              );
            },
          ),
          const TomSizedBox(height: 8),
          if (_selectedCountry != null)
            TomText(
              'Selected: $_selectedCountry',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Cupertino Text Inputs
  // ===========================================================================

  Widget _buildCupertinoTextFieldSection() {
    return _DemoCard(
      tomId: 'demo02.cupertino',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Cupertino text field
          TomCupertinoTextField(
            tomId: 'demo02.cupertino.basic',
            placeholder: 'Enter your name',
          ),
          const TomSizedBox(height: 16),

          // Cupertino text field with prefix and suffix
          TomCupertinoTextField(
            tomId: 'demo02.cupertino.decorated',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.email, size: 20),
            ),
            suffix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle, size: 20, color: Colors.green),
            ),
            placeholder: 'Email address',
          ),
          const TomSizedBox(height: 16),

          // Cupertino form field row
          TomCupertinoTextFormFieldRow(
            tomId: 'demo02.cupertino.formrow',
            prefix: TomText(null, tomId: 'demo02.cupertino.formrowPrefix'),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoSearchSection() {
    // Wrap in NotificationListener to prevent CupertinoSearchTextField from
    // receiving scroll notifications that trigger size access during build.
    // This is a workaround for a Flutter bug where YearPicker.jumpTo dispatches
    // scroll notifications that CupertinoSearchTextField tries to handle.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true, // Block scroll notifications
      child: _DemoCard(
        tomId: 'demo02.cupertinoSearch',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cupertino search text field
            TomCupertinoSearchTextField(
              tomId: 'demo02.cupertinoSearch.basic',
              onChanged: (value) {
                // Handle search
              },
            ),
            const TomSizedBox(height: 16),

            // Cupertino search with custom styling
            TomCupertinoSearchTextField(
              tomId: 'demo02.cupertinoSearch.styled',
              backgroundColor: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 4: Date & Time Pickers
  // ===========================================================================

  Widget _buildCalendarSection() {
    return _DemoCard(
      tomId: 'demo02.calendar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar date picker
          TomContainer(
            constraints: const BoxConstraints(maxHeight: 350),
            child: TomCalendarDatePicker(
              tomId: 'demo02.calendar.picker',
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
          ),
          const TomSizedBox(height: 16),

          // Selected date display
          TomRow(
            children: [
              TomIcon(null, tomId: 'demo02.calendar.selectedIcon'),
              const TomSizedBox(width: 8),
              TomText(
                MaterialLocalizations.of(context).formatShortDate(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Input date picker form field
          TomInputDatePickerFormField(
            tomId: 'demo02.calendar.inputField',
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateSubmitted: (date) {
              setState(() => _selectedDate = date);
            },
          ),
          const TomSizedBox(height: 24),

          // Year picker
          TomContainer(
            constraints: const BoxConstraints(maxHeight: 200),
            child: TomYearPicker(
              tomId: 'demo02.calendar.yearPicker',
              firstDate: DateTime(2010),
              lastDate: DateTime(2030),
              currentDate: DateTime.now(),
              selectedDate: DateTime(_selectedYear),
              onChanged: (date) {
                setState(() => _selectedYear = date.year);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoDateTimeSection() {
    return _DemoCard(
      tomId: 'demo02.cupertinoDateTime',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cupertino date picker
          TomText(null, tomId: 'demo02.cupertinoDateTime.dateLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 200,
            child: TomCupertinoDatePicker(
              tomId: 'demo02.cupertinoDateTime.datePicker',
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selectedDate,
              onDateTimeChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
          ),
          const TomSizedBox(height: 24),

          // Cupertino timer picker
          TomText(null, tomId: 'demo02.cupertinoDateTime.timerLabel'),
          const TomSizedBox(height: 8),
          TomContainer(
            height: 200,
            child: TomCupertinoTimerPicker(
              tomId: 'demo02.cupertinoDateTime.timerPicker',
              mode: CupertinoTimerPickerMode.hms,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (duration) {
                setState(() => _selectedDuration = duration);
              },
            ),
          ),
          const TomSizedBox(height: 16),

          // Display selected duration
          TomRow(
            children: [
              TomIcon(null, tomId: 'demo02.cupertinoDateTime.durationIcon'),
              const TomSizedBox(width: 8),
              TomText(
                _formatDuration(_selectedDuration),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo (RTL/LTR)
  // ===========================================================================

  Widget _buildAclTextFieldSection() {
    return _DemoCard(
      tomId: 'demo02.aclTextField',
      child: AclBuilder()
          // Row 1: Label + TextField side by side
          .append(TomText(null, tomId: 'demo02.aclTextField.nameLabel'))
          .append(
            TomTextField(
              tomId: 'demo02.aclTextField.name',
            ),
            dist: 8,
          )
          .setPSize(200, 56)
          .expandX()
          .newRow(dist: 16)
          // Row 2: Label + TextField side by side
          .append(TomText(null, tomId: 'demo02.aclTextField.emailLabel'))
          .append(
            TomTextField(
              tomId: 'demo02.aclTextField.email',
              keyboardType: TextInputType.emailAddress,
            ),
            dist: 8,
          )
          .setPSize(200, 56)
          .expandX()
          .newRow(dist: 16)
          // Row 3: Two text fields side by side
          .append(
            TomTextField(
              tomId: 'demo02.aclTextField.city',
            ),
          )
          .expandX()
          .append(
            TomTextField(
              tomId: 'demo02.aclTextField.zip',
            ),
            dist: 16,
          )
          .setPSize(120, 56)
          .build(),
    );
  }

  Widget _buildAclDatePickerSection() {
    return _DemoCard(
      tomId: 'demo02.aclDatePicker',
      child: AclBuilder()
          // Row 1: Date label with formatted date display
          .append(TomIcon(null, tomId: 'demo02.aclDatePicker.icon'))
          .append(
            TomText(null, tomId: 'demo02.aclDatePicker.label'),
            dist: 8,
          )
          .append(
            TomText(
              MaterialLocalizations.of(context).formatShortDate(_selectedDate),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 2: Duration label with formatted duration
          .append(TomIcon(null, tomId: 'demo02.aclDatePicker.timerIcon'))
          .append(
            TomText(null, tomId: 'demo02.aclDatePicker.durationLabel'),
            dist: 8,
          )
          .append(
            TomText(
              _formatDuration(_selectedDuration),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            dist: 16,
          )
          .gap()
          .newRow(dist: 24)
          // Row 3: Calendar picker (constrained height)
          .append(
            TomContainer(
              constraints: const BoxConstraints(maxHeight: 300),
              child: TomCalendarDatePicker(
                tomId: 'demo02.aclDatePicker.calendar',
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
            ),
          )
          .expandX()
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
          null,
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const TomSizedBox(height: 4),
        TomText(
          null,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomIcon(null, tomId: '$tomId.icon'),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    null,
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 8),
            // Description
            TomText(
              null,
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const TomSizedBox(height: 16),
            const TomDivider(),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
