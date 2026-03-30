/// Demo 17: Sliver Compositions
///
/// Comprehensive demonstration of all Tom sliver and CustomScrollView widgets.
/// Widgets covered: TomCustomScrollView, TomSliverAppBar, TomSliverList,
/// TomSliverGrid, TomSliverToBoxAdapter, TomSliverFillRemaining,
/// TomPinnedHeaderSliver, TomSliverFloatingHeader, TomSliverMainAxisGroup,
/// TomSliverCrossAxisGroup, TomDecoratedSliver, TomSliverPadding,
/// TomSliverFixedExtentList, TomSliverPrototypeExtentList,
/// TomSliverVariedExtentList, TomSliverFillViewport, TomSliverSafeArea,
/// TomSliverVisibility.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Sliver Compositions demo.
class SliversDemo extends StatelessWidget {
  const SliversDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SliversDemoContent();
  }
}

class _SliversDemoContent extends StatefulWidget {
  const _SliversDemoContent();

  @override
  State<_SliversDemoContent> createState() => _SliversDemoContentState();
}

class _SliversDemoContentState extends State<_SliversDemoContent>
    with TickerProviderStateMixin {
  // Scroll controllers
  final ScrollController _basicScrollController = ScrollController();
  final ScrollController _pinnedScrollController = ScrollController();
  final ScrollController _floatingScrollController = ScrollController();
  final ScrollController _snapScrollController = ScrollController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();
  final ScrollController _mixedScrollController = ScrollController();
  final ScrollController _fillRemainingController = ScrollController();
  final ScrollController _headersController = ScrollController();
  final ScrollController _groupsController = ScrollController();
  final ScrollController _decoratedController = ScrollController();

  // Sliver visibility states
  bool _isSliver1Visible = true;
  bool _isSliver2Visible = true;

  @override
  void dispose() {
    _basicScrollController.dispose();
    _pinnedScrollController.dispose();
    _floatingScrollController.dispose();
    _snapScrollController.dispose();
    _listScrollController.dispose();
    _gridScrollController.dispose();
    _mixedScrollController.dispose();
    _fillRemainingController.dispose();
    _headersController.dispose();
    _groupsController.dispose();
    _decoratedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: CustomScrollView Basics
            _SectionHeader(tomId: 'demo17.section.customScroll'),
            const TomSizedBox(height: 16),
            _buildCustomScrollViewSection(),
            const TomSizedBox(height: 32),

            // Section 2: SliverAppBar Styles
            _SectionHeader(tomId: 'demo17.section.appBar'),
            const TomSizedBox(height: 16),
            _buildSliverAppBarPinnedSection(),
            const TomSizedBox(height: 24),
            _buildSliverAppBarFloatingSection(),
            const TomSizedBox(height: 24),
            _buildSliverAppBarSnapSection(),
            const TomSizedBox(height: 32),

            // Section 3: SliverList and SliverGrid
            _SectionHeader(tomId: 'demo17.section.listGrid'),
            const TomSizedBox(height: 16),
            _buildSliverListSection(),
            const TomSizedBox(height: 24),
            _buildSliverGridSection(),
            const TomSizedBox(height: 32),

            // Section 4: Mixed Content
            _SectionHeader(tomId: 'demo17.section.mixed'),
            const TomSizedBox(height: 16),
            _buildMixedContentSection(),
            const TomSizedBox(height: 24),
            _buildFillRemainingSection(),
            const TomSizedBox(height: 32),

            // Section 5: Pinned & Floating Headers
            _SectionHeader(tomId: 'demo17.section.headers'),
            const TomSizedBox(height: 16),
            _buildPinnedFloatingHeadersSection(),
            const TomSizedBox(height: 32),

            // Section 6: Sliver Groups
            _SectionHeader(tomId: 'demo17.section.groups'),
            const TomSizedBox(height: 16),
            _buildSliverGroupsSection(),
            const TomSizedBox(height: 32),

            // Section 7: Decorated Slivers
            _SectionHeader(tomId: 'demo17.section.decorated'),
            const TomSizedBox(height: 16),
            _buildDecoratedSliversSection(),
            const TomSizedBox(height: 32),

            // Section 8: Sliver Visibility
            _SectionHeader(tomId: 'demo17.section.visibility'),
            const TomSizedBox(height: 16),
            _buildSliverVisibilitySection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: CustomScrollView Basics
  // ===========================================================================

  Widget _buildCustomScrollViewSection() {
    return _DemoCard(
      tomId: 'demo17.customScroll',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.customScroll.basicLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _basicScrollController,
              slivers: [
                // Basic SliverAppBar
                TomSliverAppBar(
                  titleText: 'Basic CustomScrollView',
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  expandedHeight: 80,
                ),
                // Basic list content
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(
                      leading: TomContainer(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1 + index * 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: TomText(text: '${index + 1}'),
                        ),
                      ),
                      titleText: 'List Item ${index + 1}',
                      subtitle: const Text('Basic sliver list item'),
                    ),
                    childCount: 10,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.customScroll.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: SliverAppBar Styles
  // ===========================================================================

  Widget _buildSliverAppBarPinnedSection() {
    return _DemoCard(
      tomId: 'demo17.pinnedAppBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.pinnedAppBar.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _pinnedScrollController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Pinned AppBar',
                  pinned: true,
                  expandedHeight: 120,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      titleText: 'Item ${index + 1}',
                      subtitle: const Text('Scroll up to see pinned behavior'),
                    ),
                    childCount: 15,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.pinnedAppBar.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBarFloatingSection() {
    return _DemoCard(
      tomId: 'demo17.floatingAppBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.floatingAppBar.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _floatingScrollController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Floating AppBar',
                  floating: true,
                  expandedHeight: 100,
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                  leading: const Icon(Icons.menu),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {},
                    ),
                  ],
                ),
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(
                      leading: Icon(
                        Icons.article,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      titleText: 'Article ${index + 1}',
                      subtitle: const Text('Scroll down then up quickly'),
                    ),
                    childCount: 15,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.floatingAppBar.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBarSnapSection() {
    return _DemoCard(
      tomId: 'demo17.snapAppBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.snapAppBar.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _snapScrollController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Snap AppBar',
                  floating: true,
                  snap: true,
                  expandedHeight: 120,
                  stretch: true,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Container(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Center(
                        child: Icon(Icons.expand, size: 48),
                      ),
                    ),
                  ),
                ),
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(
                      leading: Icon(
                        Icons.touch_app,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      titleText: 'Snap Item ${index + 1}',
                      subtitle: const Text('Partially scroll - watch it snap'),
                    ),
                    childCount: 15,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.snapAppBar.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: SliverList and SliverGrid
  // ===========================================================================

  Widget _buildSliverListSection() {
    return _DemoCard(
      tomId: 'demo17.sliverList',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.sliverList.typesLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _listScrollController,
              slivers: [
                // Regular SliverList
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Text(
                      'Regular SliverList',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TomSliverList(
                  delegate: SliverChildListDelegate([
                    ListTile(
                      leading: const Icon(Icons.looks_one),
                      title: const Text('Static Item 1'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: const Icon(Icons.looks_two),
                      title: const Text('Static Item 2'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                    ),
                    ListTile(
                      leading: const Icon(Icons.looks_3),
                      title: const Text('Static Item 3'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                    ),
                  ]),
                ),

                // Fixed extent list
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Text(
                      'SliverFixedExtentList (50px each)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TomSliverFixedExtentList(
                  itemExtent: 50,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      color: index.isEven
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.5),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Fixed Height Item ${index + 1}'),
                    ),
                    childCount: 5,
                  ),
                ),

                // Prototype extent list
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Text(
                      'SliverPrototypeExtentList',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TomSliverPrototypeExtentList(
                  prototypeItem: const ListTile(
                    title: Text('Prototype'),
                    subtitle: Text('Height'),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.tertiaryContainer,
                        child: Text('${index + 1}'),
                      ),
                      title: Text('Prototype Item ${index + 1}'),
                      subtitle: const Text('Same height as prototype'),
                    ),
                    childCount: 5,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.sliverList.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverGridSection() {
    return _DemoCard(
      tomId: 'demo17.sliverGrid',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.sliverGrid.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _gridScrollController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Grid Gallery',
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
                  pinned: true,
                ),
                TomSliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: TomSliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => TomContainer(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.primaries[index % Colors.primaries.length],
                              Colors.primaries[
                                  (index + 5) % Colors.primaries.length],
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      childCount: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.sliverGrid.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Mixed Content
  // ===========================================================================

  Widget _buildMixedContentSection() {
    return _DemoCard(
      tomId: 'demo17.mixedContent',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.mixedContent.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _mixedScrollController,
              slivers: [
                // Hero section using SliverToBoxAdapter
                TomSliverToBoxAdapter(
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.dashboard,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats row
                TomSliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildStatCard('Users', '1,234', Icons.people),
                        const SizedBox(width: 12),
                        _buildStatCard('Sales', '\$5,678', Icons.attach_money),
                        const SizedBox(width: 12),
                        _buildStatCard('Orders', '89', Icons.shopping_cart),
                      ],
                    ),
                  ),
                ),

                // Section header
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),

                // Activity list
                TomSliverList(
                  delegate: SliverChildListDelegate([
                    _buildActivityTile('New user registered', Icons.person_add,
                        Colors.green, '2 min ago'),
                    _buildActivityTile('Order completed', Icons.check_circle,
                        Colors.blue, '5 min ago'),
                    _buildActivityTile('Payment received', Icons.payment,
                        Colors.orange, '12 min ago'),
                    _buildActivityTile('Product updated', Icons.edit,
                        Colors.purple, '1 hour ago'),
                  ]),
                ),

                // Grid section
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),

                TomSliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: TomSliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildQuickActionTile('Add User', Icons.person_add),
                      _buildQuickActionTile('New Order', Icons.add_shopping_cart),
                      _buildQuickActionTile('Reports', Icons.analytics),
                      _buildQuickActionTile('Settings', Icons.settings),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.mixedContent.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(
      String title, IconData icon, Color color, String time) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildQuickActionTile(String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillRemainingSection() {
    return _DemoCard(
      tomId: 'demo17.fillRemaining',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.fillRemaining.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _fillRemainingController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Fill Remaining Demo',
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                TomSliverList(
                  delegate: SliverChildListDelegate([
                    const ListTile(title: Text('Item 1')),
                    const ListTile(title: Text('Item 2')),
                  ]),
                ),
                TomSliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.3),
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.expand,
                            size: 48,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This fills remaining space',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Great for footers or empty states',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.fillRemaining.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: Pinned & Floating Headers
  // ===========================================================================

  Widget _buildPinnedFloatingHeadersSection() {
    return _DemoCard(
      tomId: 'demo17.pinnedFloating',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.pinnedFloating.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _headersController,
              slivers: [
                // Pinned header that stays at top
                TomPinnedHeaderSliver(
                  child: Container(
                    color: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Pinned Header - Always Visible',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // First section
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      title: Text('Section A - Item ${index + 1}'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.2),
                    ),
                    childCount: 5,
                  ),
                ),

                // Floating header - reappears when scrolling up
                TomSliverFloatingHeader(
                  child: Container(
                    color: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.vertical_align_top, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Floating Header - Scroll Up',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Second section
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      title: Text('Section B - Item ${index + 1}'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.2),
                    ),
                    childCount: 5,
                  ),
                ),

                // Another pinned header (persistent header style)
                TomSliverPersistentHeader(
                  pinned: true,
                  delegate: _PersistentHeaderDelegate(
                    minHeight: 48,
                    maxHeight: 80,
                    child: Container(
                      color: Theme.of(context).colorScheme.tertiary,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Persistent Header (resizable)',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Third section
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(
                      title: Text('Section C - Item ${index + 1}'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withValues(alpha: 0.2),
                    ),
                    childCount: 8,
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.pinnedFloating.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 6: Sliver Groups
  // ===========================================================================

  Widget _buildSliverGroupsSection() {
    return _DemoCard(
      tomId: 'demo17.groups',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.groups.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _groupsController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Sliver Groups',
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),

                // Main Axis Group - sequential slivers
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      'SliverMainAxisGroup (sequential)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),

                TomSliverMainAxisGroup(
                  slivers: [
                    TomSliverPersistentHeader(
                      pinned: true,
                      delegate: _PersistentHeaderDelegate(
                        minHeight: 40,
                        maxHeight: 40,
                        child: Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text('Group A Header'),
                        ),
                      ),
                    ),
                    TomSliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ListTile(
                          dense: true,
                          title: Text('Group A Item ${index + 1}'),
                        ),
                        childCount: 3,
                      ),
                    ),
                  ],
                ),

                TomSliverMainAxisGroup(
                  slivers: [
                    TomSliverPersistentHeader(
                      pinned: true,
                      delegate: _PersistentHeaderDelegate(
                        minHeight: 40,
                        maxHeight: 40,
                        child: Container(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text('Group B Header'),
                        ),
                      ),
                    ),
                    TomSliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ListTile(
                          dense: true,
                          title: Text('Group B Item ${index + 1}'),
                        ),
                        childCount: 3,
                      ),
                    ),
                  ],
                ),

                // Cross Axis Group - side by side
                TomSliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      'SliverCrossAxisGroup (side-by-side)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),

                TomSliverCrossAxisGroup(
                  slivers: [
                    TomSliverCrossAxisExpanded(
                      flex: 1,
                      sliver: TomSliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Container(
                            height: 50,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text('Left ${index + 1}'),
                          ),
                          childCount: 5,
                        ),
                      ),
                    ),
                    TomSliverConstrainedCrossAxis(
                      maxExtent: 100,
                      sliver: TomSliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Container(
                            height: 50,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text('R${index + 1}'),
                          ),
                          childCount: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.groups.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 7: Decorated Slivers
  // ===========================================================================

  Widget _buildDecoratedSliversSection() {
    return _DemoCard(
      tomId: 'demo17.decorated',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.decorated.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              controller: _decoratedController,
              slivers: [
                TomSliverAppBar(
                  titleText: 'Decorated Slivers',
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),

                // Padded sliver
                TomSliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'SliverPadding with decoration',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),

                TomSliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: TomDecoratedSliver(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    sliver: TomSliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ListTile(
                          leading: Icon(
                            Icons.star,
                            color: Colors.amber.shade700,
                          ),
                          title: Text('Decorated Item ${index + 1}'),
                          subtitle: const Text('With gradient background'),
                        ),
                        childCount: 4,
                      ),
                    ),
                  ),
                ),

                // Another decorated section
                TomSliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: TomDecoratedSliver(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.tertiary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    sliver: TomSliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ListTile(
                          leading: Icon(
                            Icons.verified,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          title: Text('Bordered Item ${index + 1}'),
                          subtitle: const Text('With solid border'),
                        ),
                        childCount: 3,
                      ),
                    ),
                  ),
                ),

                // Safe area sliver
                TomSliverSafeArea(
                  minimum: const EdgeInsets.all(8),
                  sliver: TomSliverToBoxAdapter(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Safe Area Protected Content'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.decorated.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 8: Sliver Visibility
  // ===========================================================================

  Widget _buildSliverVisibilitySection() {
    return _DemoCard(
      tomId: 'demo17.visibility',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo17.visibility.demoLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const TomSizedBox(height: 12),

          // Controls
          TomRow(
            children: [
              TomExpanded(
                child: TomSwitchListTile(
                  value: _isSliver1Visible,
                  onChanged: (v) => setState(() => _isSliver1Visible = v),
                  titleText: 'Show Sliver 1',
                  dense: true,
                ),
              ),
              TomExpanded(
                child: TomSwitchListTile(
                  value: _isSliver2Visible,
                  onChanged: (v) => setState(() => _isSliver2Visible = v),
                  titleText: 'Show Sliver 2',
                  dense: true,
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 12),

          TomContainer(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCustomScrollView(
              slivers: [
                TomSliverAppBar(
                  titleText: 'Visibility Demo',
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),

                // Visible sliver 1
                TomSliverVisibility(
                  visible: _isSliver1Visible,
                  sliver: TomSliverToBoxAdapter(
                    child: Container(
                      height: 80,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.looks_one,
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sliver 1 - Toggleable',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Visible sliver 2
                TomSliverVisibility(
                  visible: _isSliver2Visible,
                  maintainState: true,
                  sliver: TomSliverToBoxAdapter(
                    child: Container(
                      height: 80,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.looks_two,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sliver 2 - Maintains state',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Opacity sliver
                TomSliverOpacity(
                  opacity: 0.5,
                  sliver: TomSliverToBoxAdapter(
                    child: Container(
                      height: 60,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      alignment: Alignment.center,
                      child: const Text('50% Opacity Sliver'),
                    ),
                  ),
                ),

                // Always visible
                TomSliverToBoxAdapter(
                  child: Container(
                    height: 60,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('Always Visible Footer'),
                  ),
                ),
              ],
            ),
          ),
          const TomSizedBox(height: 12),
          TomText(
            tomId: 'demo17.visibility.hint',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Classes
// =============================================================================

/// Simple persistent header delegate for demo purposes.
class _PersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _PersistentHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PersistentHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
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
