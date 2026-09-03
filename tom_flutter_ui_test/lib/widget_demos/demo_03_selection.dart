/// Demo 03: Selection Controls
///
/// Comprehensive demonstration of all Tom selection widgets.
/// Widgets covered: TomDropdownButton, TomDropdownButtonFormField,
/// TomDropdownMenu, TomDropdownMenuFormField, TomPopupMenuButton,
/// TomPopupMenuItem, TomCheckedPopupMenuItem, TomPopupMenuDivider,
/// TomMenuAnchor, TomCheckboxMenuButton, TomRadioMenuButton,
/// TomCupertinoSlidingSegmentedControl, TomCupertinoSegmentedControl,
/// TomCupertinoPicker.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Selection Controls demo.
class SelectionDemo extends TomStatelessWidget {
  SelectionDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _SelectionDemoContent();
  }
}

class _SelectionDemoContent extends TomStatefulWidget {
  _SelectionDemoContent();

  @override
  State<_SelectionDemoContent> createState() => _SelectionDemoContentState();
}

class _SelectionDemoContentState extends TomState<_SelectionDemoContent> {
  // State for interactive demos
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  String? _selectedColor;
  String? _selectedSize;
  String? _selectedCountry;
  int _slidingValue = 1;
  int _segmentedValue = 0;
  int _pickerValue = 0;
  bool _showPreview = true;
  bool _showDetails = false;
  bool _showSidebar = true;
  String _radioMenuValue = 'option1';

  // Data keys for resource lookups
  static const _categoryKeys = [
    'electronics',
    'clothing',
    'homeGarden',
    'books',
    'sports',
  ];
  static const _colorKeys = ['red', 'green', 'blue', 'yellow', 'black'];
  static const _sizeKeys = ['xs', 's', 'm', 'l', 'xl', 'xxl'];
  static const _fruitKeys = [
    'apple',
    'banana',
    'orange',
    'mango',
    'grape',
    'strawberry',
    'pineapple',
    'watermelon',
  ];
  static const _countryKeys = ['us', 'uk', 'de', 'fr', 'jp'];

  /// Resolves a text resource by tomId and suffix.
  String _resolveText(String tomId, String suffix) {
    return TomCtr.text(tomId, suffix);
  }

  /// Resolves a color from resources by tomId.
  Color? _resolveColor(String tomId) {
    final colorName = TomCtr.text(tomId, 'color');
    return TomUIColors.resolveColor(colorName);
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Dropdown Menus
            _SectionHeader(tomId: 'section.dropdown'),
            TomSizedBox(height: 16),
            _buildDropdownButtonSection(),
            TomSizedBox(height: 24),
            _buildDropdownMenuSection(),
            TomSizedBox(height: 32),

            // Section 2: Popup Menus
            _SectionHeader(tomId: 'section.popup'),
            TomSizedBox(height: 16),
            _buildPopupMenuButtonSection(),
            TomSizedBox(height: 24),
            _buildCheckedPopupMenuSection(),
            TomSizedBox(height: 32),

            // Section 3: Menu Anchors
            _SectionHeader(tomId: 'section.anchor'),
            TomSizedBox(height: 16),
            _buildMenuAnchorSection(),
            TomSizedBox(height: 32),

            // Section 4: Cupertino Segmented Controls
            _SectionHeader(tomId: 'section.cupertino'),
            TomSizedBox(height: 16),
            _buildCupertinoSegmentedSection(),
            TomSizedBox(height: 24),
            _buildCupertinoPickerSection(),
            TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo (RTL/LTR)
            _SectionHeader(tomId: 'section.acl'),
            TomSizedBox(height: 16),
            _buildAclDropdownSection(),
            TomSizedBox(height: 24),
            _buildAclSegmentedSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Dropdown Menus
  // ===========================================================================

  Widget _buildDropdownButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'dropdownButton',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic dropdown
            TomRow(
              children: [
                TomText(tomId: 'dropdownButton.categoryLabel'),
                TomSizedBox(width: 16),
                TomExpanded(
                  child: TomDropdownButton<String>(
                    tomId: 'dropdownButton.category',
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categoryKeys
                        .map(
                          (key) => TomDropdownMenuItem<String>(
                            tomId: 'data.category.$key',
                            value: key,
                            child: TomText(tomId: 'data.category.$key'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 24),

            // Dropdown with custom items (icons)
            TomText(tomId: 'dropdownButton.colorLabel'),
            TomSizedBox(height: 8),
            TomDropdownButton<String>(
              tomId: 'dropdownButton.color',
              value: _selectedColor,
              isExpanded: true,
              items: _colorKeys
                  .map(
                    (key) => TomDropdownMenuItem<String>(
                      tomId: 'data.color.$key',
                      value: key,
                      child: Row(
                        children: [
                          Text(_resolveText('demo03.data.color.$key', 'emoji')),
                          const SizedBox(width: 8),
                          TomText(tomId: 'data.color.$key'),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedColor = value);
              },
            ),
            TomSizedBox(height: 24),

            // Form dropdown with validation
            Form(
              key: _formKey,
              child: TomColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TomDropdownButtonFormField<String>(
                    tomId: 'dropdownButton.countryForm',
                    value: _selectedCountry,
                    isExpanded: true,
                    items: _countryKeys
                        .map(
                          (key) => TomDropdownMenuItem<String>(
                            tomId: 'data.country.$key',
                            value: key,
                            child: TomText(tomId: 'data.country.$key'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCountry = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a country';
                      }
                      return null;
                    },
                  ),
                  TomSizedBox(height: 16),
                  TomElevatedButton(
                    tomId: 'dropdownButton.validate',
                    onPressed: () {
                      _formKey.currentState?.validate();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownMenuSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'dropdownMenu',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // M3 Dropdown Menu
            TomDropdownMenu<String>(
              tomId: 'dropdownMenu.size',
              initialSelection: _selectedSize,
              dropdownMenuEntries: _sizeKeys
                  .map(
                    (key) => DropdownMenuEntry<String>(
                      value: key,
                      label: _resolveText('demo03.data.size.$key', 'label'),
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                setState(() => _selectedSize = value);
              },
            ),
            TomSizedBox(height: 24),

            // Dropdown Menu with icons
            TomDropdownMenu<String>(
              tomId: 'dropdownMenu.colorWithIcon',
              initialSelection: _selectedColor,
              leadingIcon: const Icon(Icons.palette),
              dropdownMenuEntries: _colorKeys
                  .map(
                    (key) => DropdownMenuEntry<String>(
                      value: key,
                      label: _resolveText('demo03.data.color.$key', 'label'),
                      leadingIcon: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _resolveColor('demo03.data.color.$key'),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                setState(() => _selectedColor = value);
              },
            ),
            TomSizedBox(height: 24),

            // Expanded dropdown menu
            TomDropdownMenu<String>(
              tomId: 'dropdownMenu.expanded',
              initialSelection: _selectedCategory,
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: _categoryKeys
                  .map(
                    (key) => DropdownMenuEntry<String>(
                      value: key,
                      label: _resolveText('demo03.data.category.$key', 'label'),
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 2: Popup Menus
  // ===========================================================================

  Widget _buildPopupMenuButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'popupMenu',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic popup menu
            TomRow(
              children: [
                TomText(tomId: 'popupMenu.basicLabel'),
                TomSizedBox(width: 16),
                TomPopupMenuButton<String>(
                  tomId: 'popupMenu.basic',
                  itemBuilder: (context) => [
                    TomPopupMenuItem<String>(
                      value: 'copy',
                      tomId: 'popupMenu.copy',
                      child: TomRow(
                        children: [
                          TomIcon(tomId: 'popupMenu.copy'),
                          TomSizedBox(width: 12),
                          TomText(tomId: 'popupMenu.copy'),
                        ],
                      ),
                    ),
                    TomPopupMenuItem<String>(
                      value: 'cut',
                      tomId: 'popupMenu.cut',
                      child: TomRow(
                        children: [
                          TomIcon(tomId: 'popupMenu.cut'),
                          TomSizedBox(width: 12),
                          TomText(tomId: 'popupMenu.cut'),
                        ],
                      ),
                    ),
                    TomPopupMenuItem<String>(
                      value: 'paste',
                      tomId: 'popupMenu.paste',
                      child: TomRow(
                        children: [
                          TomIcon(tomId: 'popupMenu.paste'),
                          TomSizedBox(width: 12),
                          TomText(tomId: 'popupMenu.paste'),
                        ],
                      ),
                    ),
                    TomPopupMenuDivider(),
                    TomPopupMenuItem<String>(
                      value: 'delete',
                      tomId: 'popupMenu.delete',
                      child: TomRow(
                        children: [
                          TomIcon(tomId: 'popupMenu.delete'),
                          TomSizedBox(width: 12),
                          TomText(tomId: 'popupMenu.delete'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Selected: $value')));
                  },
                ),
              ],
            ),
            TomSizedBox(height: 24),

            // Popup menu with custom trigger
            TomPopupMenuButton<String>(
              tomId: 'popupMenu.customTrigger',
              child: TomContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomRow(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TomText(tomId: 'popupMenu.moreOptions'),
                    TomSizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                TomPopupMenuItem<String>(
                  value: 'view',
                  tomId: 'popupMenu.view',
                  child: TomText(tomId: 'popupMenu.view'),
                ),
                TomPopupMenuItem<String>(
                  value: 'edit',
                  tomId: 'popupMenu.edit',
                  child: TomText(tomId: 'popupMenu.edit'),
                ),
                TomPopupMenuItem<String>(
                  value: 'share',
                  tomId: 'popupMenu.share',
                  child: TomText(tomId: 'popupMenu.share'),
                ),
              ],
              onSelected: (value) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckedPopupMenuSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'checkedPopup',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomText(tomId: 'checkedPopup.viewLabel'),
                TomSizedBox(width: 16),
                TomPopupMenuButton<String>(
                  tomId: 'checkedPopup.view',
                  child: TomRow(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TomIcon(tomId: 'checkedPopup.viewIcon'),
                      TomSizedBox(width: 8),
                      TomText(tomId: 'checkedPopup.viewText'),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  itemBuilder: (context) => [
                    TomCheckedPopupMenuItem<String>(
                      value: 'preview',
                      checked: _showPreview,
                      tomId: 'checkedPopup.preview',
                      child: TomText(tomId: 'checkedPopup.preview'),
                    ),
                    TomCheckedPopupMenuItem<String>(
                      value: 'details',
                      checked: _showDetails,
                      tomId: 'checkedPopup.details',
                      child: TomText(tomId: 'checkedPopup.details'),
                    ),
                    TomCheckedPopupMenuItem<String>(
                      value: 'sidebar',
                      checked: _showSidebar,
                      tomId: 'checkedPopup.sidebar',
                      child: TomText(tomId: 'checkedPopup.sidebar'),
                    ),
                  ],
                  onSelected: (value) {
                    setState(() {
                      switch (value) {
                        case 'preview':
                          _showPreview = !_showPreview;
                        case 'details':
                          _showDetails = !_showDetails;
                        case 'sidebar':
                          _showSidebar = !_showSidebar;
                      }
                    });
                  },
                ),
              ],
            ),
            TomSizedBox(height: 16),

            // Status display
            Builder(
              builder: (context) {
                final preview = _showPreview
                    ? _resolveText('demo03.status.on', 'label')
                    : _resolveText('demo03.status.off', 'label');
                final details = _showDetails
                    ? _resolveText('demo03.status.on', 'label')
                    : _resolveText('demo03.status.off', 'label');
                final sidebar = _showSidebar
                    ? _resolveText('demo03.status.on', 'label')
                    : _resolveText('demo03.status.off', 'label');
                return TomText(
                  text:
                      'Preview: $preview, Details: $details, Sidebar: $sidebar',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 3: Menu Anchors
  // ===========================================================================

  Widget _buildMenuAnchorSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'menuAnchor',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu anchor with checkbox items
            TomText(tomId: 'menuAnchor.checkboxLabel'),
            TomSizedBox(height: 8),
            TomMenuAnchor(
              menuChildren: [
                TomCheckboxMenuButton(
                  tomId: 'menuAnchor.checkPreview',
                  value: _showPreview,
                  onChanged: (value) {
                    setState(() => _showPreview = value ?? false);
                  },
                  child: TomText(tomId: 'menuAnchor.checkPreview'),
                ),
                TomCheckboxMenuButton(
                  tomId: 'menuAnchor.checkDetails',
                  value: _showDetails,
                  onChanged: (value) {
                    setState(() => _showDetails = value ?? false);
                  },
                  child: TomText(tomId: 'menuAnchor.checkDetails'),
                ),
                TomCheckboxMenuButton(
                  tomId: 'menuAnchor.checkSidebar',
                  value: _showSidebar,
                  onChanged: (value) {
                    setState(() => _showSidebar = value ?? false);
                  },
                  child: TomText(tomId: 'menuAnchor.checkSidebar'),
                ),
              ],
              builder: (context, controller, child) {
                return TomFilledButton(
                  tonal: true,
                  tomId: 'menuAnchor.checkboxTrigger',
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
            ),
            TomSizedBox(height: 24),

            // Menu anchor with radio items
            TomText(tomId: 'menuAnchor.radioLabel'),
            TomSizedBox(height: 8),
            TomMenuAnchor(
              menuChildren: [
                TomRadioMenuButton<String>(
                  tomId: 'menuAnchor.radioOption1',
                  value: 'option1',
                  groupValue: _radioMenuValue,
                  onChanged: (value) {
                    setState(() => _radioMenuValue = value!);
                  },
                  child: TomText(tomId: 'menuAnchor.radioOption1'),
                ),
                TomRadioMenuButton<String>(
                  tomId: 'menuAnchor.radioOption2',
                  value: 'option2',
                  groupValue: _radioMenuValue,
                  onChanged: (value) {
                    setState(() => _radioMenuValue = value!);
                  },
                  child: TomText(tomId: 'menuAnchor.radioOption2'),
                ),
                TomRadioMenuButton<String>(
                  tomId: 'menuAnchor.radioOption3',
                  value: 'option3',
                  groupValue: _radioMenuValue,
                  onChanged: (value) {
                    setState(() => _radioMenuValue = value!);
                  },
                  child: TomText(tomId: 'menuAnchor.radioOption3'),
                ),
              ],
              builder: (context, controller, child) {
                return TomOutlinedButton(
                  tomId: 'menuAnchor.radioTrigger',
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
            ),
            TomSizedBox(height: 16),

            // Status display
            TomText(
              text: 'Selected: $_radioMenuValue',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 4: Cupertino Segmented Controls
  // ===========================================================================

  Widget _buildCupertinoSegmentedSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertinoSegmented',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sliding segmented control
            TomText(tomId: 'cupertinoSegmented.slidingLabel'),
            TomSizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TomCupertinoSlidingSegmentedControl<int>(
                groupValue: _slidingValue,
                children: {
                  0: TomText(tomId: 'cupertinoSegmented.day'),
                  1: TomText(tomId: 'cupertinoSegmented.week'),
                  2: TomText(tomId: 'cupertinoSegmented.month'),
                  3: TomText(tomId: 'cupertinoSegmented.year'),
                },
                onValueChanged: (value) {
                  setState(() => _slidingValue = value!);
                },
              ),
            ),
            TomSizedBox(height: 24),

            // Classic segmented control
            TomText(tomId: 'cupertinoSegmented.classicLabel'),
            TomSizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TomCupertinoSegmentedControl<int>(
                groupValue: _segmentedValue,
                children: {
                  0: TomPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TomText(tomId: 'cupertinoSegmented.first'),
                  ),
                  1: TomPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TomText(tomId: 'cupertinoSegmented.second'),
                  ),
                  2: TomPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TomText(tomId: 'cupertinoSegmented.third'),
                  ),
                },
                onValueChanged: (value) {
                  setState(() => _segmentedValue = value);
                },
              ),
            ),
            TomSizedBox(height: 16),

            // Status display
            TomText(
              text:
                  'Sliding: ${_resolveText('demo03.cupertinoSegmented.${['day', 'week', 'month', 'year'][_slidingValue]}', 'label')}, Classic: ${_resolveText('demo03.cupertinoSegmented.${['first', 'second', 'third'][_segmentedValue]}', 'label')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoPickerSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertinoPicker',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(tomId: 'cupertinoPicker.fruitLabel'),
            TomSizedBox(height: 8),
            TomContainer(
              height: 200,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TomCupertinoPicker(
                itemExtent: 36,
                onSelectedItemChanged: (index) {
                  setState(() => _pickerValue = index);
                },
                children: _fruitKeys
                    .map(
                      (key) => Center(
                        child: TomText(
                          tomId: 'data.fruit.$key',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            TomSizedBox(height: 16),

            // Selected fruit display
            TomRow(
              children: [
                TomIcon(tomId: 'cupertinoPicker.selectedIcon'),
                TomSizedBox(width: 8),
                TomText(
                  tomId: 'data.fruit.${_fruitKeys[_pickerValue]}',
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

  Widget _buildAclDropdownSection() {
    return _DemoCard(
      tomId: 'aclDropdown',
      child: AclBuilder()
          // Row 1: Label + Dropdown side by side
          .append(TomText(tomId: 'aclDropdown.categoryLabel'))
          .append(
            TomDropdownButton<String>(
              tomId: 'aclDropdown.category',
              value: _selectedCategory,
              isExpanded: true,
              items: _categoryKeys
                  .map(
                    (key) => TomDropdownMenuItem<String>(
                      tomId: 'data.category.$key',
                      value: key,
                      child: TomText(tomId: 'data.category.$key'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            dist: 16,
          )
          .expandX()
          .newRow(dist: 16)
          // Row 2: Label + Dropdown Menu
          .append(TomText(tomId: 'aclDropdown.sizeLabel'))
          .append(
            TomDropdownMenu<String>(
              tomId: 'aclDropdown.size',
              initialSelection: _selectedSize,
              dropdownMenuEntries: _sizeKeys
                  .map(
                    (key) => DropdownMenuEntry<String>(
                      value: key,
                      label: _resolveText('demo03.data.size.$key', 'label'),
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                setState(() => _selectedSize = value);
              },
            ),
            dist: 16,
          )
          .gap()
          .build(),
    );
  }

  Widget _buildAclSegmentedSection() {
    return _DemoCard(
      tomId: 'aclSegmented',
      child: AclBuilder()
          // Row 1: Label + Sliding segmented
          .append(TomText(tomId: 'aclSegmented.periodLabel'))
          .append(
            TomCupertinoSlidingSegmentedControl<int>(
              groupValue: _slidingValue,
              children: {
                0: TomText(tomId: 'aclSegmented.day'),
                1: TomText(tomId: 'aclSegmented.week'),
                2: TomText(tomId: 'aclSegmented.month'),
              },
              onValueChanged: (value) {
                setState(() => _slidingValue = value!);
              },
            ),
            dist: 16,
          )
          .expandX()
          .newRow(dist: 24)
          // Row 2: Action buttons
          .append(
            TomTextButton(
              tomId: 'aclSegmented.reset',
              onPressed: () {
                setState(() {
                  _slidingValue = 0;
                  _selectedCategory = null;
                  _selectedSize = null;
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(tomId: 'aclSegmented.apply', onPressed: () {}),
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
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({required this.tomId});

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

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
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
                    tomId: tomId,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                TomSizedBox(width: 12),
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
            TomSizedBox(height: 16),
            TomDivider(color: theme.colorScheme.outlineVariant),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
