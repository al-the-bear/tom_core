/// Comprehensive Scrollable Widgets Demo
///
/// This demo showcases scrollable widgets including ListView, GridView,
/// PageView, SingleChildScrollView, and scroll controllers.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main scrollable widgets demo screen.
class ScrollableDemo extends StatelessWidget {
  const ScrollableDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'ListView',
          subtitle: 'Scrollable list of children',
        ),
        _ListViewSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'GridView',
          subtitle: 'Scrollable grid of children',
        ),
        _GridViewSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'PageView',
          subtitle: 'Swipeable pages',
        ),
        _PageViewSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'SingleChildScrollView',
          subtitle: 'Scrollable single child',
        ),
        _SingleChildScrollViewSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Scroll Controllers',
          subtitle: 'Programmatic scroll control',
        ),
        _ScrollControllerSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Nested Scrolling',
          subtitle: 'Scrollable inside scrollable',
        ),
        _NestedScrollSection(),
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
// ListView Section
// =============================================================================

class _ListViewSection extends StatelessWidget {
  const _ListViewSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'ListView.builder',
          'Efficiently builds items on demand.',
          TomSizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) {
                return TomListTile(
                  leading: TomCircleAvatar(child: TomText('${index + 1}')),
                  title: TomText('Item ${index + 1}'),
                  subtitle: TomText('Description for item ${index + 1}'),
                  trailing: const TomIcon(Icons.chevron_right),
                );
              },
            ),
          ),
        ),
        _buildDemoCard(
          'ListView.separated',
          'ListView with separators between items.',
          TomSizedBox(
            height: 200,
            child: ListView.separated(
              itemCount: 10,
              separatorBuilder: (context, index) => const TomDivider(height: 1),
              itemBuilder: (context, index) {
                return TomListTile(
                  leading: TomIcon(
                    Icons.folder,
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                  title: TomText('Folder ${index + 1}'),
                  trailing: TomText('${(index + 1) * 3} items'),
                );
              },
            ),
          ),
        ),
        _buildDemoCard(
          'Horizontal ListView',
          'Horizontal scrolling list.',
          TomSizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) {
                return TomContainer(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.primaries[index % Colors.primaries.length],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TomCenter(
                    child: TomText(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _buildDemoCard(
          'ListView with Sticky Header',
          'Using itemBuilder with custom items.',
          TomSizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: 15,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return TomContainer(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.all(12),
                    child: const TomText(
                      'Today',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }
                if (index == 5) {
                  return TomContainer(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.all(12),
                    child: const TomText(
                      'Yesterday',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return TomListTile(
                  leading: const TomIcon(Icons.message),
                  title: TomText('Message $index'),
                );
              },
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
// GridView Section
// =============================================================================

class _GridViewSection extends StatelessWidget {
  const _GridViewSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'GridView.count',
          'Fixed number of columns.',
          TomSizedBox(
            height: 200,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: List.generate(12, (index) {
                return TomContainer(
                  decoration: BoxDecoration(
                    color: Colors.primaries[index % Colors.primaries.length],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomCenter(
                    child: TomText(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        _buildDemoCard(
          'GridView.builder',
          'Efficiently builds items on demand.',
          TomSizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 24,
              itemBuilder: (context, index) {
                return TomContainer(
                  decoration: BoxDecoration(
                    color: Colors.primaries[index % Colors.primaries.length]
                        .shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomIcon(
                    IconData(
                      0xe000 + index,
                      fontFamily: 'MaterialIcons',
                    ),
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                );
              },
            ),
          ),
        ),
        _buildDemoCard(
          'GridView.extent',
          'Fixed maximum item extent.',
          TomSizedBox(
            height: 200,
            child: GridView.extent(
              maxCrossAxisExtent: 100,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: List.generate(12, (index) {
                return TomCard(
                  child: TomCenter(
                    child: TomText('Item ${index + 1}'),
                  ),
                );
              }),
            ),
          ),
        ),
        _buildDemoCard(
          'SliverGridDelegateWithMaxCrossAxisExtent',
          'Responsive grid with max item width.',
          TomSizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return TomContainer(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.primaries[index % Colors.primaries.length],
                        Colors.primaries[(index + 3) % Colors.primaries.length],
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomCenter(
                    child: TomText(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
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
// PageView Section
// =============================================================================

class _PageViewSection extends StatefulWidget {
  const _PageViewSection();

  @override
  State<_PageViewSection> createState() => _PageViewSectionState();
}

class _PageViewSectionState extends State<_PageViewSection> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic PageView',
          'Swipeable pages with indicator.',
          TomColumn(
            children: [
              TomSizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return TomContainer(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.primaries[index % Colors.primaries.length],
                            Colors.primaries[
                                (index + 3) % Colors.primaries.length],
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TomCenter(
                        child: TomColumn(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TomText(
                              'Page ${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TomSizedBox(height: 8),
                            const TomText(
                              'Swipe to navigate',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const TomSizedBox(height: 16),
              TomRow(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return TomContainer(
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const _VerticalPageViewDemo(),
        const _PageViewWithTransformDemo(),
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

class _VerticalPageViewDemo extends StatelessWidget {
  const _VerticalPageViewDemo();

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
              'Vertical PageView',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              'Pages scrolling vertically.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            TomSizedBox(
              height: 150,
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return TomContainer(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.primaries[index % Colors.primaries.length]
                          .shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.primaries[index % Colors.primaries.length],
                      ),
                    ),
                    child: TomCenter(
                      child: TomRow(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const TomIcon(Icons.swap_vert, color: Colors.grey),
                          const TomSizedBox(width: 8),
                          TomText(
                            'Section ${index + 1}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageViewWithTransformDemo extends StatefulWidget {
  const _PageViewWithTransformDemo();

  @override
  State<_PageViewWithTransformDemo> createState() =>
      _PageViewWithTransformDemoState();
}

class _PageViewWithTransformDemoState
    extends State<_PageViewWithTransformDemo> {
  final _controller = PageController(viewportFraction: 0.8);

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
            const TomText(
              'PageView with Transform',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              'Carousel effect with viewportFraction.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            TomSizedBox(
              height: 150,
              child: PageView.builder(
                controller: _controller,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return TomAnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_controller.position.haveDimensions) {
                        value = (_controller.page ?? 0) - index;
                        value = (1 - (value.abs() * 0.3)).clamp(0.85, 1.0);
                      }
                      return TomCenter(
                        child: Transform.scale(
                          scale: value,
                          child: TomContainer(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.primaries[
                                  index % Colors.primaries.length],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TomCenter(
                              child: TomText(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SingleChildScrollView Section
// =============================================================================

class _SingleChildScrollViewSection extends StatelessWidget {
  const _SingleChildScrollViewSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic SingleChildScrollView',
          'Scrollable container for a single child.',
          TomSizedBox(
            height: 150,
            child: TomSingleChildScrollView(
              child: TomColumn(
                children: List.generate(
                  10,
                  (index) => TomListTile(
                    leading: TomIcon(Icons.star, color: Colors.amber),
                    title: TomText('Item ${index + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'Horizontal SingleChildScrollView',
          'Horizontal scrolling container.',
          TomSizedBox(
            height: 100,
            child: TomSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TomRow(
                children: List.generate(
                  8,
                  (index) => TomContainer(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.primaries[index % Colors.primaries.length],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TomCenter(
                      child: TomText(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildDemoCard(
          'With Padding and Physics',
          'Custom padding and scroll physics.',
          TomSizedBox(
            height: 150,
            child: TomSingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: TomColumn(
                children:
                    [
                      ('Welcome!', Icons.waving_hand, Colors.orange),
                      ('Getting Started', Icons.play_arrow, Colors.blue),
                      ('Documentation', Icons.description, Colors.green),
                      ('API Reference', Icons.code, Colors.purple),
                      ('Examples', Icons.lightbulb, Colors.amber),
                    ].map((item) {
                      return TomCard(
                        child: TomListTile(
                          leading: TomIcon(item.$2, color: item.$3),
                          title: TomText(item.$1),
                          trailing: const TomIcon(Icons.chevron_right),
                        ),
                      );
                    }).toList(),
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
// Scroll Controller Section
// =============================================================================

class _ScrollControllerSection extends StatefulWidget {
  const _ScrollControllerSection();

  @override
  State<_ScrollControllerSection> createState() =>
      _ScrollControllerSectionState();
}

class _ScrollControllerSectionState extends State<_ScrollControllerSection> {
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final showButton = _scrollController.offset > 50;
      if (showButton != _showScrollToTop) {
        setState(() => _showScrollToTop = showButton);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
            const TomText(
              'Scroll Controller Demo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const TomSizedBox(height: 4),
            TomText(
              'Programmatic scrolling and position listening.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const TomSizedBox(height: 12),
            TomRow(
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const TomText('Scroll to Top'),
                ),
                const TomSizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const TomText('Scroll to Bottom'),
                ),
              ],
            ),
            const TomSizedBox(height: 12),
            TomSizedBox(
              height: 200,
              child: TomStack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      return TomListTile(
                        leading: TomCircleAvatar(child: TomText('${index + 1}')),
                        title: TomText('Item ${index + 1}'),
                      );
                    },
                  ),
                  if (_showScrollToTop)
                    TomPositioned(
                      right: 8,
                      bottom: 8,
                      child: FloatingActionButton.small(
                        onPressed: () {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const TomIcon(Icons.arrow_upward),
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
// Nested Scroll Section
// =============================================================================

class _NestedScrollSection extends StatelessWidget {
  const _NestedScrollSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Horizontal in Vertical',
          'Horizontal scroll inside vertical scroll.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomPadding(
                padding: EdgeInsets.only(bottom: 8),
                child: TomText(
                  'Categories',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TomSizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return TomContainer(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.primaries[index % Colors.primaries.length]
                            .shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomColumn(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TomIcon(
                            [
                              Icons.home,
                              Icons.work,
                              Icons.shopping_cart,
                              Icons.favorite,
                              Icons.star,
                              Icons.music_note,
                              Icons.movie,
                              Icons.book,
                              Icons.sports,
                              Icons.flight,
                            ][index % 10],
                          ),
                          const TomSizedBox(height: 4),
                          TomText(
                            'Cat ${index + 1}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const TomSizedBox(height: 16),
              const TomPadding(
                padding: EdgeInsets.only(bottom: 8),
                child: TomText(
                  'Featured',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TomSizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return TomContainer(
                      width: 180,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.primaries[index % Colors.primaries.length],
                            Colors.primaries[
                                (index + 4) % Colors.primaries.length],
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TomCenter(
                        child: TomText(
                          'Featured ${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Physics Options',
          'Different scroll physics behaviors.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText(
                'BouncingScrollPhysics (iOS style):',
                style: TextStyle(fontSize: 12),
              ),
              const TomSizedBox(height: 4),
              TomSizedBox(
                height: 80,
                child: TomListView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: List.generate(
                    5,
                    (i) => TomContainer(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      color: Colors.blue.shade200,
                      child: TomCenter(child: TomText('${i + 1}')),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(height: 12),
              const TomText(
                'ClampingScrollPhysics (Android style):',
                style: TextStyle(fontSize: 12),
              ),
              const TomSizedBox(height: 4),
              TomSizedBox(
                height: 80,
                child: TomListView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: List.generate(
                    5,
                    (i) => TomContainer(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      color: Colors.green.shade200,
                      child: TomCenter(child: TomText('${i + 1}')),
                    ),
                  ),
                ),
              ),
              const TomSizedBox(height: 12),
              const TomText(
                'NeverScrollableScrollPhysics:',
                style: TextStyle(fontSize: 12),
              ),
              const TomSizedBox(height: 4),
              TomSizedBox(
                height: 80,
                child: TomListView(
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: List.generate(
                    5,
                    (i) => TomContainer(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      color: Colors.red.shade200,
                      child: TomCenter(child: TomText('${i + 1}')),
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
