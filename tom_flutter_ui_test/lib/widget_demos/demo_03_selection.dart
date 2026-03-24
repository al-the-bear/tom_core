/// Comprehensive Selection Widgets Demo
///
/// This demo showcases all Flutter selection widgets including dropdowns,
/// autocomplete, chips, and search components with their various
/// configurations and styling options.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main selection demo screen with all selection categories.
class SelectionDemo extends StatelessWidget {
  const SelectionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'DropdownButton',
          subtitle: 'Classic dropdown menus for item selection',
        ),
        _DropdownButtonSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'DropdownMenu',
          subtitle: 'Material 3 dropdown menus with search support',
        ),
        _DropdownMenuSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Autocomplete',
          subtitle: 'Text field with suggestions as you type',
        ),
        _AutocompleteSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Chips',
          subtitle: 'Compact elements for selection, filtering, and actions',
        ),
        _ChipsSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'FilterChip & ChoiceChip',
          subtitle: 'Chips for filtering and single selection',
        ),
        _FilterChoiceChipSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Multi-Select',
          subtitle: 'Selecting multiple items from a list',
        ),
        _MultiSelectSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Selection Examples',
          subtitle: 'Real-world selection patterns',
        ),
        _SelectionExamplesSection(),
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
// DropdownButton Section
// =============================================================================

class _DropdownButtonSection extends StatefulWidget {
  const _DropdownButtonSection();

  @override
  State<_DropdownButtonSection> createState() => _DropdownButtonSectionState();
}

class _DropdownButtonSectionState extends State<_DropdownButtonSection> {
  String? _selectedFruit;
  String? _selectedCountry;
  int? _selectedPriority;

  final _fruits = ['Apple', 'Banana', 'Cherry', 'Date', 'Elderberry'];
  final _countries = ['USA', 'Canada', 'UK', 'Germany', 'France', 'Japan'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic DropdownButton',
          description: 'Simple dropdown with string items.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: _selectedFruit,
                hint: const Text('Select a fruit'),
                isExpanded: true,
                items:
                    _fruits.map((fruit) {
                      return DropdownMenuItem(value: fruit, child: Text(fruit));
                    }).toList(),
                onChanged: (value) => setState(() => _selectedFruit = value),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: ${_selectedFruit ?? "None"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
DropdownButton<String>(
  value: _selectedValue,
  hint: Text('Select a fruit'),
  isExpanded: true,
  items: items.map((item) {
    return DropdownMenuItem(
      value: item,
      child: Text(item),
    );
  }).toList(),
  onChanged: (value) => setState(() => _selectedValue = value),
)''',
        ),
        _DemoCard(
          title: 'DropdownButton with Icons',
          description: 'Dropdown items with leading icons.',
          child: DropdownButton<String>(
            value: _selectedCountry,
            hint: const Text('Select a country'),
            isExpanded: true,
            items:
                _countries.map((country) {
                  return DropdownMenuItem(
                    value: country,
                    child: Row(
                      children: [
                        _countryFlag(country),
                        const SizedBox(width: 12),
                        Text(country),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: (value) => setState(() => _selectedCountry = value),
          ),
        ),
        _DemoCard(
          title: 'DropdownButton with Custom Styling',
          description: 'Styled dropdown with elevation and border.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _selectedPriority,
              hint: const Text('Select priority'),
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: const [
                DropdownMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('High'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Medium'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Low'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedPriority = value),
            ),
          ),
        ),
        _DemoCard(
          title: 'DropdownButtonFormField',
          description: 'Dropdown with form validation support.',
          child: Form(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Favorite Fruit',
                prefixIcon: const Icon(Icons.local_florist),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items:
                  _fruits.map((fruit) {
                    return DropdownMenuItem(value: fruit, child: Text(fruit));
                  }).toList(),
              onChanged: (value) {},
              validator: (value) {
                if (value == null) return 'Please select a fruit';
                return null;
              },
            ),
          ),
          code: '''
DropdownButtonFormField<String>(
  decoration: InputDecoration(
    labelText: 'Favorite Fruit',
    prefixIcon: Icon(Icons.local_florist),
    border: OutlineInputBorder(),
  ),
  items: items.map((item) {
    return DropdownMenuItem(
      value: item,
      child: Text(item),
    );
  }).toList(),
  onChanged: (value) {},
  validator: (value) {
    if (value == null) return 'Please select a fruit';
    return null;
  },
)''',
        ),
      ],
    );
  }

  Widget _countryFlag(String country) {
    final flagMap = {
      'USA': '🇺🇸',
      'Canada': '🇨🇦',
      'UK': '🇬🇧',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Japan': '🇯🇵',
    };
    return Text(flagMap[country] ?? '🏳️', style: const TextStyle(fontSize: 20));
  }
}

// =============================================================================
// DropdownMenu Section
// =============================================================================

class _DropdownMenuSection extends StatefulWidget {
  const _DropdownMenuSection();

  @override
  State<_DropdownMenuSection> createState() => _DropdownMenuSectionState();
}

class _DropdownMenuSectionState extends State<_DropdownMenuSection> {
  String? _selectedColor;
  String? _selectedIcon;

  final _colors = [
    ('Red', Colors.red),
    ('Orange', Colors.orange),
    ('Yellow', Colors.yellow),
    ('Green', Colors.green),
    ('Blue', Colors.blue),
    ('Purple', Colors.purple),
    ('Pink', Colors.pink),
  ];

  final _icons = [
    ('Home', Icons.home),
    ('Work', Icons.work),
    ('School', Icons.school),
    ('Gym', Icons.fitness_center),
    ('Shopping', Icons.shopping_cart),
    ('Restaurant', Icons.restaurant),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic DropdownMenu',
          description: 'Material 3 dropdown with built-in search.',
          child: DropdownMenu<String>(
            width: double.infinity,
            hintText: 'Select a color',
            enableSearch: false,
            requestFocusOnTap: false,
            onSelected: (value) => setState(() => _selectedColor = value),
            dropdownMenuEntries:
                _colors.map((c) {
                  return DropdownMenuEntry(
                    value: c.$1,
                    label: c.$1,
                    leadingIcon: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c.$2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }).toList(),
          ),
          code: '''
DropdownMenu<String>(
  hintText: 'Select a color',
  onSelected: (value) => setState(() => _selectedValue = value),
  dropdownMenuEntries: colors.map((color) {
    return DropdownMenuEntry(
      value: color.name,
      label: color.name,
      leadingIcon: Container(
        width: 20,
        height: 20,
        color: color,
      ),
    );
  }).toList(),
)''',
        ),
        _DemoCard(
          title: 'DropdownMenu with Search',
          description: 'Searchable dropdown for long lists.',
          child: DropdownMenu<String>(
            width: double.infinity,
            hintText: 'Search and select',
            enableFilter: true,
            requestFocusOnTap: true,
            onSelected: (value) => setState(() => _selectedIcon = value),
            dropdownMenuEntries:
                _icons.map((i) {
                  return DropdownMenuEntry(
                    value: i.$1,
                    label: i.$1,
                    leadingIcon: Icon(i.$2),
                  );
                }).toList(),
          ),
        ),
        _DemoCard(
          title: 'DropdownMenu Styling',
          description: 'Customized appearance with input decoration.',
          child: DropdownMenu<String>(
            width: double.infinity,
            hintText: 'Select category',
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surface,
              ),
              elevation: const WidgetStatePropertyAll(8),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'tech', label: 'Technology'),
              DropdownMenuEntry(value: 'health', label: 'Health'),
              DropdownMenuEntry(value: 'sports', label: 'Sports'),
              DropdownMenuEntry(value: 'travel', label: 'Travel'),
            ],
            onSelected: (_) {},
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Autocomplete Section
// =============================================================================

class _AutocompleteSection extends StatelessWidget {
  const _AutocompleteSection();

  static const _programmingLanguages = [
    'Dart',
    'JavaScript',
    'TypeScript',
    'Python',
    'Java',
    'Kotlin',
    'Swift',
    'C++',
    'C#',
    'Go',
    'Rust',
    'Ruby',
    'PHP',
    'Scala',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic Autocomplete',
          description: 'Text field with suggestions as you type.',
          child: Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _programmingLanguages.where(
                (lang) => lang.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            onSelected: (selection) {
              debugPrint('Selected: $selection');
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onFieldSubmitted(),
                decoration: InputDecoration(
                  labelText: 'Programming Language',
                  hintText: 'Start typing...',
                  prefixIcon: const Icon(Icons.code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
          code: '''
Autocomplete<String>(
  optionsBuilder: (textEditingValue) {
    if (textEditingValue.text.isEmpty) {
      return const Iterable<String>.empty();
    }
    return options.where((option) => option
        .toLowerCase()
        .contains(textEditingValue.text.toLowerCase()));
  },
  onSelected: (selection) {
    print('Selected: \$selection');
  },
)''',
        ),
        _DemoCard(
          title: 'Custom Autocomplete Options',
          description: 'Styled suggestion items with icons.',
          child: Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _programmingLanguages.take(5);
              }
              return _programmingLanguages.where(
                (lang) => lang.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 300,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          leading: _languageIcon(option),
                          title: Text(option),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Select Language',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            onSelected: (_) {},
          ),
        ),
        const _AsyncAutocompleteDemo(),
      ],
    );
  }

  Widget _languageIcon(String language) {
    final iconMap = {
      'Dart': Icons.flutter_dash,
      'JavaScript': Icons.javascript,
      'Python': Icons.pest_control,
      'Java': Icons.coffee,
      'Swift': Icons.speed,
    };
    return Icon(iconMap[language] ?? Icons.code, size: 24, color: Colors.blue);
  }
}

class _AsyncAutocompleteDemo extends StatefulWidget {
  const _AsyncAutocompleteDemo();

  @override
  State<_AsyncAutocompleteDemo> createState() => _AsyncAutocompleteDemoState();
}

class _AsyncAutocompleteDemoState extends State<_AsyncAutocompleteDemo> {
  final _cities = [
    'New York',
    'Los Angeles',
    'Chicago',
    'Houston',
    'Phoenix',
    'Philadelphia',
    'San Antonio',
    'San Diego',
    'Dallas',
    'San Francisco',
    'Austin',
    'Seattle',
    'Denver',
    'Boston',
    'Miami',
  ];

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Async Autocomplete',
      description: 'Simulated API call with loading state.',
      child: RawAutocomplete<String>(
        optionsBuilder: (textEditingValue) async {
          if (textEditingValue.text.isEmpty) {
            return const [];
          }
          // Simulate API delay
          await Future.delayed(const Duration(milliseconds: 500));
          return _cities.where(
            (city) =>
                city.toLowerCase().contains(textEditingValue.text.toLowerCase()),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 300,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.location_city),
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Search cities...',
              prefixIcon: const Icon(Icons.location_city),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Chips Section
// =============================================================================

class _ChipsSection extends StatefulWidget {
  const _ChipsSection();

  @override
  State<_ChipsSection> createState() => _ChipsSectionState();
}

class _ChipsSectionState extends State<_ChipsSection> {
  final _inputChips = <String>['Flutter', 'Dart', 'Mobile'];
  final _chipController = TextEditingController();

  @override
  void dispose() {
    _chipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Basic Chips',
          description: 'Different chip variants and their uses.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Chip(label: Text('Basic Chip')),
              const Chip(
                avatar: CircleAvatar(child: Text('A')),
                label: Text('With Avatar'),
              ),
              Chip(
                avatar: const Icon(Icons.check, size: 16),
                label: const Text('With Icon'),
                backgroundColor: Colors.green.shade100,
              ),
              Chip(
                label: const Text('Deletable'),
                onDeleted: () {},
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          code: '''
// Basic chip
Chip(label: Text('Basic'))

// With avatar
Chip(
  avatar: CircleAvatar(child: Text('A')),
  label: Text('With Avatar'),
)

// Deletable
Chip(
  label: Text('Deletable'),
  onDeleted: () {},
)''',
        ),
        _DemoCard(
          title: 'ActionChip',
          description: 'Chips that trigger an action when tapped.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Add to Cart'),
                avatar: const Icon(Icons.add_shopping_cart, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Added!')));
                },
              ),
              ActionChip(
                label: const Text('Share'),
                avatar: const Icon(Icons.share, size: 18),
                onPressed: () {},
              ),
              ActionChip(
                label: const Text('Bookmark'),
                avatar: const Icon(Icons.bookmark_add, size: 18),
                onPressed: () {},
              ),
            ],
          ),
          code: '''
ActionChip(
  label: Text('Add to Cart'),
  avatar: Icon(Icons.add_shopping_cart),
  onPressed: () {
    // Handle action
  },
)''',
        ),
        _DemoCard(
          title: 'InputChip (Tags)',
          description: 'Add and remove tags dynamically.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._inputChips.map(
                    (chip) => InputChip(
                      label: Text(chip),
                      onDeleted: () {
                        setState(() => _inputChips.remove(chip));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chipController,
                      decoration: InputDecoration(
                        hintText: 'Add a tag',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() => _inputChips.add(value));
                          _chipController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      if (_chipController.text.isNotEmpty) {
                        setState(() => _inputChips.add(_chipController.text));
                        _chipController.clear();
                      }
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// FilterChip & ChoiceChip Section
// =============================================================================

class _FilterChoiceChipSection extends StatefulWidget {
  const _FilterChoiceChipSection();

  @override
  State<_FilterChoiceChipSection> createState() =>
      _FilterChoiceChipSectionState();
}

class _FilterChoiceChipSectionState extends State<_FilterChoiceChipSection> {
  final _selectedFilters = <String>{};
  int _selectedChoice = 0;
  final _sizes = ['XS', 'S', 'M', 'L', 'XL'];
  final _categories = ['All', 'Electronics', 'Clothing', 'Books', 'Food'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'FilterChip',
          description: 'Multi-select chips for filtering content.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Categories:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _categories.skip(1).map((category) {
                      final selected = _selectedFilters.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedFilters.add(category);
                            } else {
                              _selectedFilters.remove(category);
                            }
                          });
                        },
                        checkmarkColor:
                            selected ? Colors.white : null,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected: ${_selectedFilters.isEmpty ? "None" : _selectedFilters.join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
FilterChip(
  label: Text(category),
  selected: isSelected,
  onSelected: (value) {
    setState(() {
      if (value) {
        _selectedFilters.add(category);
      } else {
        _selectedFilters.remove(category);
      }
    });
  },
)''',
        ),
        _DemoCard(
          title: 'ChoiceChip',
          description: 'Single-select chips (radio button behavior).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Size:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_sizes.length, (index) {
                  return ChoiceChip(
                    label: Text(_sizes[index]),
                    selected: _selectedChoice == index,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedChoice = index);
                      }
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected: ${_sizes[_selectedChoice]}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          code: '''
ChoiceChip(
  label: Text(size),
  selected: _selectedIndex == index,
  onSelected: (selected) {
    if (selected) {
      setState(() => _selectedIndex = index);
    }
  },
)''',
        ),
        _DemoCard(
          title: 'Chip Styling',
          description: 'Custom colors, shapes, and elevations.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: const Text('Rounded'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.blue.shade100,
              ),
              Chip(
                label: const Text('Outlined'),
                shape: const StadiumBorder(side: BorderSide(color: Colors.blue)),
                backgroundColor: Colors.transparent,
              ),
              Chip(
                label: const Text('Elevated'),
                elevation: 4,
                shadowColor: Colors.black26,
                backgroundColor: Colors.white,
              ),
              Chip(
                avatar: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                    ),
                  ),
                  child: const Icon(Icons.star, size: 16, color: Colors.white),
                ),
                label: const Text('Gradient'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Multi-Select Section
// =============================================================================

class _MultiSelectSection extends StatefulWidget {
  const _MultiSelectSection();

  @override
  State<_MultiSelectSection> createState() => _MultiSelectSectionState();
}

class _MultiSelectSectionState extends State<_MultiSelectSection> {
  final _selectedLanguages = <String>{};
  final _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Korean',
    'Arabic',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'Multi-Select List',
          description: 'Select multiple items from a list.',
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final selected = _selectedLanguages.contains(language);
                    return CheckboxListTile(
                      title: Text(language),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedLanguages.add(language);
                          } else {
                            _selectedLanguages.remove(language);
                          }
                        });
                      },
                      dense: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedLanguages.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _selectedLanguages.map((lang) {
                        return Chip(
                          label: Text(lang),
                          onDeleted: () {
                            setState(() => _selectedLanguages.remove(lang));
                          },
                          deleteIconColor: Colors.red,
                        );
                      }).toList(),
                ),
            ],
          ),
          code: '''
CheckboxListTile(
  title: Text(item),
  value: _selectedItems.contains(item),
  onChanged: (value) {
    setState(() {
      if (value == true) {
        _selectedItems.add(item);
      } else {
        _selectedItems.remove(item);
      }
    });
  },
)''',
        ),
        const _MultiSelectDialogDemo(),
      ],
    );
  }
}

class _MultiSelectDialogDemo extends StatefulWidget {
  const _MultiSelectDialogDemo();

  @override
  State<_MultiSelectDialogDemo> createState() => _MultiSelectDialogDemoState();
}

class _MultiSelectDialogDemoState extends State<_MultiSelectDialogDemo> {
  final _selectedHobbies = <String>[];
  final _hobbies = [
    'Reading',
    'Gaming',
    'Cooking',
    'Sports',
    'Music',
    'Art',
    'Photography',
    'Travel',
    'Gardening',
    'Writing',
  ];

  Future<void> _showMultiSelectDialog() async {
    final tempSelection = Set<String>.from(_selectedHobbies);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Hobbies'),
              content: SizedBox(
                width: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _hobbies.length,
                  itemBuilder: (context, index) {
                    final hobby = _hobbies[index];
                    return CheckboxListTile(
                      title: Text(hobby),
                      value: tempSelection.contains(hobby),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelection.add(hobby);
                          } else {
                            tempSelection.remove(hobby);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, tempSelection),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedHobbies.clear();
        _selectedHobbies.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Multi-Select Dialog',
      description: 'Select multiple items in a dialog.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _showMultiSelectDialog,
            icon: const Icon(Icons.add),
            label: Text(
              _selectedHobbies.isEmpty
                  ? 'Select Hobbies'
                  : '${_selectedHobbies.length} selected',
            ),
          ),
          if (_selectedHobbies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _selectedHobbies.map((hobby) {
                    return Chip(
                      label: Text(hobby),
                      onDeleted: () {
                        setState(() => _selectedHobbies.remove(hobby));
                      },
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Selection Examples Section
// =============================================================================

class _SelectionExamplesSection extends StatefulWidget {
  const _SelectionExamplesSection();

  @override
  State<_SelectionExamplesSection> createState() =>
      _SelectionExamplesSectionState();
}

class _SelectionExamplesSectionState extends State<_SelectionExamplesSection> {
  String _sortBy = 'Relevance';
  String _priceRange = 'Any';
  final _selectedColors = <String>{};

  final _colors = [
    ('Red', Colors.red),
    ('Blue', Colors.blue),
    ('Green', Colors.green),
    ('Yellow', Colors.yellow.shade700),
    ('Purple', Colors.purple),
    ('Orange', Colors.orange),
    ('Pink', Colors.pink),
    ('Brown', Colors.brown),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DemoCard(
          title: 'E-commerce Filter Panel',
          description: 'Complete filter UI with multiple selection types.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sort By
              const Text(
                'Sort By',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownMenu<String>(
                width: double.infinity,
                initialSelection: _sortBy,
                onSelected: (value) {
                  if (value != null) setState(() => _sortBy = value);
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'Relevance', label: 'Relevance'),
                  DropdownMenuEntry(
                    value: 'Price: Low to High',
                    label: 'Price: Low to High',
                  ),
                  DropdownMenuEntry(
                    value: 'Price: High to Low',
                    label: 'Price: High to Low',
                  ),
                  DropdownMenuEntry(value: 'Newest', label: 'Newest'),
                  DropdownMenuEntry(value: 'Rating', label: 'Rating'),
                ],
              ),
              const SizedBox(height: 16),

              // Price Range
              const Text(
                'Price Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ['Any', '\$0-\$25', '\$25-\$50', '\$50-\$100', '\$100+']
                        .map((price) {
                          return ChoiceChip(
                            label: Text(price),
                            selected: _priceRange == price,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _priceRange = price);
                              }
                            },
                          );
                        })
                        .toList(),
              ),
              const SizedBox(height: 16),

              // Color Filter
              const Text('Colors', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _colors.map((c) {
                      final selected = _selectedColors.contains(c.$1);
                      return FilterChip(
                        label: Text(c.$1),
                        avatar: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: c.$2,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 0.5,
                            ),
                          ),
                        ),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedColors.add(c.$1);
                            } else {
                              _selectedColors.remove(c.$1);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              // Clear all / Apply
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _sortBy = 'Relevance';
                        _priceRange = 'Any';
                        _selectedColors.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filters applied!')),
                      );
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _TagInputDemo(),
      ],
    );
  }
}

class _TagInputDemo extends StatefulWidget {
  const _TagInputDemo();

  @override
  State<_TagInputDemo> createState() => _TagInputDemoState();
}

class _TagInputDemoState extends State<_TagInputDemo> {
  final _tags = <String>['flutter', 'dart', 'mobile'];
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  final _suggestions = [
    'flutter',
    'dart',
    'mobile',
    'web',
    'desktop',
    'android',
    'ios',
    'widgets',
    'state-management',
    'animation',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final normalizedTag = tag.toLowerCase().trim();
    if (normalizedTag.isNotEmpty && !_tags.contains(normalizedTag)) {
      setState(() => _tags.add(normalizedTag));
    }
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Tag Input Field',
      description: 'Autocomplete with chip display.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map(
                (tag) => Chip(
                  label: Text('#$tag'),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RawAutocomplete<String>(
            textEditingController: _controller,
            focusNode: _focusNode,
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const [];
              return _suggestions
                  .where(
                    (s) =>
                        s.contains(textEditingValue.text.toLowerCase()) &&
                        !_tags.contains(s),
                  )
                  .toList();
            },
            onSelected: _addTag,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Add tags...',
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed:
                        controller.text.isNotEmpty
                            ? () => _addTag(controller.text)
                            : null,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (value) {
                  _addTag(value);
                  onSubmitted();
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children:
                          options.map((option) {
                            return ListTile(
                              leading: const Icon(Icons.tag, size: 20),
                              title: Text('#$option'),
                              dense: true,
                              onTap: () => onSelected(option),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
