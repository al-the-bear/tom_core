/// Comprehensive Slivers Demo
///
/// This demo showcases SliverList, SliverGrid, SliverAppBar,
/// CustomScrollView, and various sliver patterns.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main slivers demo screen.
class SliversDemo extends StatelessWidget {
  const SliversDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: false,
              automaticallyImplyLeading: false,
              title: const Text('Slivers Demo'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'App Bar'),
                  Tab(text: 'Lists'),
                  Tab(text: 'Grids'),
                  Tab(text: 'Combined'),
                ],
              ),
            ),
          ],
          body: const TabBarView(
            children: [
              _SliverAppBarTab(),
              _SliverListTab(),
              _SliverGridTab(),
              _CombinedSliversTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SliverAppBar Tab
// =============================================================================

class _SliverAppBarTab extends StatelessWidget {
  const _SliverAppBarTab();

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDemoCard(
          'Floating AppBar',
          'Appears when scrolling up.',
          TomSizedBox(
            height: 300,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.blue,
                  title: const Text('Floating'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const TomSizedBox(height: 16),
        _buildDemoCard(
          'Pinned AppBar',
          'Stays at top when scrolling.',
          TomSizedBox(
            height: 300,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.green,
                  title: const Text('Pinned'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const TomSizedBox(height: 16),
        _buildDemoCard(
          'Expandable AppBar',
          'Expands with flexible space.',
          TomSizedBox(
            height: 350,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 150,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.purple,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text('Expandable'),
                    background: TomContainer(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.purple.shade300,
                            Colors.purple.shade700,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const TomSizedBox(height: 16),
        _buildDemoCard(
          'Snap AppBar',
          'Snaps to expanded/collapsed.',
          TomSizedBox(
            height: 350,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  snap: true,
                  expandedHeight: 150,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.orange,
                  flexibleSpace: const FlexibleSpaceBar(
                    title: Text('Snap'),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TomListTile(title: Text('Item $index')),
                    childCount: 20,
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
      clipBehavior: Clip.antiAlias,
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomPadding(
            padding: const EdgeInsets.all(16),
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const TomSizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// =============================================================================
// SliverList Tab
// =============================================================================

class _SliverListTab extends StatelessWidget {
  const _SliverListTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverList',
              subtitle: 'Basic sliver list',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: TomListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('SliverList Item ${index + 1}'),
                  subtitle: const Text('Built with SliverChildBuilderDelegate'),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverFixedExtentList',
              subtitle: 'Fixed height items for performance',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverFixedExtentList(
            itemExtent: 72,
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: TomListTile(
                  leading: TomIcon(Icons.star, color: Colors.amber.shade600),
                  title: Text('Fixed Height Item ${index + 1}'),
                  subtitle: const Text('Exactly 72 pixels tall'),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverPrototypeExtentList',
              subtitle: 'Items sized by prototype',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverPrototypeExtentList(
            prototypeItem: TomCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: TomListTile(
                leading: const TomIcon(Icons.star),
                title: const Text('Prototype'),
                subtitle: const Text('Size template'),
              ),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: TomListTile(
                  leading: TomIcon(Icons.brightness_1, color: Colors.primaries[index % Colors.primaries.length]),
                  title: Text('Prototype Item ${index + 1}'),
                  subtitle: const Text('Sized by prototype'),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: TomSizedBox(height: 48),
        ),
      ],
    );
  }
}

// =============================================================================
// SliverGrid Tab
// =============================================================================

class _SliverGridTab extends StatelessWidget {
  const _SliverGridTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverGrid with Fixed Count',
              subtitle: 'Fixed number of columns',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                color: Colors.primaries[index % Colors.primaries.length].shade100,
                child: TomCenter(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              childCount: 9,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverGrid with Max Extent',
              subtitle: 'Maximum item width',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                child: TomColumn(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TomIcon(
                      Icons.image,
                      size: 32,
                      color: Colors.primaries[index % Colors.primaries.length],
                    ),
                    const TomSizedBox(height: 4),
                    Text('Item ${index + 1}'),
                  ],
                ),
              ),
              childCount: 12,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'SliverGrid.extent',
              subtitle: 'Convenience constructor',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.extent(
            maxCrossAxisExtent: 120,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(
              8,
              (index) => TomCard(
                color: Colors.teal.shade50,
                child: TomCenter(
                  child: TomIcon(
                    _icons[index % _icons.length],
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: TomSizedBox(height: 48),
        ),
      ],
    );
  }

  static const _icons = [
    Icons.home,
    Icons.star,
    Icons.favorite,
    Icons.settings,
    Icons.search,
    Icons.person,
    Icons.mail,
    Icons.notifications,
  ];
}

// =============================================================================
// Combined Slivers Tab
// =============================================================================

class _CombinedSliversTab extends StatelessWidget {
  const _CombinedSliversTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header section
        SliverToBoxAdapter(
          child: TomContainer(
            height: 150,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              ),
            ),
            child: const TomCenter(
              child: TomColumn(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TomIcon(Icons.dashboard, size: 48, color: Colors.white),
                  TomSizedBox(height: 8),
                  Text(
                    'Combined Slivers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Section header
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Featured',
              subtitle: 'Grid section',
            ),
          ),
        ),
        // Grid section
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                color: Colors.amber.shade50,
                child: TomCenter(
                  child: TomColumn(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TomIcon(Icons.star, color: Colors.amber.shade700),
                      Text('Featured ${index + 1}'),
                    ],
                  ),
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
        // Another section header
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recent Items',
              subtitle: 'List section',
            ),
          ),
        ),
        // List section
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => TomCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: TomListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: TomIcon(Icons.check, color: Colors.green.shade700),
                  ),
                  title: Text('Recent Item ${index + 1}'),
                  subtitle: const Text('Added recently'),
                  trailing: const TomIcon(Icons.chevron_right),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        // Fill remaining space
        SliverFillRemaining(
          hasScrollBody: false,
          child: TomContainer(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TomColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TomIcon(Icons.check_circle, size: 48, color: Colors.grey.shade400),
                const TomSizedBox(height: 8),
                Text(
                  'End of Content',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'SliverFillRemaining fills the space',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Section Header (copied for sliver compatibility)
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const TomSizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const TomSizedBox(height: 12),
      ],
    );
  }
}
