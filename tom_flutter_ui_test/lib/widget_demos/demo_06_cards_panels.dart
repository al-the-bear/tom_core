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
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Card',
          subtitle: 'Material design card containers',
        ),
        _CardSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'ExpansionTile',
          subtitle: 'Collapsible list tiles',
        ),
        _ExpansionTileSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'ExpansionPanel',
          subtitle: 'Accordion-style expandable panels',
        ),
        _ExpansionPanelSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Panel Patterns',
          subtitle: 'Common panel layouts and designs',
        ),
        _PanelPatternsSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Interactive Cards',
          subtitle: 'Cards with actions and gestures',
        ),
        _InteractiveCardsSection(),
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
// Card Section
// =============================================================================

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic Card',
          'Simple card with padding and content.',
          const TomCard(
            child: TomPadding(
              padding: EdgeInsets.all(16),
              child: TomText('This is a basic card with some content inside.'),
            ),
          ),
        ),
        _buildDemoCard(
          'Elevated Card',
          'Card with custom elevation and shadow.',
          TomCard(
            tomId: 'demo.card.elevated',
            elevation: 8,
            shadowColor: Colors.black45,
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomColumn(
                children: [
                  const TomIcon(Icons.cloud, size: 48, color: Colors.blue),
                  const TomSizedBox(height: 8),
                  TomText(
                    'Elevated Card',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const TomText('With shadow'),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Outlined Card',
          'Card with border instead of shadow.',
          TomCard(
            tomId: 'demo.card.outlined',
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const TomPadding(
              padding: EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomIcon(Icons.info_outline),
                  TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomText('This is an outlined card without elevation.'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Filled Card',
          'Card with filled background color.',
          TomCard(
            tomId: 'demo.card.filled',
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                children: [
                  TomIcon(
                    Icons.lightbulb,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const TomSizedBox(width: 12),
                  TomExpanded(
                    child: TomText(
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
          TomCard(
            tomId: 'demo.card.image',
            clipBehavior: Clip.antiAlias,
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TomContainer(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.blue.shade300],
                    ),
                  ),
                  child: const TomCenter(
                    child: TomIcon(Icons.image, size: 48, color: Colors.white),
                  ),
                ),
                TomPadding(
                  padding: const EdgeInsets.all(16),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        'Card Title',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const TomSizedBox(height: 4),
                      const TomText('Card description goes here with some text.'),
                      const TomSizedBox(height: 8),
                      TomRow(
                        children: [
                          TomTextButton(onPressed: () {}, child: const TomText('ACTION 1')),
                          TomTextButton(onPressed: () {}, child: const TomText('ACTION 2')),
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
          TomRow(
            children: [
              TomExpanded(
                child: TomCard(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: const TomPadding(
                    padding: EdgeInsets.all(12),
                    child: TomCenter(child: TomText('Square')),
                  ),
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomCard(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const TomPadding(
                    padding: EdgeInsets.all(12),
                    child: TomCenter(child: TomText('Rounded')),
                  ),
                ),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child: TomCard(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const TomPadding(
                    padding: EdgeInsets.all(12),
                    child: TomCenter(child: TomText('Stadium')),
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
            const TomSizedBox(height: 12),
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
    return TomCard(
      child: TomColumn(
        children: [
          const TomExpansionTile(
            leading: TomIcon(Icons.folder),
            title: TomText('Basic ExpansionTile'),
            subtitle: TomText('Tap to expand'),
            children: [
              TomListTile(title: TomText('Item 1')),
              TomListTile(title: TomText('Item 2')),
              TomListTile(title: TomText('Item 3')),
            ],
          ),
          const TomDivider(height: 1),
          TomExpansionTile(
            tomId: 'demo.expansion.styled',
            leading: const TomIcon(Icons.settings),
            title: const TomText('Styled ExpansionTile'),
            iconColor: Colors.purple,
            collapsedIconColor: Colors.grey,
            backgroundColor: Colors.purple.shade50,
            children: [
              TomListTile(
                leading: TomIcon(Icons.brightness_6),
                title: TomText('Appearance'),
                trailing: TomIcon(Icons.chevron_right),
              ),
              TomListTile(
                leading: TomIcon(Icons.language),
                title: TomText('Language'),
                trailing: TomIcon(Icons.chevron_right),
              ),
            ],
          ),
          const TomDivider(height: 1),
          TomExpansionTile(
            tomId: 'demo.expansion.profile',
            initiallyExpanded: true,
            shape: Border.all(color: Colors.transparent),
            leading: const TomCircleAvatar(
              backgroundColor: Colors.blue,
              child: TomIcon(Icons.person, color: Colors.white),
            ),
            title: const TomText('Initially Expanded'),
            subtitle: const TomText('User Profile'),
            children: [
              TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomColumn(
                  children: [
                    _buildInfoRow('Name', 'John Doe'),
                    _buildInfoRow('Email', 'john@example.com'),
                    _buildInfoRow('Role', 'Administrator'),
                  ],
                ),
              ),
            ],
          ),
          const TomDivider(height: 1),
          const _NestedExpansionDemo(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TomRow(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TomText(label, style: const TextStyle(color: Colors.grey)),
          TomText(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NestedExpansionDemo extends StatelessWidget {
  const _NestedExpansionDemo();

  @override
  Widget build(BuildContext context) {
    return const TomExpansionTile(
      leading: TomIcon(Icons.menu_book),
      title: TomText('Nested ExpansionTiles'),
      subtitle: TomText('Documentation'),
      children: [
        TomExpansionTile(
          title: TomText('Getting Started'),
          leading: TomIcon(Icons.play_arrow),
          tilePadding: EdgeInsets.only(left: 32, right: 16),
          children: [
            TomListTile(
              title: TomText('Installation'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
            TomListTile(
              title: TomText('Configuration'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
          ],
        ),
        TomExpansionTile(
          title: TomText('API Reference'),
          leading: TomIcon(Icons.code),
          tilePadding: EdgeInsets.only(left: 32, right: 16),
          children: [
            TomListTile(
              title: TomText('Components'),
              contentPadding: EdgeInsets.only(left: 64),
            ),
            TomListTile(
              title: TomText('Utilities'),
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
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'ExpansionPanelList',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 8),
            const TomText(
              'Accordion-style panels where only one can be expanded at a time.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const TomSizedBox(height: 16),
            TomExpansionPanelList(
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
                    return const TomListTile(
                      leading: TomIcon(Icons.question_answer),
                      title: TomText('What is Flutter?'),
                    );
                  },
                  body: const TomPadding(
                    padding: EdgeInsets.all(16),
                    child: TomText(
                      'Flutter is Google\'s UI toolkit for building beautiful, '
                      'natively compiled applications for mobile, web, and desktop '
                      'from a single codebase.',
                    ),
                  ),
                  isExpanded: _isExpanded[0],
                ),
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const TomListTile(
                      leading: TomIcon(Icons.code),
                      title: TomText('What is Dart?'),
                    );
                  },
                  body: const TomPadding(
                    padding: EdgeInsets.all(16),
                    child: TomText(
                      'Dart is a client-optimized programming language for apps on '
                      'multiple platforms. It is developed by Google and is used to '
                      'build mobile, desktop, server, and web applications.',
                    ),
                  ),
                  isExpanded: _isExpanded[1],
                ),
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) {
                    return const TomListTile(
                      leading: TomIcon(Icons.widgets),
                      title: TomText('What are widgets?'),
                    );
                  },
                  body: const TomPadding(
                    padding: EdgeInsets.all(16),
                    child: TomText(
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Info Panel',
          'Alert-style panels with icons.',
          TomColumn(
            children: [
              _buildAlertPanel(
                icon: Icons.info,
                color: Colors.blue,
                title: 'Information',
                message: 'This is an informational message.',
              ),
              const TomSizedBox(height: 8),
              _buildAlertPanel(
                icon: Icons.check_circle,
                color: Colors.green,
                title: 'Success',
                message: 'Your action was completed successfully.',
              ),
              const TomSizedBox(height: 8),
              _buildAlertPanel(
                icon: Icons.warning,
                color: Colors.orange,
                title: 'Warning',
                message: 'Please review this before continuing.',
              ),
              const TomSizedBox(height: 8),
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
          TomRow(
            children: [
              TomExpanded(
                child: _buildStatCard('Users', '12,345', Icons.people, Colors.blue),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child:
                    _buildStatCard('Revenue', '\$45.2K', Icons.attach_money, Colors.green),
              ),
              const TomSizedBox(width: 8),
              TomExpanded(
                child:
                    _buildStatCard('Orders', '1,234', Icons.shopping_cart, Colors.purple),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Feature Panel',
          'Showcase features with icons.',
          TomColumn(
            children:
                [
                  ('Fast', 'Lightning fast performance', Icons.bolt),
                  ('Secure', 'Enterprise-grade security', Icons.security),
                  ('Scalable', 'Grows with your needs', Icons.trending_up),
                ].map((f) {
                  return TomListTile(
                    leading: TomCircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: TomIcon(
                        f.$3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: TomText(f.$1),
                    subtitle: TomText(f.$2),
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
    return TomContainer(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: TomRow(
        children: [
          TomIcon(icon, color: color),
          const TomSizedBox(width: 12),
          TomExpanded(
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TomText(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                TomText(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return TomCard(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: TomPadding(
        padding: const EdgeInsets.all(12),
        child: TomColumn(
          children: [
            TomIcon(icon, color: color),
            const TomSizedBox(height: 8),
            TomText(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            TomText(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
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
            const TomSizedBox(height: 12),
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
    return TomColumn(
      children: [
        _buildDemoCard(
          'Selectable Cards',
          'Cards that can be selected with visual feedback.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(4, (index) {
              final isSelected = _selectedIndex == index;
              return TomInkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: TomAnimatedContainer(
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
                  child: TomColumn(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TomIcon(
                        [Icons.home, Icons.work, Icons.school, Icons.park][index],
                        color:
                            isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const TomSizedBox(height: 4),
                      TomText(
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
              return TomCard(
                child: TomStack(
                  children: [
                    TomPadding(
                      padding: const EdgeInsets.all(12),
                      child: TomColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TomText(
                            'Item ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TomText(
                            'Description here',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    TomPositioned(
                      top: 4,
                      right: 4,
                      child: TomIconButton(
                        icon: TomIcon(
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
            const TomSizedBox(height: 12),
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
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TomText(
              'Dismissible Cards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            const TomText(
              'Swipe left or right to dismiss.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            ..._items.map((item) {
              return TomPadding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TomDismissible(
                  key: Key(item),
                  onDismissed: (direction) {
                    setState(() => _items.remove(item));
                    ScaffoldMessenger.of(context).showSnackBar(
                      TomSnackBar(
                        content: TomText('$item dismissed'),
                        action: TomSnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            setState(() => _items.add(item));
                          },
                        ),
                      ),
                    );
                  },
                  background: TomContainer(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const TomIcon(Icons.check, color: Colors.white),
                  ),
                  secondaryBackground: TomContainer(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const TomIcon(Icons.delete, color: Colors.white),
                  ),
                  child: TomCard(
                    margin: EdgeInsets.zero,
                    child: TomListTile(
                      leading: const TomIcon(Icons.drag_indicator),
                      title: TomText(item),
                      subtitle: const TomText('Swipe to dismiss'),
                    ),
                  ),
                ),
              );
            }),
            if (_items.isEmpty)
              const TomCenter(
                child: TomPadding(
                  padding: EdgeInsets.all(16),
                  child: TomText('All items dismissed!'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
