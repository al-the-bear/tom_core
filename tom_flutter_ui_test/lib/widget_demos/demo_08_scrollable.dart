/// Demo 08: Scrollable Containers
///
/// Comprehensive demonstration of Tom scrollable container widgets for
/// scroll views, nested scrolling, draggable sheets, interactive viewers,
/// carousels, and visibility controls.
/// Widgets covered: TomSingleChildScrollView, TomScrollbar,
/// TomCupertinoScrollbar, TomNestedScrollView, TomDraggableScrollableSheet,
/// TomInteractiveViewer, TomCarouselView, TomVisibility, TomOffstage,
/// TomSafeArea.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// ScrollBehavior that allows mouse drag for desktop/web platforms.
class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Scrollable Containers demo.
class ScrollableContainersDemo extends TomStatelessWidget {
  ScrollableContainersDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ScrollableDemoContent();

  }
}

class _ScrollableDemoContent extends TomStatefulWidget {
  _ScrollableDemoContent();

  @override
  State<_ScrollableDemoContent> createState() => _ScrollableDemoContentState();
}

class _ScrollableDemoContentState extends TomState<_ScrollableDemoContent>
    with SingleTickerProviderStateMixin {
  // ===========================================================================
  // Section 1: Basic Scroll Views state
  // ===========================================================================
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _cupertinoScrollController = ScrollController();

  // ===========================================================================
  // Section 2: Nested Scroll Views state
  // ===========================================================================
  late TabController _nestedTabController;

  // ===========================================================================
  // Section 3: InteractiveViewer state
  // ===========================================================================
  final TransformationController _transformationController =
      TransformationController();

  // ===========================================================================
  // Section 4: Visibility & Offstage state
  // ===========================================================================
  bool _isVisible = true;
  bool _maintainSize = true;
  bool _isOffstage = false;
  int _carouselTapIndex = -1;

  // ===========================================================================
  // Section 5: ACL state
  // ===========================================================================
  double _aclSheetSize = 0.5;
  bool _aclSnap = true;

  @override
  void initState() {
    super.initState();
    _nestedTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _cupertinoScrollController.dispose();
    _nestedTabController.dispose();
    _transformationController.dispose();
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
            // Section 1: Basic Scroll Views
            _SectionHeader(tomId: 'section.basicScroll'),
            TomSizedBox(height: 16),
            _buildSingleChildScrollSection(),
            TomSizedBox(height: 24),
            _buildHorizontalScrollSection(),
            TomSizedBox(height: 24),
            _buildScrollbarSection(),
            TomSizedBox(height: 24),
            _buildCupertinoScrollbarSection(),
            TomSizedBox(height: 32),

            // Section 2: Nested Scroll Views
            _SectionHeader(tomId: 'section.nestedScroll'),
            TomSizedBox(height: 16),
            _buildNestedScrollSection(),
            TomSizedBox(height: 32),

            // Section 3: Draggable & Interactive
            _SectionHeader(tomId: 'section.draggable'),
            TomSizedBox(height: 16),
            _buildDraggableSheetSection(),
            TomSizedBox(height: 24),
            _buildInteractiveViewerSection(),
            TomSizedBox(height: 32),

            // Section 4: Carousel & Visibility
            _SectionHeader(tomId: 'section.carousel'),
            TomSizedBox(height: 16),
            _buildCarouselSection(),
            TomSizedBox(height: 24),
            _buildVisibilitySection(),
            TomSizedBox(height: 24),
            _buildOffstageSection(),
            TomSizedBox(height: 24),
            _buildSafeAreaSection(),
            TomSizedBox(height: 32),

            // Section 5: ACL Layout Demo
            _SectionHeader(tomId: 'section.acl'),
            TomSizedBox(height: 16),
            _buildAclScrollSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Basic Scroll Views
  // ===========================================================================

  Widget _buildSingleChildScrollSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'singleChildScroll',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'singleChildScroll.verticalLabel'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomSingleChildScrollView(
              controller: _verticalScrollController,
              child: TomPadding(
                padding: const EdgeInsets.all(12),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(15, (i) {
                    return TomPadding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TomContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: TomText(
                          text: 'Scrollable item ${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            color: i.isEven
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalScrollSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'horizontalScroll',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'horizontalScroll.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: ScrollConfiguration(
              behavior: _MouseDragScrollBehavior(),
              child: TomSingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: TomRow(
                children: List.generate(10, (i) {
                  final colors = [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                    theme.colorScheme.tertiary,
                    theme.colorScheme.error,
                  ];
                  return TomPadding(
                    padding: const EdgeInsets.all(8),
                    child: TomContainer(
                      width: 100,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length].withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors[i % colors.length],
                        ),
                      ),
                      child: TomCenter(
                        child: TomText(
                          text: 'Item ${i + 1}',
                          style: TextStyle(
                            color: colors[i % colors.length],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollbarSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'scrollbar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'scrollbar.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomScrollbar(
              thumbVisibility: true,
              interactive: true,
              thickness: 8,
              radius: const Radius.circular(4),
              child: TomSingleChildScrollView(
                child: TomPadding(
                  padding: const EdgeInsets.all(12),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(20, (i) {
                      return TomPadding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TomText(
                          text: 'Line ${i + 1}: Scrollbar content with visible thumb',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoScrollbarSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'cupertinoScrollbar',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'cupertinoScrollbar.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomCupertinoScrollbar(
              controller: _cupertinoScrollController,
              thumbVisibility: true,
              thickness: 6,
              child: TomSingleChildScrollView(
                controller: _cupertinoScrollController,
                child: TomPadding(
                  padding: const EdgeInsets.all(12),
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(20, (i) {
                      return TomPadding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TomText(
                          text: 'Line ${i + 1}: Cupertino-style scrollbar',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Nested Scroll Views
  // ===========================================================================

  Widget _buildNestedScrollSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'nestedScroll',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'nestedScroll.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 350,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomNestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'Collapsible Header',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      background: TomContainer(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary,
                            ],
                          ),
                        ),
                      ),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    bottom: TabBar(
                      controller: _nestedTabController,
                      labelColor: theme.colorScheme.onPrimary,
                      unselectedLabelColor:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.6),
                      indicatorColor: theme.colorScheme.onPrimary,
                      tabs: const [
                        Tab(text: 'Tab 1'),
                        Tab(text: 'Tab 2'),
                        Tab(text: 'Tab 3'),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _nestedTabController,
                children: List.generate(3, (tabIndex) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: 20,
                    itemBuilder: (context, i) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text('${i + 1}'),
                          ),
                          title: Text('Tab ${tabIndex + 1} - Item ${i + 1}'),
                          subtitle:
                              const Text('Scroll to collapse the header'),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Draggable & Interactive
  // ===========================================================================

  Widget _buildDraggableSheetSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'draggableSheet',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'draggableSheet.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomStack(
              children: [
                // Background content
                TomContainer(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: TomCenter(
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TomIcon(
                          icon: Icons.swipe_vertical,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                        TomSizedBox(height: 8),
                        TomText(
                          tomId: 'draggableSheet.backgroundText',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Draggable sheet
                TomDraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.2,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [0.2, 0.4, 0.85],
                  builder: (context, scrollController) {
                    return TomContainer(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ScrollConfiguration(
                        behavior: _MouseDragScrollBehavior(),
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: 15,
                          itemBuilder: (context, i) {
                          if (i == 0) {
                            return TomColumn(
                              children: [
                                TomSizedBox(height: 8),
                                TomCenter(
                                  child: TomContainer(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                TomSizedBox(height: 12),
                                TomPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: TomText(
                                    tomId: 'draggableSheet.sheetTitle',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TomSizedBox(height: 8),
                              ],
                            );
                          }
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              child: Text('$i'),
                            ),
                            title: Text('Sheet item $i'),
                            subtitle: const Text('Drag handle to resize'),
                          );
                        },
                      ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveViewerSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'interactiveViewer',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'interactiveViewer.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: TomInteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(80),
              child: TomContainer(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.tertiaryContainer,
                    ],
                  ),
                ),
                child: TomCenter(
                  child: TomColumn(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TomIcon(
                        icon: Icons.zoom_in,
                        size: 48,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      TomSizedBox(height: 12),
                      TomText(
                        tomId: 'interactiveViewer.contentText',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomSizedBox(height: 4),
                      TomText(
                        tomId: 'interactiveViewer.hintText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TomSizedBox(height: 8),
          TomRow(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TomFilledButton(
                label: 'Reset Zoom',
                tonal: true,
                onPressed: () {
                  _transformationController.value = Matrix4.identity();
                },
                child: TomRow(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 16),
                    TomSizedBox(width: 4),
                    TomText(tomId: 'interactiveViewer.resetButton'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Carousel & Visibility
  // ===========================================================================

  Widget _buildCarouselSection() {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      theme.colorScheme.inversePrimary,
    ];
    final labels = ['Slide 1', 'Slide 2', 'Slide 3', 'Slide 4', 'Slide 5'];

    return _DemoCard(
      tomId: 'carousel',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'carousel.label'),
          TomSizedBox(height: 8),
          TomSizedBox(
            height: 160,
            child: ScrollConfiguration(
              behavior: _MouseDragScrollBehavior(),
              child: TomCarouselView(
                itemExtent: 280,
                shrinkExtent: 200,
                onTap: (i) => setState(() => _carouselTapIndex = i),
                children: List.generate(5, (i) {
                  return TomContainer(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[i],
                        colors[i].withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TomCenter(
                    child: TomColumn(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo,
                          size: 36,
                          color: theme.colorScheme.onPrimary,
                        ),
                        TomSizedBox(height: 8),
                        TomText(
                          text: labels[i],
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ),
            ),
          ),
          if (_carouselTapIndex >= 0) ...[
            TomSizedBox(height: 8),
            TomText(
              text: 'Tapped: ${labels[_carouselTapIndex]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisibilitySection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'visibility',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'visibility.label'),
          TomSizedBox(height: 8),
          TomRow(
            children: [
              TomFilledButton(
                label: 'Toggle Visibility',
                tonal: _isVisible,
                onPressed: () => setState(() => _isVisible = !_isVisible),
                child: TomText(
                  text: _isVisible ? 'Visible' : 'Hidden',
                ),
              ),
              TomSizedBox(width: 8),
              TomFilledButton(
                label: 'Toggle Maintain Size',
                tonal: _maintainSize,
                onPressed: () =>
                    setState(() => _maintainSize = !_maintainSize),
                child: TomText(
                  text: _maintainSize ? 'Maintain Size' : 'Collapse',
                ),
              ),
            ],
          ),
          TomSizedBox(height: 12),
          TomContainer(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.all(12),
              child: TomColumn(
                children: [
                  TomText(
                    tomId: 'visibility.beforeText',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TomSizedBox(height: 8),
                  TomVisibility(
                    visible: _isVisible,
                    maintainSize: _maintainSize,
                    maintainAnimation: _maintainSize,
                    maintainState: true,
                    child: TomContainer(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TomText(
                        tomId: 'visibility.targetText',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  TomSizedBox(height: 8),
                  TomText(
                    tomId: 'visibility.afterText',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffstageSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'offstage',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'offstage.label'),
          TomSizedBox(height: 8),
          TomRow(
            children: [
              TomFilledButton(
                label: 'Toggle Offstage',
                tonal: !_isOffstage,
                onPressed: () => setState(() => _isOffstage = !_isOffstage),
                child: TomText(
                  text: _isOffstage ? 'Offstage (hidden)' : 'On Stage',
                ),
              ),
            ],
          ),
          TomSizedBox(height: 12),
          TomContainer(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomPadding(
              padding: const EdgeInsets.all(12),
              child: TomColumn(
                children: [
                  TomText(
                    tomId: 'offstage.beforeText',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TomOffstage(
                    offstage: _isOffstage,
                    child: TomPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TomContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TomText(
                          tomId: 'offstage.targetText',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TomText(
                    tomId: 'offstage.afterText',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeAreaSection() {
    final theme = Theme.of(context);

    return _DemoCard(
      tomId: 'safeArea',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(tomId: 'safeArea.label'),
          TomSizedBox(height: 8),
          TomContainer(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomSafeArea(
              child: TomContainer(
                color: theme.colorScheme.primaryContainer,
                child: TomCenter(
                  child: TomText(
                    tomId: 'safeArea.contentText',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          TomSizedBox(height: 4),
          TomText(
            tomId: 'safeArea.hintText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: ACL Layout Demo
  // ===========================================================================

  Widget _buildAclScrollSection() {
    return _DemoCard(
      tomId: 'aclScroll',
      child: AclBuilder()
          // Row 1: Sheet size control
          .append(TomText(tomId: 'aclScroll.sheetSizeLabel'))
          .append(
            TomSlider(
              value: _aclSheetSize,
              min: 0.2,
              max: 1.0,
              divisions: 8,
              label: '${(_aclSheetSize * 100).round()}%',
              onChanged: (v) => setState(() => _aclSheetSize = v),
            ),
            dist: 8,
          )
          .expandX()
          .append(
            TomText(
              text: '${(_aclSheetSize * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            dist: 8,
          )
          .newRow(dist: 12)
          // Row 2: Snap toggle
          .append(TomText(tomId: 'aclScroll.snapLabel'))
          .append(
            TomSwitch(
              value: _aclSnap,
              onChanged: (v) => setState(() => _aclSnap = v),
            ),
            dist: 8,
          )
          .newRow(dist: 16)
          // Row 3: Preview area with scroll view
          .append(
            TomContainer(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: TomStack(
                children: [
                  TomSingleChildScrollView(
                    child: TomPadding(
                      padding: const EdgeInsets.all(8),
                      child: TomColumn(
                        children: List.generate(8, (i) {
                          return TomPadding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: TomText(
                              text: 'Background row ${i + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  TomAlign(
                    alignment: Alignment.bottomCenter,
                    child: TomContainer(
                      height: 120 * _aclSheetSize,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: TomCenter(
                        child: TomText(
                          text:
                              'Sheet: ${(_aclSheetSize * 100).round()}% '
                              '${_aclSnap ? "(snap)" : "(free)"}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .expandX()
          .newRow(dist: 12)
          // Row 4: Buttons
          .append(
            TomTextButton(
              tomId: 'aclScroll.reset',
              onPressed: () {
                setState(() {
                  _aclSheetSize = 0.5;
                  _aclSnap = true;
                });
              },
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'aclScroll.apply',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget for demo sections.
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({
    required this.tomId,
  });

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

  _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      elevation: 2,
      child: TomPadding(
        padding: const EdgeInsets.all(20),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomContainer(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomIcon(
                    tomId: tomId,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.description',
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
            TomDivider(color: theme.colorScheme.outlineVariant),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
