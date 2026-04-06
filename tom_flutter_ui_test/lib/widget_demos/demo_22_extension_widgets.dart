/// Demo 22: Extension-Based Widgets
///
/// Demonstrates Tom widgets that use the extension pattern — they extend
/// their Flutter counterpart directly (with TomWidgetMixin) rather than
/// wrapping it via composition. This ensures they pass `is` type checks
/// required by parent widgets like NavigationBar, Table, etc.
///
/// Widgets covered: TomAppBar, TomNavigationDestination,
/// TomNavigationDrawerDestination, TomTableCell,
/// TomCupertinoTabView, TomRefreshProgressIndicator.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Extension Widgets demo.
class ExtensionWidgetsDemo extends TomStatelessWidget {
  ExtensionWidgetsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ExtensionWidgetsDemoContent();
  }
}

class _ExtensionWidgetsDemoContent extends TomStatefulWidget {
  _ExtensionWidgetsDemoContent();

  @override
  State<_ExtensionWidgetsDemoContent> createState() =>
      _ExtensionWidgetsDemoContentState();
}

class _ExtensionWidgetsDemoContentState
    extends TomState<_ExtensionWidgetsDemoContent> {
  // Navigation state
  int _navBarIndex = 0;
  int _drawerIndex = 0;

  // Refresh state
  final List<String> _refreshItems =
      List.generate(5, (i) => 'Item ${i + 1}');

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: TomAppBar
            _SectionHeader(tomId: 'section.appbar'),
            TomSizedBox(height: 16),
            _buildAppBarSection(context),
            TomSizedBox(height: 32),

            // Section 2: TomNavigationDestination
            _SectionHeader(tomId: 'section.navDestination'),
            TomSizedBox(height: 16),
            _buildNavigationDestinationSection(context),
            TomSizedBox(height: 32),

            // Section 3: TomNavigationDrawerDestination
            _SectionHeader(tomId: 'section.drawerDestination'),
            TomSizedBox(height: 16),
            _buildNavigationDrawerDestinationSection(context),
            TomSizedBox(height: 32),

            // Section 4: TomTableCell
            _SectionHeader(tomId: 'section.tableCell'),
            TomSizedBox(height: 16),
            _buildTableCellSection(context),
            TomSizedBox(height: 32),

            // Section 5: TomRefreshProgressIndicator
            _SectionHeader(tomId: 'section.refreshProgress'),
            TomSizedBox(height: 16),
            _buildRefreshProgressSection(context),
            TomSizedBox(height: 32),

            // Section 6: TomCupertinoTabView
            _SectionHeader(tomId: 'section.cupertinoTabView'),
            TomSizedBox(height: 16),
            _buildCupertinoTabViewSection(context),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: TomAppBar
  // ===========================================================================

  Widget _buildAppBarSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic TomAppBar with titleText
        _DemoCard(
          tomId: 'demo.appbar.basic',
          child: TomSizedBox(
            height: 200,
            child: Scaffold(
              appBar: TomAppBar(
                tomId: 'appbar.basic',
                titleText: 'Basic TomAppBar',
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
              body: const Center(
                child: Text('TomAppBar extends StatelessWidget + TomWidgetMixin\n'
                    'and implements PreferredSizeWidget'),
              ),
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomAppBar with leading, bottom, and styling
        _DemoCard(
          tomId: 'demo.appbar.styled',
          child: TomSizedBox(
            height: 240,
            child: Scaffold(
              appBar: TomAppBar(
                tomId: 'appbar.styled',
                titleText: 'Styled AppBar',
                centerTitle: true,
                elevation: 4,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {},
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(40),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('With bottom widget'),
                  ),
                ),
              ),
              body: const Center(
                child: Text('Custom colors, centered title, and bottom widget'),
              ),
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomAppBar with title widget
        _DemoCard(
          tomId: 'demo.appbar.titleWidget',
          child: TomSizedBox(
            height: 200,
            child: Scaffold(
              appBar: TomAppBar(
                tomId: 'appbar.titleWidget',
                title: Row(
                  children: [
                    const Icon(Icons.star),
                    const SizedBox(width: 8),
                    const Text('Custom Title Widget'),
                  ],
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
              ),
              body: const Center(
                child: Text('Title as widget + custom shape'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: TomNavigationDestination (inside NavigationBar)
  // ===========================================================================

  Widget _buildNavigationDestinationSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DemoCard(
          tomId: 'demo.navDest.basic',
          child: TomSizedBox(
            height: 160,
            child: TomColumn(
              children: [
                TomExpanded(
                  child: Center(
                    child: Text(
                      'Selected: ${['Home', 'Search', 'Profile'][_navBarIndex]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                NavigationBar(
                  selectedIndex: _navBarIndex,
                  onDestinationSelected: (index) {
                    setState(() => _navBarIndex = index);
                  },
                  destinations: [
                    TomNavigationDestination(
                      tomId: 'navDest.home',
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: 'Home',
                    ),
                    TomNavigationDestination(
                      tomId: 'navDest.search',
                      icon: const Icon(Icons.search),
                      selectedIcon: const Icon(Icons.search),
                      label: 'Search',
                    ),
                    TomNavigationDestination(
                      tomId: 'navDest.profile',
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: 'Profile',
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

  // ===========================================================================
  // Section 3: TomNavigationDrawerDestination (inside NavigationDrawer)
  // ===========================================================================

  Widget _buildNavigationDrawerDestinationSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DemoCard(
          tomId: 'demo.drawerDest.basic',
          child: TomSizedBox(
            height: 320,
            child: TomRow(
              children: [
                // Inline NavigationDrawer preview
                TomSizedBox(
                  width: 280,
                  child: NavigationDrawer(
                    selectedIndex: _drawerIndex,
                    onDestinationSelected: (index) {
                      setState(() => _drawerIndex = index);
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
                        child: Text(
                          'Mail',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TomNavigationDrawerDestination(
                        tomId: 'drawerDest.inbox',
                        icon: const Icon(Icons.inbox_outlined),
                        selectedIcon: const Icon(Icons.inbox),
                        label: const Text('Inbox'),
                      ),
                      TomNavigationDrawerDestination(
                        tomId: 'drawerDest.sent',
                        icon: const Icon(Icons.send_outlined),
                        selectedIcon: const Icon(Icons.send),
                        label: const Text('Sent'),
                      ),
                      TomNavigationDrawerDestination(
                        tomId: 'drawerDest.drafts',
                        icon: const Icon(Icons.drafts_outlined),
                        selectedIcon: const Icon(Icons.drafts),
                        label: const Text('Drafts'),
                      ),
                      TomNavigationDrawerDestination(
                        tomId: 'drawerDest.trash',
                        icon: const Icon(Icons.delete_outline),
                        selectedIcon: const Icon(Icons.delete),
                        label: const Text('Trash'),
                      ),
                    ],
                  ),
                ),
                // Content area
                TomExpanded(
                  child: Center(
                    child: Text(
                      'Selected: ${['Inbox', 'Sent', 'Drafts', 'Trash'][_drawerIndex]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 4: TomTableCell (inside Table)
  // ===========================================================================

  Widget _buildTableCellSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic TomTableCell usage
        _DemoCard(
          tomId: 'demo.tableCell.basic',
          child: Table(
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                ),
                children: [
                  TomTableCell(
                    tomId: 'header.id',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('ID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'header.name',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Name',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'header.status',
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              // Data rows
              TableRow(
                children: [
                  TomTableCell(
                    tomId: 'cell.1.id',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('001'),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'cell.1.name',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Widget Alpha'),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'cell.1.status',
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.check_circle,
                          color: Colors.green.shade600),
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  TomTableCell(
                    tomId: 'cell.2.id',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('002'),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'cell.2.name',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Widget Beta'),
                    ),
                  ),
                  TomTableCell(
                    tomId: 'cell.2.status',
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child:
                          Icon(Icons.pending, color: Colors.orange.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 5: TomRefreshProgressIndicator
  // ===========================================================================

  Widget _buildRefreshProgressSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Static indicators at different values
        _DemoCard(
          tomId: 'demo.refreshProgress.static',
          child: TomColumn(
            children: [
              TomRow(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TomColumn(
                    children: [
                      TomRefreshProgressIndicator(
                        tomId: 'refreshProg.indeterminate',
                      ),
                      TomSizedBox(height: 8),
                      const Text('Indeterminate'),
                    ],
                  ),
                  TomColumn(
                    children: [
                      TomRefreshProgressIndicator(
                        tomId: 'refreshProg.quarter',
                        value: 0.25,
                        color: Colors.blue,
                      ),
                      TomSizedBox(height: 8),
                      const Text('25%'),
                    ],
                  ),
                  TomColumn(
                    children: [
                      TomRefreshProgressIndicator(
                        tomId: 'refreshProg.half',
                        value: 0.5,
                        color: Colors.orange,
                      ),
                      TomSizedBox(height: 8),
                      const Text('50%'),
                    ],
                  ),
                  TomColumn(
                    children: [
                      TomRefreshProgressIndicator(
                        tomId: 'refreshProg.full',
                        value: 1.0,
                        color: Colors.green,
                        backgroundColor: Colors.green.shade100,
                      ),
                      TomSizedBox(height: 8),
                      const Text('100%'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // In a RefreshIndicator context
        _DemoCard(
          tomId: 'demo.refreshProgress.inRefresh',
          child: TomSizedBox(
            height: 200,
            child: TomRefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 2));
                setState(() {
                  _refreshItems.add('Item ${_refreshItems.length + 1}');
                });
              },
              child: ListView.builder(
                itemCount: _refreshItems.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.article),
                  title: Text(_refreshItems[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 6: TomCupertinoTabView
  // ===========================================================================

  Widget _buildCupertinoTabViewSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DemoCard(
          tomId: 'demo.cupertinoTabView.info',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomContainer(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomRow(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        TomSizedBox(width: 8),
                        TomExpanded(
                          child: Text(
                            'TomCupertinoTabView',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    TomSizedBox(height: 12),
                    const Text(
                      'TomCupertinoTabView extends CupertinoTabView with '
                      'TomWidgetMixin. It provides tomId, scope, and '
                      'tomGroup for tab content views inside a '
                      'CupertinoTabScaffold.\n\n'
                      'It is a pure extension — no build override — adding '
                      'only the Tom identity fields for authorization and '
                      'resource resolution context.',
                    ),
                    TomSizedBox(height: 12),
                    TomContainer(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TomCupertinoTabView(\n'
                        '  tomId: \'myTab\',\n'
                        '  builder: (context) => const MyTabContent(),\n'
                        ')',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared Helpers
// =============================================================================

/// Section header with title and subtitle from resources.
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

/// Demo card with title, subtitle, and icon from resources.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: tomId, size: 24),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.subtitle',
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
            child,
          ],
        ),
      ),
    );
  }
}
