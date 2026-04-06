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
class InputsDemo extends TomStatelessWidget {
  InputsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _InputsDemoContent();

  }
}

class _InputsDemoContent extends TomStatefulWidget {
  _InputsDemoContent();

  @override
  State<_InputsDemoContent> createState() => _InputsDemoContentState();
}

class _InputsDemoContentState extends TomState<_InputsDemoContent> {
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
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Standard Text Fields
            _SectionHeader(
              tomId: 'section.standard',
            ),
            TomSizedBox(height: 16),
            _buildTextFieldSection(),
            TomSizedBox(height: 24),
            _buildTextFormFieldSection(),
            TomSizedBox(height: 32),

            // Section 2: Search & Autocomplete
            _SectionHeader(
              tomId: 'section.search',
            ),
            TomSizedBox(height: 16),
            _buildSearchBarSection(),
            TomSizedBox(height: 24),
            _buildAutocompleteSection(),
            TomSizedBox(height: 32),

            // Section 3: Cupertino Text Inputs
            _SectionHeader(
              tomId: 'section.cupertino',
            ),
            TomSizedBox(height: 16),
            _buildCupertinoTextFieldSection(),
            TomSizedBox(height: 24),
            _buildCupertinoSearchSection(),
            TomSizedBox(height: 32),

            // Section 4: Date & Time Pickers
            _SectionHeader(
              tomId: 'section.datetime',
            ),
            TomSizedBox(height: 16),
            _buildCalendarSection(),
            TomSizedBox(height: 24),
            _buildCupertinoDateTimeSection(),
            TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo (RTL/LTR)
            _SectionHeader(
              tomId: 'section.acl',
            ),
            TomSizedBox(height: 16),
            _buildAclTextFieldSection(),
            TomSizedBox(height: 24),
            _buildAclDatePickerSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Standard Text Fields
  // ===========================================================================

  Widget _buildTextFieldSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'textfield',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic text field
          TomTextField(
            tomId: 'textfield.basic',
            controller: _nameController,
          ),
          TomSizedBox(height: 16),

          // Text field with prefix and suffix
          TomTextField(
            tomId: 'textfield.price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              suffixText: 'USD',
            ),
          ),
          TomSizedBox(height: 16),

          // Password field with visibility toggle
          TomTextField(
            tomId: 'textfield.password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: TomIconButton(
                tomId: 'textfield.passwordToggle',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          TomSizedBox(height: 16),

          // Multiline text field
          TomTextField(
            tomId: 'textfield.multiline',
            maxLines: 4,
            minLines: 2,
          ),
          TomSizedBox(height: 16),

          // Disabled text field
          TomTextField(
            tomId: 'textfield.disabled',
            enabled: false,
          ),

          TomSizedBox(height: 16),

          // Read-only text field
          TomTextField(
            tomId: 'textfield.readonly',
            readOnly: true,
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTextFormFieldSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'formfield',
        child: Form(
        key: _formKey,
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email validation
            TomTextFormField(
              tomId: 'formfield.email',
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
            TomSizedBox(height: 16),

            // Required field
            TomTextFormField(
              tomId: 'formfield.required',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),
            TomSizedBox(height: 16),

            // Phone number with formatting
            TomTextFormField(
              tomId: 'formfield.phone',
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            TomSizedBox(height: 24),

            // Validate button
            TomElevatedButton(
              tomId: 'formfield.validate',
              onPressed: () {
                _formKey.currentState?.validate();
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 2: Search & Autocomplete
  // ===========================================================================

  Widget _buildSearchBarSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'searchbar',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic search bar
          TomSearchBar(
            tomId: 'searchbar.basic',
            controller: _searchController,
            onChanged: (value) {
              // Handle search
            },
            leading: const Icon(Icons.search),
            trailing: [
              TomIconButton(
                tomId: 'searchbar.mic',
                onPressed: () {},
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Search anchor with suggestions
          TomSearchAnchor(
            tomId: 'searchbar.anchor',
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
                tomId: 'searchbar.anchorBar',
                controller: controller,
                onTap: () => controller.openView(),
                onChanged: (_) => controller.openView(),
                leading: const Icon(Icons.search),
              );
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildAutocompleteSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'autocomplete',
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
                tomId: 'autocomplete.country',
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.public),
                ),
              );
            },
          ),
          TomSizedBox(height: 8),
          if (_selectedCountry != null)
            TomText(
              text: 'Selected: $_selectedCountry',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 3: Cupertino Text Inputs
  // ===========================================================================

  Widget _buildCupertinoTextFieldSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertino',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Cupertino text field
          TomCupertinoTextField(
            tomId: 'cupertino.basic',
            placeholder: 'Enter your name',
          ),
          TomSizedBox(height: 16),

          // Cupertino text field with prefix and suffix
          TomCupertinoTextField(
            tomId: 'cupertino.decorated',
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
          TomSizedBox(height: 16),

          // Cupertino form field row
          TomCupertinoTextFormFieldRow(
            tomId: 'cupertino.formrow',
            prefix: TomText(tomId: 'cupertino.formrowPrefix'),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildCupertinoSearchSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    // Wrap in NotificationListener to prevent CupertinoSearchTextField from
    // receiving scroll notifications that trigger size access during build.
    // This is a workaround for a Flutter bug where YearPicker.jumpTo dispatches
    // scroll notifications that CupertinoSearchTextField tries to handle.
    return Directionality(
      textDirection: textDirection,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true, // Block scroll notifications
        child: _DemoCard(
          tomId: 'cupertinoSearch',
          child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cupertino search text field
            TomCupertinoSearchTextField(
              tomId: 'cupertinoSearch.basic',
              onChanged: (value) {
                // Handle search
              },
            ),
            TomSizedBox(height: 16),

            // Cupertino search with custom styling
            TomCupertinoSearchTextField(
              tomId: 'cupertinoSearch.styled',
              backgroundColor: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 4: Date & Time Pickers
  // ===========================================================================

  Widget _buildCalendarSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'calendar',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar date picker
          TomContainer(
            constraints: const BoxConstraints(maxHeight: 350),
            child: TomCalendarDatePicker(
              tomId: 'calendar.picker',
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
          ),
          TomSizedBox(height: 16),

          // Selected date display
          TomRow(
            children: [
              TomIcon(tomId: 'calendar.selectedIcon'),
              TomSizedBox(width: 8),
              TomText(
                text: MaterialLocalizations.of(context).formatShortDate(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Input date picker form field
          TomInputDatePickerFormField(
            tomId: 'calendar.inputField',
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateSubmitted: (date) {
              setState(() => _selectedDate = date);
            },
          ),
          TomSizedBox(height: 24),

          // Year picker
          TomContainer(
            constraints: const BoxConstraints(maxHeight: 200),
            child: TomYearPicker(
              tomId: 'calendar.yearPicker',
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
      ),
    );
  }

  Widget _buildCupertinoDateTimeSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertinoDateTime',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cupertino date picker
          TomText(tomId: 'cupertinoDateTime.dateLabel'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 200,
            child: TomCupertinoDatePicker(
              tomId: 'cupertinoDateTime.datePicker',
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selectedDate,
              onDateTimeChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
          ),
          TomSizedBox(height: 24),

          // Cupertino timer picker
          TomText(tomId: 'cupertinoDateTime.timerLabel'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 200,
            child: TomCupertinoTimerPicker(
              tomId: 'cupertinoDateTime.timerPicker',
              mode: CupertinoTimerPickerMode.hms,
              initialTimerDuration: _selectedDuration,
              onTimerDurationChanged: (duration) {
                setState(() => _selectedDuration = duration);
              },
            ),
          ),
          TomSizedBox(height: 16),

          // Display selected duration
          TomRow(
            children: [
              TomIcon(tomId: 'cupertinoDateTime.durationIcon'),
              TomSizedBox(width: 8),
              TomText(
                text: _formatDuration(_selectedDuration),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo (RTL/LTR)
  // ===========================================================================

  Widget _buildAclTextFieldSection() {
    return _DemoCard(
      tomId: 'aclTextField',
      child: AclBuilder()
          // Row 1: Label + TextField side by side
          .append(TomText(tomId: 'aclTextField.nameLabel'))
          .append(
            TomTextField(
              tomId: 'aclTextField.name',
            ),
            dist: 8,
          )
          .setPSize(200, 56)
          .expandX()
          .newRow(dist: 16)
          // Row 2: Label + TextField side by side
          .append(TomText(tomId: 'aclTextField.emailLabel'))
          .append(
            TomTextField(
              tomId: 'aclTextField.email',
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
              tomId: 'aclTextField.city',
            ),
          )
          .expandX()
          .append(
            TomTextField(
              tomId: 'aclTextField.zip',
            ),
            dist: 16,
          )
          .setPSize(120, 56)
          .build(),
    );
  }

  Widget _buildAclDatePickerSection() {
    return _DemoCard(
      tomId: 'aclDatePicker',
      child: AclBuilder()
          // Row 1: Date label with formatted date display
          .append(TomIcon(tomId: 'aclDatePicker.icon'))
          .append(
            TomText(tomId: 'aclDatePicker.label'),
            dist: 8,
          )
          .append(
            TomText(
              text: MaterialLocalizations.of(context).formatShortDate(_selectedDate),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 2: Duration label with formatted duration
          .append(TomIcon(tomId: 'aclDatePicker.timerIcon'))
          .append(
            TomText(tomId: 'aclDatePicker.durationLabel'),
            dist: 8,
          )
          .append(
            TomText(
              text: _formatDuration(_selectedDuration),
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
                tomId: 'aclDatePicker.calendar',
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
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({
    required this.tomId,
  });

  @override
  Widget buildContent(BuildContext context) {
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
        TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TomSizedBox(height: 8),
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
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
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
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
