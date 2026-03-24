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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDemoCard(
          'Floating AppBar',
          'Appears when scrolling up.',
          SizedBox(
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
                    (context, index) => ListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDemoCard(
          'Pinned AppBar',
          'Stays at top when scrolling.',
          SizedBox(
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
                    (context, index) => ListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDemoCard(
          'Expandable AppBar',
          'Expands with flexible space.',
          SizedBox(
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
                    background: Container(
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
                    (context, index) => ListTile(title: Text('Item $index')),
                    childCount: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDemoCard(
          'Snap AppBar',
          'Snaps to expanded/collapsed.',
          SizedBox(
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
                    (context, index) => ListTile(title: Text('Item $index')),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
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
              (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
              (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.star, color: Colors.amber.shade600),
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
            prototypeItem: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Prototype'),
                subtitle: const Text('Size template'),
              ),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.brightness_1, color: Colors.primaries[index % Colors.primaries.length]),
                  title: Text('Prototype Item ${index + 1}'),
                  subtitle: const Text('Sized by prototype'),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 48),
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
              (context, index) => Card(
                color: Colors.primaries[index % Colors.primaries.length].shade100,
                child: Center(
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
              (context, index) => Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 32,
                      color: Colors.primaries[index % Colors.primaries.length],
                    ),
                    const SizedBox(height: 4),
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
              (index) => Card(
                color: Colors.teal.shade50,
                child: Center(
                  child: Icon(
                    _icons[index % _icons.length],
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 48),
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
          child: Container(
            height: 150,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard, size: 48, color: Colors.white),
                  SizedBox(height: 8),
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
              (context, index) => Card(
                color: Colors.amber.shade50,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade700),
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
              (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.check, color: Colors.green.shade700),
                  ),
                  title: Text('Recent Item ${index + 1}'),
                  subtitle: const Text('Added recently'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
        // Fill remaining space
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
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
        const SizedBox(height: 12),
      ],
    );
  }
}
