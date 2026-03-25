/// Comprehensive Navigation Widgets Demo
///
/// This demo showcases AppBar, NavigationBar, NavigationRail,
/// Drawer, TabBar, and various navigation patterns.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main navigation demo screen.
class NavigationDemo extends StatelessWidget {
  const NavigationDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'AppBar',
          subtitle: 'Top app bar variations',
        ),
        _AppBarSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'NavigationBar',
          subtitle: 'Bottom navigation (Material 3)',
        ),
        _NavigationBarSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'NavigationRail',
          subtitle: 'Side navigation for larger screens',
        ),
        _NavigationRailSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TabBar',
          subtitle: 'Tab-based navigation',
        ),
        _TabBarSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Drawer',
          subtitle: 'Navigation drawer patterns',
        ),
        _DrawerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Breadcrumbs',
          subtitle: 'Navigation path indicators',
        ),
        _BreadcrumbSection(),
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
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
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
// AppBar Section
// =============================================================================

class _AppBarSection extends StatelessWidget {
  const _AppBarSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic AppBar',
          'Simple app bar with title.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TomSizedBox(
              height: 56,
              child: AppBar(
                title: const Text('App Title'),
                automaticallyImplyLeading: false,
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'AppBar with Actions',
          'Title with action buttons.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TomSizedBox(
              height: 56,
              child: AppBar(
                leading: IconButton(
                  icon: const TomIcon(Icons.menu),
                  onPressed: () {},
                ),
                title: const Text('App Title'),
                actions: [
                  IconButton(icon: const TomIcon(Icons.search), onPressed: () {}),
                  IconButton(icon: const TomIcon(Icons.more_vert), onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Centered Title',
          'AppBar with centered title.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TomSizedBox(
              height: 56,
              child: AppBar(
                leading: IconButton(
                  icon: const TomIcon(Icons.arrow_back),
                  onPressed: () {},
                ),
                title: const Text('Centered'),
                centerTitle: true,
                actions: [
                  IconButton(icon: const TomIcon(Icons.share), onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'ColorScheme Variants',
          'Different color schemes.',
          TomColumn(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TomSizedBox(
                  height: 48,
                  child: AppBar(
                    title: const Text('Primary'),
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TomSizedBox(
                  height: 48,
                  child: AppBar(
                    title: const Text('Secondary'),
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
              const TomSizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TomSizedBox(
                  height: 48,
                  child: AppBar(
                    title: const Text('Surface'),
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Search AppBar',
          'AppBar with search field.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TomSizedBox(
              height: 56,
              child: AppBar(
                leading: IconButton(
                  icon: const TomIcon(Icons.arrow_back),
                  onPressed: () {},
                ),
                title: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                  ),
                ),
                actions: [
                  IconButton(icon: const TomIcon(Icons.close), onPressed: () {}),
                ],
              ),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// NavigationBar Section
// =============================================================================

class _NavigationBarSection extends StatefulWidget {
  const _NavigationBarSection();

  @override
  State<_NavigationBarSection> createState() => _NavigationBarSectionState();
}

class _NavigationBarSectionState extends State<_NavigationBarSection> {
  int _selectedIndex = 0;
  int _selectedIndex2 = 0;

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic NavigationBar',
          'Standard bottom navigation.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: TomIcon(Icons.home_outlined),
                  selectedIcon: TomIcon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: TomIcon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: TomIcon(Icons.person_outline),
                  selectedIcon: TomIcon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'With Badges',
          'Navigation items with notification badges.',
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NavigationBar(
              selectedIndex: _selectedIndex2,
              onDestinationSelected: (i) => setState(() => _selectedIndex2 = i),
              destinations: [
                const NavigationDestination(
                  icon: TomIcon(Icons.home_outlined),
                  selectedIcon: TomIcon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    label: const Text('3'),
                    child: const TomIcon(Icons.notifications_outlined),
                  ),
                  selectedIcon: Badge(
                    label: const Text('3'),
                    child: const TomIcon(Icons.notifications),
                  ),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Badge.count(
                    count: 12,
                    child: const TomIcon(Icons.message_outlined),
                  ),
                  selectedIcon: Badge.count(
                    count: 12,
                    child: const TomIcon(Icons.message),
                  ),
                  label: 'Messages',
                ),
                const NavigationDestination(
                  icon: TomIcon(Icons.settings_outlined),
                  selectedIcon: TomIcon(Icons.settings),
                  label: 'Settings',
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
// NavigationRail Section
// =============================================================================

class _NavigationRailSection extends StatefulWidget {
  const _NavigationRailSection();

  @override
  State<_NavigationRailSection> createState() => _NavigationRailSectionState();
}

class _NavigationRailSectionState extends State<_NavigationRailSection> {
  int _selectedIndex = 0;
  bool _extended = false;

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                const Text(
                  'NavigationRail',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const TomSpacer(),
                const Text('Extended:', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _extended,
                  onChanged: (v) => setState(() => _extended = v),
                ),
              ],
            ),
            const TomSizedBox(height: 12),
            TomSizedBox(
              height: 300,
              child: TomRow(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _selectedIndex = i),
                    extended: _extended,
                    leading: FloatingActionButton(
                      mini: true,
                      onPressed: () {},
                      child: const TomIcon(Icons.add),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: TomIcon(Icons.inbox_outlined),
                        selectedIcon: TomIcon(Icons.inbox),
                        label: Text('Inbox'),
                      ),
                      NavigationRailDestination(
                        icon: TomIcon(Icons.send_outlined),
                        selectedIcon: TomIcon(Icons.send),
                        label: Text('Sent'),
                      ),
                      NavigationRailDestination(
                        icon: TomIcon(Icons.drafts_outlined),
                        selectedIcon: TomIcon(Icons.drafts),
                        label: Text('Drafts'),
                      ),
                      NavigationRailDestination(
                        icon: TomIcon(Icons.delete_outline),
                        selectedIcon: TomIcon(Icons.delete),
                        label: Text('Trash'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  TomExpanded(
                    child: TomContainer(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: TomCenter(
                        child: Text(
                          ['Inbox', 'Sent', 'Drafts', 'Trash'][_selectedIndex],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TabBar Section
// =============================================================================

class _TabBarSection extends StatelessWidget {
  const _TabBarSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        const _BasicTabDemo(),
        const _ScrollableTabDemo(),
        const _IconTabDemo(),
      ],
    );
  }
}

class _BasicTabDemo extends StatefulWidget {
  const _BasicTabDemo();

  @override
  State<_BasicTabDemo> createState() => _BasicTabDemoState();
}

class _BasicTabDemoState extends State<_BasicTabDemo>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic TabBar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 12),
            TabBar(
              controller: _controller,
              tabs: const [
                Tab(text: 'Tab 1'),
                Tab(text: 'Tab 2'),
                Tab(text: 'Tab 3'),
              ],
            ),
            TomSizedBox(
              height: 100,
              child: TabBarView(
                controller: _controller,
                children: [
                  TomCenter(child: Text('Content 1')),
                  TomCenter(child: Text('Content 2')),
                  TomCenter(child: Text('Content 3')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableTabDemo extends StatefulWidget {
  const _ScrollableTabDemo();

  @override
  State<_ScrollableTabDemo> createState() => _ScrollableTabDemoState();
}

class _ScrollableTabDemoState extends State<_ScrollableTabDemo>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scrollable TabBar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 12),
            TabBar(
              controller: _controller,
              isScrollable: true,
              tabs: List.generate(
                8,
                (i) => Tab(text: 'Category ${i + 1}'),
              ),
            ),
            TomSizedBox(
              height: 80,
              child: TabBarView(
                controller: _controller,
                children: List.generate(
                  8,
                  (i) => TomCenter(child: Text('Category ${i + 1} Content')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTabDemo extends StatefulWidget {
  const _IconTabDemo();

  @override
  State<_IconTabDemo> createState() => _IconTabDemoState();
}

class _IconTabDemoState extends State<_IconTabDemo>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Icon Tabs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 12),
            TabBar(
              controller: _controller,
              tabs: const [
                Tab(icon: TomIcon(Icons.photo), text: 'Photos'),
                Tab(icon: TomIcon(Icons.video_library), text: 'Videos'),
                Tab(icon: TomIcon(Icons.music_note), text: 'Music'),
                Tab(icon: TomIcon(Icons.folder), text: 'Files'),
              ],
            ),
            TomSizedBox(
              height: 80,
              child: TabBarView(
                controller: _controller,
                children: [
                  TomCenter(child: Text('Photos')),
                  TomCenter(child: Text('Videos')),
                  TomCenter(child: Text('Music')),
                  TomCenter(child: Text('Files')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Drawer Section
// =============================================================================

class _DrawerSection extends StatelessWidget {
  const _DrawerSection();

  @override
  Widget build(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drawer Preview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 12),
            TomContainer(
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TomRow(
                  children: [
                    TomSizedBox(
                      width: 240,
                      child: Drawer(
                        child: TomListView(
                          padding: EdgeInsets.zero,
                          children: [
                            DrawerHeader(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: TomColumn(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const CircleAvatar(
                                    radius: 32,
                                    child: TomIcon(Icons.person, size: 32),
                                  ),
                                  const TomSizedBox(height: 8),
                                  Text(
                                    'John Doe',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'john@example.com',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const ListTile(
                              leading: TomIcon(Icons.home),
                              title: Text('Home'),
                              selected: true,
                            ),
                            const ListTile(
                              leading: TomIcon(Icons.favorite),
                              title: Text('Favorites'),
                            ),
                            const ListTile(
                              leading: TomIcon(Icons.settings),
                              title: Text('Settings'),
                            ),
                            const TomDivider(),
                            const ListTile(
                              leading: TomIcon(Icons.help),
                              title: Text('Help'),
                            ),
                            const ListTile(
                              leading: TomIcon(Icons.logout),
                              title: Text('Logout'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TomExpanded(
                      child: TomContainer(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const TomCenter(
                          child: Text('Main Content Area'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Breadcrumb Section
// =============================================================================

class _BreadcrumbSection extends StatelessWidget {
  const _BreadcrumbSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Simple Breadcrumbs',
          'Text-based navigation path.',
          TomRow(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Home'),
              ),
              const TomIcon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: () {},
                child: const Text('Products'),
              ),
              const TomIcon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: () {},
                child: const Text('Electronics'),
              ),
              const TomIcon(Icons.chevron_right, size: 16),
              const Text(
                'Phones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Icon Breadcrumbs',
          'Navigation path with icons.',
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: TomRow(
              children: [
                _breadcrumbItem(Icons.home, 'Home', true),
                const TomIcon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                _breadcrumbItem(Icons.folder, 'Documents', true),
                const TomIcon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                _breadcrumbItem(Icons.folder, 'Projects', true),
                const TomIcon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                _breadcrumbItem(Icons.description, 'Report.pdf', false),
              ],
            ),
          ),
        ),
        _buildDemoCard(
          'Chip Breadcrumbs',
          'Navigation path as chips.',
          TomWrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(label: const Text('Home'), onPressed: () {}),
              const TomIcon(Icons.chevron_right, size: 16),
              ActionChip(label: const Text('Category'), onPressed: () {}),
              const TomIcon(Icons.chevron_right, size: 16),
              ActionChip(label: const Text('Subcategory'), onPressed: () {}),
              const TomIcon(Icons.chevron_right, size: 16),
              const Chip(label: Text('Current')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _breadcrumbItem(IconData icon, String label, bool clickable) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TomRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          TomIcon(icon, size: 16, color: clickable ? Colors.blue : Colors.grey),
          const TomSizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: clickable ? Colors.blue : Colors.black,
              fontWeight: clickable ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            Text(
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
