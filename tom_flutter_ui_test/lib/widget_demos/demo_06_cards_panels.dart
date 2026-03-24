/// Comprehensive Cards and Panels Demo
///
/// This demo showcases Card widgets, ExpansionTile, ExpansionPanel,
/// and various panel patterns with their configurations and styling.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main cards and panels demo screen.
class CardsPanelsDemo extends StatelessWidget {
  const CardsPanelsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Card',
          subtitle: 'Material design card containers',
        ),
        _CardSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ExpansionTile',
          subtitle: 'Collapsible list tiles',
        ),
        _ExpansionTileSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'ExpansionPanel',
          subtitle: 'Accordion-style expandable panels',
        ),
        _ExpansionPanelSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Panel Patterns',
          subtitle: 'Common panel layouts and designs',
        ),
        _PanelPatternsSection(),
        SizedBox(height: 32),
        _SectionHeader(
          title: 'Interactive Cards',
          subtitle: 'Cards with actions and gestures',
        ),
        _InteractiveCardsSection(),
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
// Card Section
// =============================================================================

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Basic Card',
          'Simple card with padding and content.',
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('This is a basic card with some content inside.'),
            ),
          ),
        ),
        _buildDemoCard(
          'Elevated Card',
          'Card with custom elevation and shadow.',
          Card(
            elevation: 8,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.cloud, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    'Elevated Card',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('With shadow'),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Outlined Card',
          'Card with border instead of shadow.',
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('This is an outlined card without elevation.'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Filled Card',
          'Card with filled background color.',
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: You can use filled cards for emphasis.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Card with Image',
          'Card containing an image header.',
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.blue.shade300],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card Title',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text('Card description goes here with some text.'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(onPressed: () {}, child: const Text('ACTION 1')),
                          TextButton(onPressed: () {}, child: const Text('ACTION 2')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Card Shapes',
          'Different border radius and shapes.',
          Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('Square')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('Rounded')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('Stadium')),
                  ),
                ),
              ),
            ],
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ExpansionTile Section
// =============================================================================

class _ExpansionTileSection extends StatelessWidget {
  const _ExpansionTileSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ExpansionTile(
            leading: Icon(Icons.folder),
            title: Text('Basic ExpansionTile'),
            subtitle: Text('Tap to expand'),
            children: [
              ListTile(title: Text('Item 1')),
              ListTile(title: Text('Item 2')),
              ListTile(title: Text('Item 3')),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            leading: const Icon(Icons.settings),
            title: const Text('Styled ExpansionTile'),
            iconColor: Colors.purple,
            collapsedIconColor: Colors.grey,
            backgroundColor: Colors.purple.shade50,
            children: [
              ListTile(
                leading: Icon(Icons.brightness_6),
                title: Text('Appearance'),
                trailing: Icon(Icons.chevron_right),
              ),
              ListTile(
                leading: Icon(Icons.language),
                title: Text('Language'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Divider(height: 1),
          ExpansionTile(
            initiallyExpanded: true,
            shape: Border.all(color: Colors.transparent),
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: const Text('Initially Expanded'),
            subtitle: const Text('User Profile'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Name', 'John Doe'),
                    _buildInfoRow('Email', 'john@example.com'),
                    _buildInfoRow('Role', 'Administrator'),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          const _NestedExpansionDemo(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NestedExpansionDemo extends StatelessWidget {
  const _NestedExpansionDemo();

  @override
  Widget build(BuildContext context) {
    return const ExpansionTile(
      leading: Icon(Icons.menu_book),
      title: Text('Nested ExpansionTiles'),
      subtitle: Text('Documentation'),
      children: [
        ExpansionTile(
          title: Text('Getting Started'),
          leading: Icon(Icons.play_arrow),
          tilePadding: EdgeInsets.only(left: 32, right: 16),
          children: [
            ListTile(
              title: Text('Installation'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
            ListTile(
              title: Text('Configuration'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('API Reference'),
          leading: Icon(Icons.code),
          tilePadding: EdgeInsets.only(left: 32, right: 16),
          children: [
            ListTile(
              title: Text('Components'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
            ListTile(
              title: Text('Utilities'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// ExpansionPanel Section
// =============================================================================

class _ExpansionPanelSection extends StatefulWidget {
  const _ExpansionPanelSection();

  @override
  State<_ExpansionPanelSection> createState() => _ExpansionPanelSectionState();
}

class _ExpansionPanelSectionState extends State<_ExpansionPanelSection> {
  final List<bool> _isExpanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ExpansionPanelList',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Accordion-style panels where only one can be expanded at a time.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ExpansionPanelList(
              elevation: 1,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: (index, isExpanded) {
                setState(() {
                  _isExpanded[index] = isExpanded;
                });
              },
              children: [
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const ListTile(
                      leading: Icon(Icons.question_answer),
                      title: Text('What is Flutter?'),
                    );
                  },
                  body: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Flutter is Google\'s UI toolkit for building beautiful, '
                      'natively compiled applications for mobile, web, and desktop '
                      'from a single codebase.',
                    ),
                  ),
                  isExpanded: _isExpanded[0],
                ),
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const ListTile(
                      leading: Icon(Icons.code),
                      title: Text('What is Dart?'),
                    );
                  },
                  body: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Dart is a client-optimized programming language for apps on '
                      'multiple platforms. It is developed by Google and is used to '
                      'build mobile, desktop, server, and web applications.',
                    ),
                  ),
                  isExpanded: _isExpanded[1],
                ),
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const ListTile(
                      leading: Icon(Icons.widgets),
                      title: Text('What are widgets?'),
                    );
                  },
                  body: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Widgets are the basic building blocks of a Flutter app\'s '
                      'user interface. Each widget is an immutable declaration of '
                      'part of the user interface.',
                    ),
                  ),
                  isExpanded: _isExpanded[2],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Panel Patterns Section
// =============================================================================

class _PanelPatternsSection extends StatelessWidget {
  const _PanelPatternsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Info Panel',
          'Alert-style panels with icons.',
          Column(
            children: [
              _buildAlertPanel(
                icon: Icons.info,
                color: Colors.blue,
                title: 'Information',
                message: 'This is an informational message.',
              ),
              const SizedBox(height: 8),
              _buildAlertPanel(
                icon: Icons.check_circle,
                color: Colors.green,
                title: 'Success',
                message: 'Your action was completed successfully.',
              ),
              const SizedBox(height: 8),
              _buildAlertPanel(
                icon: Icons.warning,
                color: Colors.orange,
                title: 'Warning',
                message: 'Please review this before continuing.',
              ),
              const SizedBox(height: 8),
              _buildAlertPanel(
                icon: Icons.error,
                color: Colors.red,
                title: 'Error',
                message: 'Something went wrong. Please try again.',
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Stats Panel',
          'Display statistics in a card grid.',
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Users', '12,345', Icons.people, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildStatCard('Revenue', '\$45.2K', Icons.attach_money, Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildStatCard('Orders', '1,234', Icons.shopping_cart, Colors.purple),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Feature Panel',
          'Showcase features with icons.',
          Column(
            children:
                [
                  ('Fast', 'Lightning fast performance', Icons.bolt),
                  ('Secure', 'Enterprise-grade security', Icons.security),
                  ('Scalable', 'Grows with your needs', Icons.trending_up),
                ].map((f) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        f.$3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(f.$1),
                    subtitle: Text(f.$2),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertPanel({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Interactive Cards Section
// =============================================================================

class _InteractiveCardsSection extends StatefulWidget {
  const _InteractiveCardsSection();

  @override
  State<_InteractiveCardsSection> createState() =>
      _InteractiveCardsSectionState();
}

class _InteractiveCardsSectionState extends State<_InteractiveCardsSection> {
  int _selectedIndex = -1;
  final _favorites = <int>{};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDemoCard(
          'Selectable Cards',
          'Cards that can be selected with visual feedback.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (index) {
              final isSelected = _selectedIndex == index;
              return InkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isSelected
                            ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                            : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        [Icons.home, Icons.work, Icons.school, Icons.park][index],
                        color:
                            isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['Home', 'Work', 'School', 'Park'][index],
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        _buildDemoCard(
          'Favorite Cards',
          'Cards with favorite toggle button.',
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: List.generate(4, (index) {
              final isFavorite = _favorites.contains(index);
              return Card(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Item ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Description here',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isFavorite) {
                              _favorites.remove(index);
                            } else {
                              _favorites.add(index);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const _SwipeableCardDemo(),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SwipeableCardDemo extends StatefulWidget {
  const _SwipeableCardDemo();

  @override
  State<_SwipeableCardDemo> createState() => _SwipeableCardDemoState();
}

class _SwipeableCardDemoState extends State<_SwipeableCardDemo> {
  final _items = List.generate(3, (i) => 'Swipeable Item ${i + 1}');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dismissible Cards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Swipe left or right to dismiss.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ..._items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: Key(item),
                  onDismissed: (direction) {
                    setState(() => _items.remove(item));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$item dismissed'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            setState(() => _items.add(item));
                          },
                        ),
                      ),
                    );
                  },
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.drag_indicator),
                      title: Text(item),
                      subtitle: const Text('Swipe to dismiss'),
                    ),
                  ),
                ),
              );
            }),
            if (_items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('All items dismissed!'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
