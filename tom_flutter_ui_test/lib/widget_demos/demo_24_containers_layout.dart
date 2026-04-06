/// Demo 24: Containers, Transforms & Layout
///
/// Demonstrates Tom container, transform, scaffold, and layout primitives
/// not covered in previous demos.
///
/// Widgets covered: TomScaffold, TomBottomAppBar, TomCupertinoPageScaffold,
/// TomCupertinoTabScaffold, TomDecoratedBox, TomColoredBox,
/// TomPhysicalModel, TomPhysicalShape, TomTransform, TomRotatedBox,
/// TomFractionalTranslation, TomConstraintsTransformBox,
/// TomSizedOverflowBox, TomOverflowBar, TomFlow, TomListBody,
/// TomCustomPaint, TomCustomSingleChildLayout, TomCustomMultiChildLayout,
/// TomGridTile, TomGridTileBar, TomExpansionPanel,
/// TomSliverOffstage, TomSliverResizingHeader.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Containers, Transforms & Layout demo.
class ContainersLayoutDemo extends TomStatelessWidget {
  ContainersLayoutDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ContainersLayoutDemoContent();
  }
}

class _ContainersLayoutDemoContent extends TomStatefulWidget {
  _ContainersLayoutDemoContent();

  @override
  State<_ContainersLayoutDemoContent> createState() =>
      _ContainersLayoutDemoContentState();
}

class _ContainersLayoutDemoContentState
    extends TomState<_ContainersLayoutDemoContent> {
  // ExpansionPanel state
  bool _panel1Expanded = false;
  bool _panel2Expanded = true;

  // SliverOffstage state
  bool _sliverOffstage = false;

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Scaffolds
            _SectionHeader(tomId: 'section.scaffolds'),
            TomSizedBox(height: 16),
            _buildScaffoldSection(context),
            TomSizedBox(height: 32),

            // Section 2: Surface Containers
            _SectionHeader(tomId: 'section.surfaces'),
            TomSizedBox(height: 16),
            _buildSurfaceContainersSection(context),
            TomSizedBox(height: 32),

            // Section 3: Transforms & Position
            _SectionHeader(tomId: 'section.transforms'),
            TomSizedBox(height: 16),
            _buildTransformSection(context),
            TomSizedBox(height: 32),

            // Section 4: Multi-child Layout
            _SectionHeader(tomId: 'section.multiChild'),
            TomSizedBox(height: 16),
            _buildOverflowBarSection(context),
            TomSizedBox(height: 16),
            _buildFlowSection(context),
            TomSizedBox(height: 32),

            // Section 5: Custom Layout & Paint
            _SectionHeader(tomId: 'section.customLayout'),
            TomSizedBox(height: 16),
            _buildCustomPaintSection(context),
            TomSizedBox(height: 16),
            _buildCustomLayoutSection(context),
            TomSizedBox(height: 32),

            // Section 6: Grid & Expansion
            _SectionHeader(tomId: 'section.gridExpansion'),
            TomSizedBox(height: 16),
            _buildGridTileSection(context),
            TomSizedBox(height: 16),
            _buildExpansionPanelSection(context),
            TomSizedBox(height: 32),

            // Section 7: Sliver Extras
            _SectionHeader(tomId: 'section.sliverExtras'),
            TomSizedBox(height: 16),
            _buildSliverExtrasSection(context),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Scaffolds
  // ===========================================================================

  Widget _buildScaffoldSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomScaffold with TomBottomAppBar
        _DemoCard(
          tomId: 'demo.scaffold',
          child: TomSizedBox(
            height: 250,
            child: TomScaffold(
              tomId: 'scaffold.demo',
              appBar: TomAppBar(
                tomId: 'scaffold.appbar',
                titleText: 'TomScaffold',
              ),
              body: const Center(child: Text('Scaffold body content')),
              bottomNavigationBar: TomBottomAppBar(
                tomId: 'bottomAppBar.demo',
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: const CircularNotchedRectangle(),
                child: TomRow(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 48),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                mini: true,
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomCupertinoPageScaffold
        _DemoCard(
          tomId: 'demo.cupertinoScaffold',
          child: TomSizedBox(
            height: 200,
            child: TomCupertinoPageScaffold(
              tomId: 'cupertinoPage.demo',
              navigationBar: const CupertinoNavigationBar(
                middle: Text('Cupertino Page'),
              ),
              child: const Center(
                child: Text('CupertinoPageScaffold content'),
              ),
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomCupertinoTabScaffold
        _DemoCard(
          tomId: 'demo.cupertinoTabScaffold',
          child: TomSizedBox(
            height: 250,
            child: TomCupertinoTabScaffold(
              tomId: 'cupertinoTab.demo',
              tabBar: CupertinoTabBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.search),
                    label: 'Search',
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (context) => Center(
                    child: Text('Tab $index content'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: Surface Containers
  // ===========================================================================

  Widget _buildSurfaceContainersSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.surfaces',
      child: TomWrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // TomDecoratedBox
          TomColumn(
            children: [
              TomDecoratedBox(
                tomId: 'decoratedBox.demo',
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade200, Colors.purple.shade200],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(
                  width: 80,
                  height: 60,
                  child: Center(child: Text('Decorated')),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('DecoratedBox', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomColoredBox
          TomColumn(
            children: [
              TomColoredBox(
                tomId: 'coloredBox.demo',
                color: Colors.amber.shade200,
                child: const SizedBox(
                  width: 80,
                  height: 60,
                  child: Center(child: Text('Colored')),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('ColoredBox', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomPhysicalModel
          TomColumn(
            children: [
              TomPhysicalModel(
                tomId: 'physicalModel.demo',
                elevation: 8,
                color: Colors.white,
                shadowColor: Colors.black,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 80,
                  height: 60,
                  child: Center(child: Text('Physical')),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('PhysicalModel', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomPhysicalShape
          TomColumn(
            children: [
              TomPhysicalShape(
                tomId: 'physicalShape.demo',
                clipper: const ShapeBorderClipper(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                elevation: 6,
                color: Colors.teal.shade100,
                child: const SizedBox(
                  width: 80,
                  height: 60,
                  child: Center(child: Text('Shape')),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('PhysicalShape', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Transforms & Position
  // ===========================================================================

  Widget _buildTransformSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.transforms',
      child: TomWrap(
        spacing: 32,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          // TomTransform
          TomColumn(
            children: [
              TomSizedBox(
                width: 80,
                height: 80,
                child: TomTransform(
                  tomId: 'transform.demo',
                  transform: Matrix4.rotationZ(0.2),
                  alignment: Alignment.center,
                  child: TomContainer(
                    color: Colors.indigo.shade200,
                    child: const Center(child: Text('Rotate')),
                  ),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('Transform', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomRotatedBox
          TomColumn(
            children: [
              TomRotatedBox(
                tomId: 'rotatedBox.demo',
                quarterTurns: 1,
                child: TomContainer(
                  width: 80,
                  height: 40,
                  color: Colors.green.shade200,
                  child: const Center(child: Text('Quarter')),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('RotatedBox', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomFractionalTranslation
          TomColumn(
            children: [
              TomSizedBox(
                width: 100,
                height: 70,
                child: TomStack(
                  children: [
                    TomContainer(
                      width: 60,
                      height: 40,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Text('Base', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    TomFractionalTranslation(
                      tomId: 'fractional.demo',
                      translation: const Offset(0.5, 0.5),
                      child: TomContainer(
                        width: 60,
                        height: 40,
                        color: Colors.orange.shade300,
                        child: const Center(
                          child:
                              Text('Offset', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('Fractional', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomConstraintsTransformBox
          TomColumn(
            children: [
              TomContainer(
                width: 100,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: TomConstraintsTransformBox(
                  tomId: 'constraintsTransform.demo',
                  constraintsTransform: ConstraintsTransformBox.unconstrained,
                  child: TomContainer(
                    width: 80,
                    height: 40,
                    color: Colors.pink.shade200,
                    child: const Center(
                      child: Text('Free', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('Constraints', style: TextStyle(fontSize: 11)),
            ],
          ),
          // TomSizedOverflowBox
          TomColumn(
            children: [
              TomContainer(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: TomSizedOverflowBox(
                  tomId: 'sizedOverflow.demo',
                  size: const Size(80, 40),
                  child: TomContainer(
                    width: 100,
                    height: 60,
                    color: Colors.cyan.shade200.withValues(alpha: 0.7),
                    child: const Center(
                      child:
                          Text('Overflow', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
              ),
              TomSizedBox(height: 4),
              const Text('SizedOverflow', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Multi-child Layout
  // ===========================================================================

  Widget _buildOverflowBarSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.overflowBar',
      child: TomOverflowBar(
        tomId: 'overflowBar.demo',
        spacing: 8,
        overflowSpacing: 8,
        children: [
          TomElevatedButton(
            onPressed: () {},
            child: const Text('Action 1'),
          ),
          TomOutlinedButton(
            onPressed: () {},
            child: const Text('Action 2'),
          ),
          TomTextButton(
            onPressed: () {},
            child: const Text('Action 3'),
          ),
          TomFilledButton(
            onPressed: () {},
            child: const Text('Action 4'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.flow',
      child: TomSizedBox(
        height: 100,
        child: TomFlow(
          tomId: 'flow.demo',
          delegate: _CircleFlowDelegate(),
          children: List.generate(
            6,
            (i) => TomContainer(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.primaries[i % Colors.primaries.length]
                    .shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 5: Custom Layout & Paint
  // ===========================================================================

  Widget _buildCustomPaintSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.customPaint',
      child: TomSizedBox(
        height: 100,
        child: TomCustomPaint(
          tomId: 'customPaint.demo',
          painter: _GridPainter(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          child: const Center(
            child: Text('CustomPaint with grid painter'),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomLayoutSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.customLayout',
      child: TomSizedBox(
        height: 100,
        child: TomCustomSingleChildLayout(
          tomId: 'customSingleChild.demo',
          delegate: _CenterOffsetDelegate(),
          child: TomContainer(
            width: 120,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('Custom positioned')),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 6: Grid & Expansion
  // ===========================================================================

  Widget _buildGridTileSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.gridTile',
      child: TomSizedBox(
        height: 220,
        child: TomGridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          childrenDelegate: SliverChildListDelegate([
            TomGridTile(
              tomId: 'gridTile.1',
              header: TomGridTileBar(
                tomId: 'gridTileBar.header',
                backgroundColor: Colors.black45,
                title: const Text('Header'),
              ),
              footer: TomGridTileBar(
                tomId: 'gridTileBar.footer',
                backgroundColor: Colors.black45,
                title: const Text('Footer'),
                trailing: const Icon(Icons.star, color: Colors.white),
              ),
              child: TomContainer(color: Colors.blue.shade200),
            ),
            TomGridTile(
              tomId: 'gridTile.2',
              footer: TomGridTileBar(
                tomId: 'gridTileBar.footer2',
                backgroundColor: Colors.black45,
                leading: const Icon(Icons.photo, color: Colors.white),
                title: const Text('Image Title'),
                subtitle: const Text('Subtitle'),
              ),
              child: TomContainer(color: Colors.green.shade200),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildExpansionPanelSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.expansionPanel',
      child: TomExpansionPanelList(
        tomId: 'expansionPanelList.demo',
        expansionCallback: (index, isExpanded) {
          setState(() {
            if (index == 0) _panel1Expanded = isExpanded;
            if (index == 1) _panel2Expanded = isExpanded;
          });
        },
        children: [
          TomExpansionPanel(
            tomId: 'panel.1',
            headerBuilder: (context, isExpanded) => const ListTile(
              title: Text('Panel 1'),
            ),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('TomExpansionPanel body content for panel 1'),
            ),
            isExpanded: _panel1Expanded,
          ).toPanel(),
          TomExpansionPanel(
            tomId: 'panel.2',
            headerBuilder: (context, isExpanded) => const ListTile(
              title: Text('Panel 2'),
            ),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('TomExpansionPanel body content for panel 2'),
            ),
            isExpanded: _panel2Expanded,
            canTapOnHeader: true,
          ).toPanel(),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 7: Sliver Extras
  // ===========================================================================

  Widget _buildSliverExtrasSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.sliverExtras',
      child: TomColumn(
        children: [
          TomRow(
            children: [
              const Text('Toggle SliverOffstage: '),
              Switch(
                value: _sliverOffstage,
                onChanged: (v) => setState(() => _sliverOffstage = v),
              ),
            ],
          ),
          TomSizedBox(height: 8),
          TomSizedBox(
            height: 200,
            child: TomCustomScrollView(
              slivers: [
                TomSliverResizingHeader(
                  tomId: 'sliverResizing.demo',
                  child: TomContainer(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Center(
                      child: Text('SliverResizingHeader — resize by scrolling'),
                    ),
                  ),
                ),
                TomSliverOffstage(
                  tomId: 'sliverOffstage.demo',
                  offstage: _sliverOffstage,
                  sliver: TomSliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ListTile(
                        title: Text('Sliver item $index'),
                      ),
                      childCount: 10,
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
}

// =============================================================================
// Custom Delegates
// =============================================================================

/// A simple FlowDelegate that arranges children in a line with spacing.
class _CircleFlowDelegate extends FlowDelegate {
  @override
  void paintChildren(FlowPaintingContext context) {
    double dx = 0;
    for (int i = 0; i < context.childCount; i++) {
      final childSize = context.getChildSize(i) ?? Size.zero;
      context.paintChild(i, transform: Matrix4.translationValues(dx, 20, 0));
      dx += childSize.width + 12;
    }
  }

  @override
  bool shouldRepaint(covariant FlowDelegate oldDelegate) => false;

  @override
  Size getSize(BoxConstraints constraints) =>
      Size(constraints.maxWidth, 100);
}

/// A simple CustomPainter that draws a grid pattern.
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A simple SingleChildLayoutDelegate that offsets the child slightly.
class _CenterOffsetDelegate extends SingleChildLayoutDelegate {
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(
      (size.width - childSize.width) / 2 + 20,
      (size.height - childSize.height) / 2,
    );
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) => false;
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
