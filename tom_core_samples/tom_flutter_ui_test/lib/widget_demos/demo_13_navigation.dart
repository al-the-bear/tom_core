/// Demo 13: Navigation Patterns
///
/// Comprehensive demonstration of all Tom navigation widgets.
/// Widgets covered: TomTabBar, TomTabBarView, TomTab, TomNavigationBar,
/// TomBottomNavigationBar, TomCupertinoTabBar, TomNavigationRail,
/// TomNavigationDrawer, TomDrawer, TomStepper, TomPageView,
/// TomCupertinoNavigationBar.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Navigation demo.
class NavigationDemo extends TomStatelessWidget {
  NavigationDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _NavigationDemoContent();
  }
}

class _NavigationDemoContent extends TomStatefulWidget {
  _NavigationDemoContent();

  @override
  State<_NavigationDemoContent> createState() => _NavigationDemoContentState();
}

class _NavigationDemoContentState extends TomState<_NavigationDemoContent>
    with TickerProviderStateMixin {
  // TabController for tab demos
  late TabController _tabController;
  late TabController _scrollableTabController;

  // Navigation state
  int _bottomNavIndex = 0;
  int _navigationBarIndex = 0;
  int _cupertinoTabIndex = 0;
  int _railIndex = 0;
  bool _railExtended = false;
  int _drawerIndex = 0;

  // Stepper state
  int _currentStep = 0;
  int _verticalStep = 0;

  // PageView state
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollableTabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollableTabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Tab Navigation
            _SectionHeader(tomId: 'section.tabs'),
            TomSizedBox(height: 16),
            _buildTabBarSection(),
            TomSizedBox(height: 24),
            _buildScrollableTabBarSection(),
            TomSizedBox(height: 32),

            // Section 2: Bottom Navigation
            _SectionHeader(tomId: 'section.bottomNav'),
            TomSizedBox(height: 16),
            _buildNavigationBarSection(),
            TomSizedBox(height: 24),
            _buildBottomNavigationBarSection(),
            TomSizedBox(height: 24),
            _buildCupertinoTabBarSection(),
            TomSizedBox(height: 32),

            // Section 3: Rail & Drawer Navigation
            _SectionHeader(tomId: 'section.railDrawer'),
            TomSizedBox(height: 16),
            _buildNavigationRailSection(),
            TomSizedBox(height: 24),
            _buildNavigationDrawerSection(),
            TomSizedBox(height: 24),
            _buildDrawerSection(),
            TomSizedBox(height: 32),

            // Section 4: Sequential Navigation
            _SectionHeader(tomId: 'section.sequential'),
            TomSizedBox(height: 16),
            _buildStepperSection(),
            TomSizedBox(height: 24),
            _buildPageViewSection(),
            TomSizedBox(height: 32),

            // Section 5: iOS Navigation
            _SectionHeader(tomId: 'section.cupertino'),
            TomSizedBox(height: 16),
            _buildCupertinoNavigationBarSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Tab Navigation
  // ===========================================================================

  Widget _buildTabBarSection() {
    return _DemoCard(
      tomId: 'tabBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic TabBar with TabBarView
          TomText(
            tomId: 'tabBar.basicLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomTabBar(
              controller: _tabController,
              tabs: [
                TomTab(tomId: 'tabBar.tab.home', text: 'Home'),
                TomTab(tomId: 'tabBar.tab.search', text: 'Search'),
                TomTab(tomId: 'tabBar.tab.settings', text: 'Settings'),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomTabBarView(
              controller: _tabController,
              children: [
                _TabContent(
                  icon: Icons.home,
                  label: 'Home',
                  color: Theme.of(context).colorScheme.primary,
                ),
                _TabContent(
                  icon: Icons.search,
                  label: 'Search',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _TabContent(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
          ),
          TomSizedBox(height: 24),

          // Tabs with icons
          TomText(
            tomId: 'tabBar.iconTabsLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomTabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onPrimaryContainer,
              tabs: [
                TomTab(tomId: 'tabBar.iconTab.photos', icon: Icon(Icons.photo)),
                TomTab(
                  tomId: 'tabBar.iconTab.videos',
                  icon: Icon(Icons.videocam),
                ),
                TomTab(
                  tomId: 'tabBar.iconTab.music',
                  icon: Icon(Icons.music_note),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableTabBarSection() {
    return _DemoCard(
      tomId: 'scrollableTabBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable TabBar
          TomText(
            tomId: 'scrollableTabBar.label',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomTabBar(
              controller: _scrollableTabController,
              isScrollable: true,
              tabs: [
                TomTab(tomId: 'scrollableTabBar.tab.all', text: 'All'),
                TomTab(
                  tomId: 'scrollableTabBar.tab.documents',
                  text: 'Documents',
                ),
                TomTab(tomId: 'scrollableTabBar.tab.images', text: 'Images'),
                TomTab(tomId: 'scrollableTabBar.tab.videos', text: 'Videos'),
                TomTab(tomId: 'scrollableTabBar.tab.audio', text: 'Audio'),
                TomTab(
                  tomId: 'scrollableTabBar.tab.archives',
                  text: 'Archives',
                ),
              ],
            ),
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomTabBarView(
              controller: _scrollableTabController,
              children: List.generate(6, (index) {
                final labels = [
                  'All Files',
                  'Documents',
                  'Images',
                  'Videos',
                  'Audio',
                  'Archives',
                ];
                return Center(
                  child: TomText(
                    text: labels[index],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Bottom Navigation
  // ===========================================================================

  Widget _buildNavigationBarSection() {
    return _DemoCard(
      tomId: 'navigationBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'navigationBar.m3Label',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomNavigationBar(
              selectedIndex: _navigationBarIndex,
              onDestinationSelected: (index) {
                setState(() => _navigationBarIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
          TomSizedBox(height: 8),
          Center(
            child: TomText(
              text:
                  'Selected: ${['Home', 'Explore', 'Saved', 'Profile'][_navigationBarIndex]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBarSection() {
    return _DemoCard(
      tomId: 'bottomNavBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'bottomNavBar.legacyLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomBottomNavigationBar(
              currentIndex: _bottomNavIndex,
              onTap: (index) {
                setState(() => _bottomNavIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox),
                  label: 'Inbox',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Sent'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.drafts),
                  label: 'Drafts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.delete),
                  label: 'Trash',
                ),
              ],
            ),
          ),
          TomSizedBox(height: 8),
          Center(
            child: TomText(
              text:
                  'Selected: ${['Inbox', 'Sent', 'Drafts', 'Trash'][_bottomNavIndex]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoTabBarSection() {
    return _DemoCard(
      tomId: 'cupertinoTabBar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'cupertinoTabBar.iosLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomCupertinoTabBar(
              currentIndex: _cupertinoTabIndex,
              onTap: (index) {
                setState(() => _cupertinoTabIndex = index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.house),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.bell),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
          TomSizedBox(height: 8),
          Center(
            child: TomText(
              text:
                  'Selected: ${['Home', 'Search', 'Alerts', 'Settings'][_cupertinoTabIndex]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Rail & Drawer Navigation
  // ===========================================================================

  Widget _buildNavigationRailSection() {
    return _DemoCard(
      tomId: 'navigationRail',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomRow(
            children: [
              TomText(
                tomId: 'navigationRail.sideLabel',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              TomText(
                tomId: 'navigationRail.extendedLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TomSizedBox(width: 8),
              Switch(
                value: _railExtended,
                onChanged: (value) {
                  setState(() => _railExtended = value);
                },
              ),
            ],
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomRow(
              children: [
                TomNavigationRail(
                  selectedIndex: _railIndex,
                  extended: _railExtended,
                  onDestinationSelected: (index) {
                    setState(() => _railIndex = index);
                  },
                  leading: FloatingActionButton(
                    mini: true,
                    onPressed: () {},
                    child: const Icon(Icons.add),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: Text('Projects'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                TomExpanded(
                  child: Center(
                    child: TomText(
                      text: [
                        'Dashboard',
                        'Analytics',
                        'Projects',
                        'Settings',
                      ][_railIndex],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawerSection() {
    return _DemoCard(
      tomId: 'navigationDrawer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'navigationDrawer.m3DrawerLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomRow(
              children: [
                // Navigation Drawer
                TomSizedBox(
                  width: 240,
                  child: TomNavigationDrawer(
                    selectedIndex: _drawerIndex,
                    onDestinationSelected: (index) {
                      setState(() => _drawerIndex = index);
                    },
                    children: [
                      // Header
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: TomColumn(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const CircleAvatar(
                              radius: 32,
                              child: Icon(Icons.person, size: 32),
                            ),
                            TomSizedBox(height: 8),
                            TomText(
                              text: 'Demo User',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TomText(
                              text: 'demo@example.com',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.inbox),
                        label: Text('Inbox'),
                      ),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.send),
                        label: Text('Outbox'),
                      ),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.favorite),
                        label: Text('Favorites'),
                      ),
                      const Divider(),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                      const NavigationDrawerDestination(
                        icon: Icon(Icons.help),
                        label: Text('Help'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                TomExpanded(
                  child: Center(
                    child: TomText(
                      text: [
                        'Inbox',
                        'Outbox',
                        'Favorites',
                        'Settings',
                        'Help',
                      ][_drawerIndex.clamp(0, 4)],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection() {
    return _DemoCard(
      tomId: 'drawer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'drawer.standardLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomElevatedButton(
                tomId: 'drawer.openButton',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: TomSizedBox(
                        width: 280,
                        height: 400,
                        child: TomDrawer(
                          child: TomColumn(
                            children: [
                              DrawerHeader(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                                child: Center(
                                  child: TomText(
                                    text: 'Drawer Demo',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.home),
                                title: const Text('Home'),
                                onTap: () => Navigator.pop(context),
                              ),
                              ListTile(
                                leading: const Icon(Icons.account_circle),
                                title: const Text('Profile'),
                                onTap: () => Navigator.pop(context),
                              ),
                              ListTile(
                                leading: const Icon(Icons.settings),
                                title: const Text('Settings'),
                                onTap: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              ListTile(
                                leading: const Icon(Icons.logout),
                                title: const Text('Logout'),
                                onTap: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          TomSizedBox(height: 8),
          Center(
            child: TomText(
              tomId: 'drawer.hint',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Sequential Navigation
  // ===========================================================================

  Widget _buildStepperSection() {
    return _DemoCard(
      tomId: 'stepper',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Stepper
          TomText(
            tomId: 'stepper.horizontalLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomSizedBox(
            height: 200,
            child: TomStepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              steps: [
                Step(
                  title: const Text('Account'),
                  content: TomContainer(
                    height: 60,
                    child: Center(
                      child: TomText(
                        text: 'Enter account details',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text('Address'),
                  content: TomContainer(
                    height: 60,
                    child: Center(
                      child: TomText(
                        text: 'Enter shipping address',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text('Confirm'),
                  content: TomContainer(
                    height: 60,
                    child: Center(
                      child: TomText(
                        text: 'Review and confirm',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  isActive: _currentStep >= 2,
                ),
              ],
            ),
          ),
          TomSizedBox(height: 24),

          // Vertical Stepper
          TomText(
            tomId: 'stepper.verticalLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 350,
            child: TomStepper(
              type: StepperType.vertical,
              currentStep: _verticalStep,
              onStepContinue: () {
                if (_verticalStep < 3) {
                  setState(() => _verticalStep++);
                }
              },
              onStepCancel: () {
                if (_verticalStep > 0) {
                  setState(() => _verticalStep--);
                }
              },
              steps: [
                Step(
                  title: const Text('Select Plan'),
                  subtitle: const Text('Choose your subscription'),
                  content: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TomText(
                      text: 'Select a plan that fits your needs.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  isActive: _verticalStep >= 0,
                ),
                Step(
                  title: const Text('Payment'),
                  subtitle: const Text('Add payment method'),
                  content: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TomText(
                      text: 'Enter your payment information.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  isActive: _verticalStep >= 1,
                ),
                Step(
                  title: const Text('Verification'),
                  subtitle: const Text('Verify your identity'),
                  content: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TomText(
                      text: 'Complete identity verification.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  isActive: _verticalStep >= 2,
                ),
                Step(
                  title: const Text('Complete'),
                  subtitle: const Text('Finish setup'),
                  content: TomPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TomText(
                      text: 'Your account is ready!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  isActive: _verticalStep >= 3,
                  state: _verticalStep > 3
                      ? StepState.complete
                      : StepState.indexed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageViewSection() {
    return _DemoCard(
      tomId: 'pageView',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'pageView.swipeLabel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TomSizedBox(height: 12),
          TomContainer(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TomPageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: List.generate(4, (index) {
                final colors = [
                  Colors.blue.shade100,
                  Colors.green.shade100,
                  Colors.orange.shade100,
                  Colors.purple.shade100,
                ];
                final titles = [
                  'Welcome',
                  'Features',
                  'Pricing',
                  'Get Started',
                ];
                return TomContainer(
                  color: colors[index],
                  child: Center(
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          [
                            Icons.waving_hand,
                            Icons.star,
                            Icons.attach_money,
                            Icons.rocket_launch,
                          ][index],
                          size: 48,
                        ),
                        TomSizedBox(height: 16),
                        TomText(
                          text: titles[index],
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.black87),
                        ),
                        TomText(
                          text: 'Page ${index + 1} of 4',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          TomSizedBox(height: 12),
          // Page indicators
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return TomContainer(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              );
            }),
          ),
          TomSizedBox(height: 8),
          // Navigation buttons
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomIconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              TomSizedBox(width: 16),
              TomIconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < 3
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: iOS Navigation
  // ===========================================================================

  Widget _buildCupertinoNavigationBarSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'cupertinoNavBar',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              tomId: 'cupertinoNavBar.iosBarLabel',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            TomSizedBox(height: 12),

            // Basic Cupertino Navigation Bar
            TomText(
              tomId: 'cupertinoNavBar.basicLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomContainer(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: TomCupertinoNavigationBar(
                middle: Text('Page Title'),
                transitionBetweenRoutes: false,
              ),
            ),
            TomSizedBox(height: 16),

            // With leading and trailing
            TomText(
              tomId: 'cupertinoNavBar.withActionsLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomContainer(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: TomCupertinoNavigationBar(
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Cancel'),
                  onPressed: () {},
                ),
                middle: const Text('Edit Profile'),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Save'),
                  onPressed: () {},
                ),
                transitionBetweenRoutes: false,
              ),
            ),
            TomSizedBox(height: 16),

            // With back button simulation
            TomText(
              tomId: 'cupertinoNavBar.backButtonLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TomSizedBox(height: 8),
            TomContainer(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: TomCupertinoNavigationBar(
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(CupertinoIcons.back), Text('Back')],
                  ),
                  onPressed: () {},
                ),
                middle: const Text('Details'),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.share),
                  onPressed: () {},
                ),
                transitionBetweenRoutes: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Tab content placeholder widget.
class _TabContent extends TomStatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  _TabContent({required this.icon, required this.label, required this.color});

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      child: TomColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          TomSizedBox(height: 8),
          TomText(
            text: '$label Tab Content',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// Section header widget with gradient underline.
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

/// Demo card widget for individual widget showcases.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
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
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
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
            TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
