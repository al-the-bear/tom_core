/// Demo 15: List Views
///
/// Comprehensive demonstration of all Tom list view widgets.
/// Widgets covered: TomListView, TomAnimatedList, TomReorderableListView,
/// TomDismissible, TomListWheelScrollView.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the List Views demo.
class ListsDemo extends StatelessWidget {
  const ListsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ListsDemoContent();
  }
}

class _ListsDemoContent extends StatefulWidget {
  const _ListsDemoContent();

  @override
  State<_ListsDemoContent> createState() => _ListsDemoContentState();
}

class _ListsDemoContentState extends State<_ListsDemoContent>
    with TickerProviderStateMixin {
  // State for animated list
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  final List<String> _animatedItems = ['Item 1', 'Item 2', 'Item 3'];
  int _animatedItemCounter = 3;

  // State for reorderable list
  final List<String> _reorderableItems = [
    'Drag to reorder 1',
    'Drag to reorder 2',
    'Drag to reorder 3',
    'Drag to reorder 4',
    'Drag to reorder 5',
  ];

  // State for dismissible list
  final List<String> _dismissibleItems = [
    'Swipe to dismiss 1',
    'Swipe to dismiss 2',
    'Swipe to dismiss 3',
    'Swipe to dismiss 4',
    'Swipe to dismiss 5',
  ];

  // State for wheel scroll view
  int _selectedWheelItem = 0;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Basic ListView
            _SectionHeader(
              tomId: 'demo15.section.basic',
            ),
            const TomSizedBox(height: 16),
            _buildBasicListViewSection(),
            const TomSizedBox(height: 32),

            // Section 2: Animated Lists
            _SectionHeader(
              tomId: 'demo15.section.animated',
            ),
            const TomSizedBox(height: 16),
            _buildAnimatedListSection(),
            const TomSizedBox(height: 32),

            // Section 3: Reorderable & Dismissible
            _SectionHeader(
              tomId: 'demo15.section.interactive',
            ),
            const TomSizedBox(height: 16),
            _buildReorderableSection(),
            const TomSizedBox(height: 24),
            _buildDismissibleSection(),
            const TomSizedBox(height: 32),

            // Section 4: Wheel Scroll View
            _SectionHeader(
              tomId: 'demo15.section.wheel',
            ),
            const TomSizedBox(height: 16),
            _buildWheelScrollViewSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Basic ListView
  // ===========================================================================

  Widget _buildBasicListViewSection() {
    return TomColumn(
      children: [
        // TomListView basic
        _DemoCard(
          tomId: 'demo15.listview',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Static list demo
              TomText(
                tomId: 'demo15.listview.staticLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const TomSizedBox(height: 12),
              TomContainer(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: TomListView(
                  padding: const EdgeInsets.all(8),
                  children: List.generate(
                    10,
                    (index) => _ListTileItem(
                      title: 'Static Item ${index + 1}',
                      subtitle: 'ListView with children list',
                      leading: TomCircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: TomText(
                          text: '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(height: 24),

              // Builder pattern demo
              TomText(
                tomId: 'demo15.listview.builderLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const TomSizedBox(height: 12),
              TomContainer(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: TomListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: 50,
                  itemBuilder: (context, index) => _ListTileItem(
                    title: 'Builder Item ${index + 1}',
                    subtitle: 'Lazily built on demand',
                    leading: TomIcon(
                      icon: Icons.star,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
              const TomSizedBox(height: 24),

              // Separated list demo
              TomText(
                tomId: 'demo15.listview.separatedLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const TomSizedBox(height: 12),
              TomContainer(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: TomListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: 20,
                  separatorBuilder: (context, index) => const TomDivider(
                    indent: 56,
                  ),
                  itemBuilder: (context, index) => TomListTile(
                    leading: TomCircleAvatar(
                      backgroundColor: Colors.primaries[index % 18],
                      child: TomText(
                        text: String.fromCharCode(65 + index),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    titleText: 'Contact ${index + 1}',
                    subtitle: const TomText(text: 'Separated with dividers'),
                    trailing: const TomIcon(icon: Icons.chevron_right),
                  ),
                ),
              ),
              const TomSizedBox(height: 24),

              // Horizontal list demo
              TomText(
                tomId: 'demo15.listview.horizontalLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const TomSizedBox(height: 12),
              TomSizedBox(
                height: 120,
                child: TomListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: 20,
                  itemBuilder: (context, index) => TomPadding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TomCard(
                      child: TomSizedBox(
                        width: 100,
                        child: TomColumn(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TomCircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  Colors.primaries[index % 18].shade300,
                              child: TomIcon(
                                icon: Icons.image,
                                color: Colors.white,
                              ),
                            ),
                            const TomSizedBox(height: 8),
                            TomText(
                              text: 'Card ${index + 1}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: Animated Lists
  // ===========================================================================

  Widget _buildAnimatedListSection() {
    return _DemoCard(
      tomId: 'demo15.animatedList',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo15.animatedList.description',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 16),

          // Control buttons
          TomWrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                tomId: 'demo15.animatedList.add',
                onPressed: _addAnimatedItem,
              ),
              TomOutlinedButton(
                tomId: 'demo15.animatedList.removeFirst',
                onPressed:
                    _animatedItems.isNotEmpty ? _removeFirstAnimatedItem : null,
              ),
              TomOutlinedButton(
                tomId: 'demo15.animatedList.removeLast',
                onPressed:
                    _animatedItems.isNotEmpty ? _removeLastAnimatedItem : null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Animated list
          TomContainer(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomAnimatedList(
              key: _animatedListKey,
              initialItemCount: _animatedItems.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index, animation) {
                return SlideTransition(
                  position: animation.drive(
                    Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: _AnimatedListItem(
                      title: _animatedItems[index],
                      onRemove: () => _removeAnimatedItemAt(index),
                    ),
                  ),
                );
              },
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo15.animatedList.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _addAnimatedItem() {
    _animatedItemCounter++;
    final newItem = 'Item $_animatedItemCounter';
    _animatedItems.add(newItem);
    _animatedListKey.currentState?.insertItem(_animatedItems.length - 1);
  }

  void _removeFirstAnimatedItem() {
    if (_animatedItems.isNotEmpty) {
      _removeAnimatedItemAt(0);
    }
  }

  void _removeLastAnimatedItem() {
    if (_animatedItems.isNotEmpty) {
      _removeAnimatedItemAt(_animatedItems.length - 1);
    }
  }

  void _removeAnimatedItemAt(int index) {
    if (index < 0 || index >= _animatedItems.length) return;

    final removedItem = _animatedItems[index];
    _animatedItems.removeAt(index);

    _animatedListKey.currentState?.removeItem(
      index,
      (context, animation) => SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInCubic)),
        ),
        child: FadeTransition(
          opacity: animation,
          child: _AnimatedListItem(
            title: removedItem,
            onRemove: () {},
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  // ===========================================================================
  // Section 3: Reorderable List
  // ===========================================================================

  Widget _buildReorderableSection() {
    return _DemoCard(
      tomId: 'demo15.reorderable',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo15.reorderable.description',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 16),

          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomReorderableListView(
              padding: const EdgeInsets.all(8),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _reorderableItems.removeAt(oldIndex);
                  _reorderableItems.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _reorderableItems.length; i++)
                  TomCard(
                    key: ValueKey(_reorderableItems[i]),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: TomListTile(
                      leading: TomCircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: TomText(
                          text: '${i + 1}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      titleText: _reorderableItems[i],
                      subtitle:
                          const TomText(text: 'Long press and drag to reorder'),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: TomIcon(
                          icon: Icons.drag_handle,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo15.reorderable.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3b: Dismissible List
  // ===========================================================================

  Widget _buildDismissibleSection() {
    return _DemoCard(
      tomId: 'demo15.dismissible',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo15.dismissible.description',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 16),

          // Reset button
          TomOutlinedButton(
            tomId: 'demo15.dismissible.reset',
            onPressed: () {
              setState(() {
                _dismissibleItems.clear();
                _dismissibleItems.addAll([
                  'Swipe to dismiss 1',
                  'Swipe to dismiss 2',
                  'Swipe to dismiss 3',
                  'Swipe to dismiss 4',
                  'Swipe to dismiss 5',
                ]);
              });
            },
          ),
          const TomSizedBox(height: 16),

          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _dismissibleItems.isEmpty
                ? Center(
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TomIcon(
                          icon: Icons.check_circle_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const TomSizedBox(height: 16),
                        TomText(
                          tomId: 'demo15.dismissible.empty',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : TomListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _dismissibleItems.length,
                    itemBuilder: (context, index) {
                      final item = _dismissibleItems[index];
                      return TomDismissible(
                        tomId: 'demo15.dismissible.$index',
                        direction: DismissDirection.horizontal,
                        background: TomContainer(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const TomIcon(
                            icon: Icons.archive,
                            color: Colors.white,
                          ),
                        ),
                        secondaryBackground: TomContainer(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const TomIcon(
                            icon: Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          setState(() {
                            _dismissibleItems.removeAt(index);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                direction == DismissDirection.startToEnd
                                    ? 'Archived: $item'
                                    : 'Deleted: $item',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: TomCard(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: TomListTile(
                            leading: TomCircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondaryContainer,
                              child: TomIcon(
                                icon: Icons.mail,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                            titleText: item,
                            subtitle: const TomText(
                              text: 'Swipe left to delete, right to archive',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo15.dismissible.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Wheel Scroll View
  // ===========================================================================

  Widget _buildWheelScrollViewSection() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return _DemoCard(
      tomId: 'demo15.wheel',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo15.wheel.description',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const TomSizedBox(height: 24),

          // Side by side wheel pickers
          TomRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Standard wheel
              TomExpanded(
                child: TomColumn(
                  children: [
                    TomText(
                      tomId: 'demo15.wheel.standard',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const TomSizedBox(height: 8),
                    TomContainer(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TomListWheelScrollView(
                        itemExtent: 40,
                        diameterRatio: 1.5,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedWheelItem = index;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: months.length,
                          builder: (context, index) {
                            final isSelected = index == _selectedWheelItem;
                            return Center(
                              child: TomText(
                                text: months[index],
                                style: TextStyle(
                                  fontSize: isSelected ? 18 : 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const TomSizedBox(width: 16),

              // Magnified wheel
              TomExpanded(
                child: TomColumn(
                  children: [
                    TomText(
                      tomId: 'demo15.wheel.magnified',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const TomSizedBox(height: 8),
                    TomContainer(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TomListWheelScrollView(
                        itemExtent: 40,
                        diameterRatio: 2.0,
                        useMagnifier: true,
                        magnification: 1.3,
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 24,
                          builder: (context, index) {
                            return Center(
                              child: TomText(
                                text: index.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 20),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const TomSizedBox(height: 4),
                    TomText(
                      text: 'Hour selector',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Selected month display
          TomContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TomIcon(
                  icon: Icons.calendar_month,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const TomSizedBox(width: 8),
                TomText(
                  text: 'Selected: ${months[_selectedWheelItem]}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 24),

          // Custom styled wheel
          TomText(
            tomId: 'demo15.wheel.customLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomListWheelScrollView(
              itemExtent: 60,
              diameterRatio: 1.2,
              perspective: 0.003,
              squeeze: 1.2,
              overAndUnderCenterOpacity: 0.5,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 100,
                builder: (context, index) {
                  return Center(
                    child: TomContainer(
                      width: 200,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.primaries[index % 18].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.primaries[index % 18],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TomText(
                        text: 'Option ${index + 1}',
                        style: TextStyle(
                          color: Colors.primaries[index % 18].shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Simple list tile item for basic demos.
class _ListTileItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading;

  const _ListTileItem({
    required this.title,
    required this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return TomCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: TomListTile(
        leading: leading,
        titleText: title,
        subtitle: TomText(text: subtitle),
      ),
    );
  }
}

/// Animated list item with remove button.
class _AnimatedListItem extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;

  const _AnimatedListItem({
    required this.title,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return TomCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: TomListTile(
        leading: TomCircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: TomIcon(
            icon: Icons.animation,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        titleText: title,
        subtitle: const TomText(text: 'Animated entry/exit'),
        trailing: TomIconButton(
          tooltip: 'Remove item',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// =============================================================================
// Section Header & Demo Card (Local Helpers)
// =============================================================================

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
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomIcon(tomId: '$tomId.icon'),
                const TomSizedBox(width: 12),
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
            const TomSizedBox(height: 8),
            // Description
            TomText(
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
