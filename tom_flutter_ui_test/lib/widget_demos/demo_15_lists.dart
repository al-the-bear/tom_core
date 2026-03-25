/// Comprehensive Lists Demo
///
/// This demo showcases ListTile, ExpansionTile, ReorderableListView,
/// and various list patterns.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main lists demo screen.
class ListsDemo extends StatelessWidget {
  const ListsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'ListTile Variants',
          subtitle: 'Basic list items',
        ),
        _ListTileSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'ListTile Density',
          subtitle: 'Compact and standard density',
        ),
        _DensitySection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'ListTile Selection',
          subtitle: 'Selectable list items',
        ),
        _SelectionSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Expansion Tiles',
          subtitle: 'Collapsible list items',
        ),
        _ExpansionSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Reorderable Lists',
          subtitle: 'Drag-to-reorder list items',
        ),
        _ReorderableSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Dismissible Lists',
          subtitle: 'Swipe-to-dismiss list items',
        ),
        _DismissibleSection(),
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
// ListTile Section
// =============================================================================

class _ListTileSection extends StatelessWidget {
  const _ListTileSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomColumn(
        children: [
          const TomListTile(
            title: TomText(null, tomId: 'demo.15.auto.text.1'),
          ),
          const TomDivider(height: 1),
          const TomListTile(
            title: TomText(null, tomId: 'demo.15.auto.text.2'),
            subtitle: TomText(null, tomId: 'demo.15.auto.text.29'),
          ),
          const TomDivider(height: 1),
          const TomListTile(
            leading: TomIcon(Icons.person),
            title: TomText(null, tomId: 'demo.15.auto.text.30'),
            subtitle: TomText(null, tomId: 'demo.15.auto.text.31'),
          ),
          const TomDivider(height: 1),
          const TomListTile(
            leading: TomCircleAvatar(child: TomText(null, tomId: 'demo.15.auto.text.3')),
            title: TomText(null, tomId: 'demo.15.auto.text.4'),
            subtitle: TomText(null, tomId: 'demo.15.auto.text.5'),
            trailing: TomIcon(Icons.chevron_right),
          ),
          const TomDivider(height: 1),
          TomListTile(
            leading: const TomIcon(Icons.image),
            title: const TomText(null, tomId: 'demo.15.auto.text.6'),
            subtitle: const TomText(null, tomId: 'demo.15.auto.text.32'),
            trailing: TomClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TomContainer(
                width: 56,
                height: 56,
                color: Colors.grey.shade300,
                child: const TomIcon(Icons.photo, color: Colors.grey),
              ),
            ),
          ),
          const TomDivider(height: 1),
          const TomListTile(
            leading: TomIcon(Icons.star, color: Colors.amber),
            title: TomText(null, tomId: 'demo.15.auto.text.33'),
            subtitle: TomText(null, tomId: 'demo.15.auto.text.28',
            ),
            isThreeLine: true,
            trailing: TomIcon(Icons.more_vert),
          ),
          const TomDivider(height: 1),
          TomListTile(
            leading: const TomIcon(Icons.notifications),
            title: const TomText(null, tomId: 'demo.15.auto.text.34'),
            subtitle: const TomText(null, tomId: 'demo.15.auto.text.35'),
            trailing: const TomIcon(Icons.chevron_right),
            onTap: () {},
          ),
          const TomDivider(height: 1),
          const TomListTile(
            leading: TomIcon(Icons.block),
            title: TomText(null, tomId: 'demo.15.auto.text.7'),
            subtitle: TomText(null, tomId: 'demo.15.auto.text.8'),
            enabled: false,
            trailing: TomIcon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Density Section
// =============================================================================

class _DensitySection extends StatelessWidget {
  const _DensitySection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Standard Density',
          'Default list tile spacing.',
          TomCard(
            child: TomColumn(
              children: [
                TomListTile(
                  leading: const TomIcon(Icons.inbox),
                  title: const TomText(null, tomId: 'demo.15.auto.text.36'),
                  trailing: const TomText(null, tomId: 'demo.15.auto.text.9'),
                  onTap: () {},
                ),
                const TomDivider(height: 1),
                TomListTile(
                  leading: const TomIcon(Icons.send),
                  title: const TomText(null, tomId: 'demo.15.auto.text.37'),
                  onTap: () {},
                ),
                const TomDivider(height: 1),
                TomListTile(
                  leading: const TomIcon(Icons.drafts),
                  title: const TomText(null, tomId: 'demo.15.auto.text.10'),
                  trailing: const TomText(null, tomId: 'demo.15.auto.text.11'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Dense ListTiles',
          'Compact list tile spacing.',
          TomCard(
            child: TomColumn(
              children: [
                TomListTile(
                  dense: true,
                  leading: const TomIcon(Icons.inbox, size: 20),
                  title: const TomText(null, tomId: 'demo.15.auto.text.38'),
                  trailing: const TomText(null, tomId: 'demo.15.auto.text.12'),
                  onTap: () {},
                ),
                const TomDivider(height: 1),
                TomListTile(
                  dense: true,
                  leading: const TomIcon(Icons.send, size: 20),
                  title: const TomText(null, tomId: 'demo.15.auto.text.39'),
                  onTap: () {},
                ),
                const TomDivider(height: 1),
                TomListTile(
                  dense: true,
                  leading: const TomIcon(Icons.drafts, size: 20),
                  title: const TomText(null, tomId: 'demo.15.auto.text.13'),
                  trailing: const TomText(null, tomId: 'demo.15.auto.text.14'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Custom Content Padding',
          'ListTile with adjusted padding.',
          TomCard(
            child: TomColumn(
              children: [
                TomListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: const TomCircleAvatar(
                    radius: 24,
                    child: TomIcon(Icons.person),
                  ),
                  title: const TomText(null, tomId: 'demo.15.auto.text.40'),
                  subtitle: const TomText(null, tomId: 'demo.15.auto.text.41'),
                  trailing: TomIconButton(
                    icon: const TomIcon(Icons.message),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Selection Section
// =============================================================================

class _SelectionSection extends StatefulWidget {
  const _SelectionSection();

  @override
  State<_SelectionSection> createState() => _SelectionSectionState();
}

class _SelectionSectionState extends State<_SelectionSection> {
  int _selectedIndex = 0;
  final Set<int> _multiSelection = {0, 2};

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Single Selection',
          'Select one item at a time.',
          TomCard(
            child: TomColumn(
              children: List.generate(4, (index) {
                final isSelected = _selectedIndex == index;
                return TomColumn(
                  children: [
                    TomListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      leading: TomIcon(
                        _icons[index],
                        color: isSelected ? Colors.blue : null,
                      ),
                      title: TomText(_titles[index]),
                      trailing: isSelected
                          ? const TomIcon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                    if (index < 3) const TomDivider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ),
        _buildDemoCard(
          'Multi Selection',
          'Select multiple items.',
          TomCard(
            child: TomColumn(
              children: List.generate(4, (index) {
                final isSelected = _multiSelection.contains(index);
                return TomColumn(
                  children: [
                    TomListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.green.shade50,
                      leading: isSelected
                          ? const TomIcon(Icons.check_box, color: Colors.green)
                          : const TomIcon(Icons.check_box_outline_blank),
                      title: TomText(_titles[index]),
                      onTap: () => setState(() {
                        if (isSelected) {
                          _multiSelection.remove(index);
                        } else {
                          _multiSelection.add(index);
                        }
                      }),
                    ),
                    if (index < 3) const TomDivider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  static const _icons = [
    Icons.home,
    Icons.settings,
    Icons.person,
    Icons.notifications,
  ];

  static const _titles = [
    'Home',
    'Settings',
    'Profile',
    'Notifications',
  ];

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Expansion Section
// =============================================================================

class _ExpansionSection extends StatelessWidget {
  const _ExpansionSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic ExpansionTile',
          'Collapsible list tile with children.',
          TomCard(
            child: TomColumn(
              children: [
                TomExpansionTile(
                  leading: const TomIcon(Icons.folder),
                  title: const TomText(null, tomId: 'demo.15.auto.text.42'),
                  children: [
                    TomListTile(
                      leading: const TomIcon(Icons.description, size: 20),
                      title: const TomText(null, tomId: 'demo.15.auto.text.15'),
                      dense: true,
                      onTap: () {},
                    ),
                    TomListTile(
                      leading: const TomIcon(Icons.description, size: 20),
                      title: const TomText(null, tomId: 'demo.15.auto.text.16'),
                      dense: true,
                      onTap: () {},
                    ),
                    TomListTile(
                      leading: const TomIcon(Icons.description, size: 20),
                      title: const TomText(null, tomId: 'demo.15.auto.text.17'),
                      dense: true,
                      onTap: () {},
                    ),
                  ],
                ),
                const TomDivider(height: 1),
                TomExpansionTile(
                  leading: const TomIcon(Icons.photo_library),
                  title: const TomText(null, tomId: 'demo.15.auto.text.18'),
                  children: [
                    TomListTile(
                      leading: const TomIcon(Icons.image, size: 20),
                      title: const TomText(null, tomId: 'demo.15.auto.text.43'),
                      dense: true,
                      onTap: () {},
                    ),
                    TomListTile(
                      leading: const TomIcon(Icons.image, size: 20),
                      title: const TomText(null, tomId: 'demo.15.auto.text.19'),
                      dense: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Initially Expanded',
          'ExpansionTile that starts expanded.',
          TomCard(
            child: TomExpansionTile(
              initiallyExpanded: true,
              leading: const TomIcon(Icons.settings),
              title: const TomText(null, tomId: 'demo.15.auto.text.44'),
              subtitle: const TomText(null, tomId: 'demo.15.auto.text.45'),
              children: [
                TomSwitchListTile(
                  title: const TomText(null, tomId: 'demo.15.auto.text.20'),
                  value: false,
                  onChanged: (v) {},
                ),
                TomSwitchListTile(
                  title: const TomText(null, tomId: 'demo.15.auto.text.46'),
                  value: true,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Nested Expansion',
          'ExpansionTiles within ExpansionTiles.',
          TomCard(
            child: TomExpansionTile(
              leading: const TomIcon(Icons.account_tree),
              title: const TomText(null, tomId: 'demo.15.auto.text.21'),
              children: [
                TomExpansionTile(
                  leading: const TomIcon(Icons.folder_open, size: 20),
                  title: const TomText(null, tomId: 'demo.15.auto.text.22'),
                  tilePadding: const EdgeInsets.only(left: 32, right: 16),
                  children: [
                    TomListTile(
                      leading: const TomIcon(Icons.code, size: 18),
                      title: const TomText(null, tomId: 'demo.15.auto.text.47'),
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      dense: true,
                    ),
                    TomListTile(
                      leading: const TomIcon(Icons.code, size: 18),
                      title: const TomText(null, tomId: 'demo.15.auto.text.23'),
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      dense: true,
                    ),
                  ],
                ),
                TomExpansionTile(
                  leading: const TomIcon(Icons.folder_open, size: 20),
                  title: const TomText(null, tomId: 'demo.15.auto.text.24'),
                  tilePadding: const EdgeInsets.only(left: 32, right: 16),
                  children: [
                    TomListTile(
                      leading: const TomIcon(Icons.code, size: 18),
                      title: const TomText(null, tomId: 'demo.15.auto.text.25'),
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String title, String description, Widget child) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Reorderable Section
// =============================================================================

class _ReorderableSection extends StatefulWidget {
  const _ReorderableSection();

  @override
  State<_ReorderableSection> createState() => _ReorderableSectionState();
}

class _ReorderableSectionState extends State<_ReorderableSection> {
  final List<String> _items = [
    'First Item',
    'Second Item',
    'Third Item',
    'Fourth Item',
    'Fifth Item',
  ];

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomPadding(
            padding: const EdgeInsets.all(16),
            child: TomText(null, tomId: 'demo.15.auto.text.1',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              return TomListTile(
                key: ValueKey(_items[index]),
                leading: TomCircleAvatar(
                  child: TomText('${index + 1}'),
                ),
                title: TomText(_items[index]),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const TomIcon(Icons.drag_handle),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dismissible Section
// =============================================================================

class _DismissibleSection extends StatefulWidget {
  const _DismissibleSection();

  @override
  State<_DismissibleSection> createState() => _DismissibleSectionState();
}

class _DismissibleSectionState extends State<_DismissibleSection> {
  List<String> _items = [
    'Swipe left to delete',
    'Swipe right to archive',
    'Another item',
    'One more item',
  ];

  void _resetItems() {
    setState(() {
      _items = [
        'Swipe left to delete',
        'Swipe right to archive',
        'Another item',
        'One more item',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomColumn(
        children: [
          if (_items.isEmpty)
            TomPadding(
              padding: const EdgeInsets.all(32),
              child: TomColumn(
                children: [
                  const TomText(null, tomId: 'demo.15.auto.text.26'),
                  const TomSizedBox(height: 16),
                  TomFilledButton(
                    onPressed: _resetItems,
                    child: const TomText(null, tomId: 'demo.15.auto.text.27'),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const TomDivider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return TomDismissible(
                  key: ValueKey(item),
                  background: TomContainer(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const TomIcon(Icons.archive, color: Colors.white),
                  ),
                  secondaryBackground: TomContainer(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const TomIcon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() => _items.removeAt(index));
                    final action =
                        direction == DismissDirection.startToEnd ? 'Archived' : 'Deleted';
                    ScaffoldMessenger.of(context).showSnackBar(
                      TomSnackBar(content: TomText('$action: $item')),
                    );
                  },
                  child: TomListTile(
                    leading: const TomIcon(Icons.mail),
                    title: TomText(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
