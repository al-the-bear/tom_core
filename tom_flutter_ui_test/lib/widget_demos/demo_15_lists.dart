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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'ListTile Variants',
          subtitle: 'Basic list items',
        ),
        _ListTileSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ListTile Density',
          subtitle: 'Compact and standard density',
        ),
        _DensitySection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ListTile Selection',
          subtitle: 'Selectable list items',
        ),
        _SelectionSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Expansion Tiles',
          subtitle: 'Collapsible list items',
        ),
        _ExpansionSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Reorderable Lists',
          subtitle: 'Drag-to-reorder list items',
        ),
        _ReorderableSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Dismissible Lists',
          subtitle: 'Swipe-to-dismiss list items',
        ),
        _DismissibleSection(),
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
// ListTile Section
// =============================================================================

class _ListTileSection extends StatelessWidget {
  const _ListTileSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('Basic ListTile'),
          ),
          const Divider(height: 1),
          const ListTile(
            title: Text('With Subtitle'),
            subtitle: Text('Secondary text goes here'),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('With Leading Icon'),
            subtitle: Text('Contact information'),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: CircleAvatar(child: Text('AB')),
            title: Text('With Avatar'),
            subtitle: Text('User profile'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('With Image'),
            subtitle: const Text('Image description'),
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade300,
                child: const Icon(Icons.photo, color: Colors.grey),
              ),
            ),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.star, color: Colors.amber),
            title: Text('Three-Line ListTile'),
            subtitle: Text(
              'This is a longer description that spans multiple lines to show how the ListTile handles overflow content.',
            ),
            isThreeLine: true,
            trailing: Icon(Icons.more_vert),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Enabled Tile'),
            subtitle: const Text('Tap enabled'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.block),
            title: Text('Disabled Tile'),
            subtitle: Text('Tap disabled'),
            enabled: false,
            trailing: Icon(Icons.chevron_right),
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
    return Column(
      children: [
        _buildDemoCard(
          'Standard Density',
          'Default list tile spacing.',
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inbox),
                  title: const Text('Inbox'),
                  trailing: const Text('5'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.send),
                  title: const Text('Sent'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.drafts),
                  title: const Text('Drafts'),
                  trailing: const Text('2'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Dense ListTiles',
          'Compact list tile spacing.',
          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.inbox, size: 20),
                  title: const Text('Inbox'),
                  trailing: const Text('5'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.send, size: 20),
                  title: const Text('Sent'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.drafts, size: 20),
                  title: const Text('Drafts'),
                  trailing: const Text('2'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Custom Content Padding',
          'ListTile with adjusted padding.',
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.person),
                  ),
                  title: const Text('Extra Padding'),
                  subtitle: const Text('More breathing room'),
                  trailing: IconButton(
                    icon: const Icon(Icons.message),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
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
    return Column(
      children: [
        _buildDemoCard(
          'Single Selection',
          'Select one item at a time.',
          Card(
            child: Column(
              children: List.generate(4, (index) {
                final isSelected = _selectedIndex == index;
                return Column(
                  children: [
                    ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      leading: Icon(
                        _icons[index],
                        color: isSelected ? Colors.blue : null,
                      ),
                      title: Text(_titles[index]),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                    if (index < 3) const Divider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ),
        _buildDemoCard(
          'Multi Selection',
          'Select multiple items.',
          Card(
            child: Column(
              children: List.generate(4, (index) {
                final isSelected = _multiSelection.contains(index);
                return Column(
                  children: [
                    ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.green.shade50,
                      leading: isSelected
                          ? const Icon(Icons.check_box, color: Colors.green)
                          : const Icon(Icons.check_box_outline_blank),
                      title: Text(_titles[index]),
                      onTap: () => setState(() {
                        if (isSelected) {
                          _multiSelection.remove(index);
                        } else {
                          _multiSelection.add(index);
                        }
                      }),
                    ),
                    if (index < 3) const Divider(height: 1),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
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
    return Column(
      children: [
        _buildDemoCard(
          'Basic ExpansionTile',
          'Collapsible list tile with children.',
          Card(
            child: Column(
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Documents'),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description, size: 20),
                      title: const Text('Resume.pdf'),
                      dense: true,
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.description, size: 20),
                      title: const Text('Cover Letter.docx'),
                      dense: true,
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.description, size: 20),
                      title: const Text('Portfolio.pdf'),
                      dense: true,
                      onTap: () {},
                    ),
                  ],
                ),
                const Divider(height: 1),
                ExpansionTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photos'),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.image, size: 20),
                      title: const Text('Vacation 2024'),
                      dense: true,
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.image, size: 20),
                      title: const Text('Family'),
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
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              subtitle: const Text('App configuration'),
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: false,
                  onChanged: (v) {},
                ),
                SwitchListTile(
                  title: const Text('Notifications'),
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
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Project Structure'),
              children: [
                ExpansionTile(
                  leading: const Icon(Icons.folder_open, size: 20),
                  title: const Text('lib'),
                  tilePadding: const EdgeInsets.only(left: 32, right: 16),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code, size: 18),
                      title: const Text('main.dart'),
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.code, size: 18),
                      title: const Text('app.dart'),
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      dense: true,
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.folder_open, size: 20),
                  title: const Text('test'),
                  tilePadding: const EdgeInsets.only(left: 32, right: 16),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code, size: 18),
                      title: const Text('widget_test.dart'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
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
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Drag items to reorder',
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
              return ListTile(
                key: ValueKey(_items[index]),
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(_items[index]),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
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
    return Card(
      child: Column(
        children: [
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('All items dismissed'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _resetItems,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey(item),
                  background: Container(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.archive, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() => _items.removeAt(index));
                    final action =
                        direction == DismissDirection.startToEnd ? 'Archived' : 'Deleted';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$action: $item')),
                    );
                  },
                  child: ListTile(
                    leading: const Icon(Icons.mail),
                    title: Text(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
