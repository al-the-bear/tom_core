import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  runApp(const AclDemoApp());
}

class AclDemoApp extends StatelessWidget {
  const AclDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACL Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoTabsPage(),
    );
  }
}

class DemoTabsPage extends StatelessWidget {
  const DemoTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ACL Components'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Acl'),
              Tab(text: 'Roadmap'),
            ],
          ),
        ),
        body: const TabBarView(children: [_AclTab(), _RoadmapTab()]),
      ),
    );
  }
}

class _AclTab extends StatelessWidget {
  const _AclTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _DemoTile(
          title: 'Basic Row Layout',
          description: 'Simple horizontal arrangement of components',
          screen: BasicRowDemo(),
        ),
        _DemoTile(
          title: 'Multiple Rows',
          description: 'Vertical stacking with newRow()',
          screen: MultiRowDemo(),
        ),
        _DemoTile(
          title: 'Row Alignment',
          description: 'LEFT, CENTER, RIGHT alignment',
          screen: AlignmentDemo(),
        ),
        _DemoTile(
          title: 'All Dimensions',
          description: 'Full-window layout: expandX + expandY + both combined',
          fullScreen: true,
          screen: const AllDimensionsDemo(),
        ),
        _DemoTile(
          title: 'Expand Flags',
          description: 'EXPANDX, EXPANDY for flexible layouts',
          screen: ExpandDemo(),
        ),
        _DemoTile(
          title: 'Spacing & Gaps',
          description: 'Component and row spacing',
          screen: SpacingDemo(),
        ),
        _DemoTile(
          title: 'Size Constraints',
          description: 'Minimum, preferred and maximum size behavior',
          screen: SizeConstraintsDemo(),
        ),
        _DemoTile(
          title: 'Reference Constraints',
          description:
              'same-size plus left/right/center/vertical alignment to references',
          screen: ReferenceConstraintsDemo(),
        ),
        _DemoTile(
          title: 'Cross-Row Alignment',
          description: 'Reference other rows: alignTopToBottom, alignRightToRight, etc.',
          screen: ConveniencePlacementDemo(),
        ),
        _DemoTile(
          title: 'Mixed Placement Playground',
          description: 'Cross-row alignment combined with regular rows, sameSize, expandX',
          screen: MixedPlacementPlaygroundDemo(),
        ),
        _DemoTile(
          title: 'Responsive Layout',
          description:
              'Shrink/grow between preferred and minimum sizes as the window resizes',
          screen: ResponsiveConvenienceDemo(),
        ),
        _DemoTile(
          title: 'Character Width Sizing',
          description: 'setPWidthInChars / setMWidthInChars / setXWidthInChars for character-based field widths',
          screen: CharacterWidthSizingDemo(),
        ),
        _DemoTile(
          title: 'Border Styles',
          description: 'Various border styles and border inset examples',
          screen: BorderStylesDemo(),
        ),
        _DemoTile(
          title: 'Groups (Titled Borders)',
          description: 'Group boxes with titles',
          screen: GroupsDemo(),
        ),
        _DemoTile(
          title: 'Bordered Groups',
          description: 'Single-line borders with topLeft / topCenter / topRight titles',
          screen: BorderedGroupsDemo(),
        ),
        _DemoTile(
          title: 'Nested Containers',
          description: 'Containers within containers',
          screen: NestedContainersDemo(),
        ),
        _DemoTile(
          title: 'Form Layout',
          description: 'Typical form layout pattern',
          screen: FormLayoutDemo(),
        ),
        _DemoTile(
          title: 'Complex Layout',
          description: 'Combined features demonstration',
          screen: ComplexLayoutDemo(),
        ),
        _DemoTile(
          title: 'Comprehensive Form',
          description: '2-column form with gap slots, gap rows, separators, cross-row alignment',
          screen: ComprehensiveFormDemo(),
        ),
        _DemoTile(
          title: 'Dynamic Resize Demo',
          description: 'Resize window to see layout adapt',
          screen: DynamicResizeDemo(),
        ),
        _DemoTile(
          title: 'Fluent Builder API',
          description: 'Using AclBuilder',
          screen: FluentApiDemo(),
        ),
      ],
    );
  }
}

class _RoadmapTab extends StatelessWidget {
  const _RoadmapTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Future tab for additional component families. '
              'Next demos can be added here as we extend tom_flutter_ui.',
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String title;
  final String description;
  final Widget screen;
  final bool fullScreen;

  const _DemoTile({
    required this.title,
    required this.description,
    required this.screen,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DemoScaffold(
              title: title,
              child: screen,
              fullScreen: fullScreen,
            ),
          ),
        ),
      ),
    );
  }
}

class DemoScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool fullScreen;

  const DemoScaffold({
    super.key,
    required this.title,
    required this.child,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: fullScreen
          ? child
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
    );
  }
}

class BasicRowDemo extends StatelessWidget {
  const BasicRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic row with three components:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const _DemoBox('A', Colors.red))
            .append(const _DemoBox('B', Colors.green))
            .append(const _DemoBox('C', Colors.blue))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder()
    .append(Widget_A)
    .append(Widget_B)
    .append(Widget_C)
    .build()
'''),
      ],
    );
  }
}

class MultiRowDemo extends StatelessWidget {
  const MultiRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multiple rows using newRow():',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const _DemoBox('Row 1 - A', Colors.red))
            .append(const _DemoBox('Row 1 - B', Colors.green))
            .newRow()
            .append(const _DemoBox('Row 2 - A', Colors.blue))
            .append(const _DemoBox('Row 2 - B', Colors.orange))
            .append(const _DemoBox('Row 2 - C', Colors.purple))
            .newRow()
            .append(const _DemoBox('Row 3', Colors.teal))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder()
    .append(Widget_1A)
    .append(Widget_1B)
    .newRow()
    .append(Widget_2A)
    .append(Widget_2B)
    .append(Widget_2C)
    .newRow()
    .append(Widget_3)
    .build()
'''),
      ],
    );
  }
}

class AlignmentDemo extends StatelessWidget {
  const AlignmentDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Row alignment options:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 140,
          child: AclBuilder()
              .append(const _DemoBox('Left', Colors.red))
              .append(const _DemoBox('Aligned', Colors.green))
              .setRowAlignment(RowAlignment.left)
              .newRow(dist: 8)
              .append(const _DemoBox('Center', Colors.blue))
              .append(const _DemoBox('Aligned', Colors.orange))
              .setRowAlignment(RowAlignment.center)
              .newRow(dist: 8)
              .append(const _DemoBox('Right', Colors.purple))
              .append(const _DemoBox('Aligned', Colors.teal))
              .setRowAlignment(RowAlignment.right)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder()
    .append(Widget_A).append(Widget_B)
    .setRowAlignment(RowAlignment.left)
    .newRow()
    .append(Widget_C).append(Widget_D)
    .setRowAlignment(RowAlignment.center)
    .newRow()
    .append(Widget_E).append(Widget_F)
    .setRowAlignment(RowAlignment.right)
    .build()
'''),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Dimensions Demo
// Fills the full window. Single ACL layout demonstrating all three expand
// patterns from the Expand Flags demo combined into one container:
//   Row 1 — single ExpandX between two fixed ends
//   Row 2 — three equal ExpandX panels
//   Row 3 — ExpandY row: fixed sidebars + ExpandX+Y centre (fills remaining height)
// ─────────────────────────────────────────────────────────────────────────────
class AllDimensionsDemo extends StatelessWidget {
  const AllDimensionsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AclBuilder()
          // ── Row 1: single ExpandX — fixed left, expand centre, fixed right ──
          .append(const _DemoBox('Fixed L\n(140)', Colors.blueGrey))
          .setPSize(140, 44)
          .append(const _DemoBox('ExpandX — fills remaining width', Colors.lightGreen))
          .setPSize(200, 44)
          .setAttr(AclFlags.expandX)
          .append(const _DemoBox('Fixed R\n(100)', Colors.blueGrey))
          .setPSize(100, 44)
          // ── Row 2: three equal ExpandX panels ────────────────────────────
          .newRow(dist: 4)
          .append(const _DemoBox('ExpandX #1', Colors.red))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          .append(const _DemoBox('ExpandX #2', Colors.green))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          .append(const _DemoBox('ExpandX #3', Colors.blue))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          // ── Row 3: expandY — fills all remaining height ───────────────────
          // Left sidebar and right panel: fixed width, expandY (fill row height).
          // Centre: expandX + expandY (fills remaining width AND height).
          .newRow(dist: 4)
          .append(
            Container(
              color: Colors.indigo.withAlpha(50),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Left Sidebar\n(fixed width,\nexpandY)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(140, 200)
          .setMSize(80, 100)
          .setAttr(AclFlags.expandY)
          .append(
            Container(
              color: Colors.lightBlue.withAlpha(60),
              alignment: Alignment.center,
              child: const Text(
                'ExpandX + ExpandY\n(fills remaining width AND height)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(200, 200)
          .setMSize(100, 100)
          .setAttr(AclFlags.expand)
          .append(
            Container(
              color: Colors.deepOrange.withAlpha(50),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Right Panel\n(fixed width,\nexpandY)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(120, 200)
          .setMSize(60, 100)
          .setAttr(AclFlags.expandY)
          .build(),
    );
  }
}

class ExpandDemo extends StatelessWidget {
  const ExpandDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EXPANDX - horizontal expansion:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          child: AclBuilder()
              .append(const _DemoBox('Fixed', Colors.red))
              .append(const _DemoBox('EXPANDX', Colors.green))
              .setAttr(AclFlags.expandX)
              .append(const _DemoBox('Fixed', Colors.blue))
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Multiple EXPANDX (equal distribution):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          child: AclBuilder()
              .append(const _DemoBox('Expand 1', Colors.red))
              .setAttr(AclFlags.expandX)
              .append(const _DemoBox('Expand 2', Colors.green))
              .setAttr(AclFlags.expandX)
              .append(const _DemoBox('Expand 3', Colors.blue))
              .setAttr(AclFlags.expandX)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'EXPANDY - vertical expansion (in sized container):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 200,
          child: AclBuilder()
              .append(const _DemoBox('Fixed Row', Colors.red))
              .newRow()
              .append(
                Container(
                  color: Colors.green.withAlpha(70),
                  alignment: Alignment.center,
                  child: const Text('EXPANDY Row'),
                ),
              )
              .setAttr(AclFlags.expand)
              .newRow()
              .append(const _DemoBox('Fixed Row', Colors.blue))
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
// EXPANDX
AclBuilder()
    .append(fixed_widget)
    .append(expandable_widget)
    .setAttr(AclFlags.expandX)
    .build()

// EXPANDY
AclBuilder()
    .append(widget)
    .setAttr(AclFlags.expandY)
    .build()

// Both
AclBuilder()
    .append(widget)
    .setAttr(AclFlags.expandX | AclFlags.expandY)
    // or use: .setAttr(AclFlags.expand)
    .build()
'''),
      ],
    );
  }
}

class SpacingDemo extends StatelessWidget {
  const SpacingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Component spacing with dist parameter:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const _DemoBox('A', Colors.red))
            .append(const _DemoBox('B (10px gap)', Colors.green), dist: 10)
            .append(const _DemoBox('C (20px gap)', Colors.blue), dist: 20)
            .append(const _DemoBox('D (30px gap)', Colors.orange), dist: 30)
            .build(),
        const SizedBox(height: 24),
        const Text(
          'Row spacing with newRow(dist:):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const _DemoBox('Row 1', Colors.red))
            .newRow(dist: 10)
            .append(const _DemoBox('Row 2 (10px gap)', Colors.green))
            .newRow(dist: 20)
            .append(const _DemoBox('Row 3 (20px gap)', Colors.blue))
            .newRow(dist: 30)
            .append(const _DemoBox('Row 4 (30px gap)', Colors.orange))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
// Component spacing
AclBuilder()
    .append(Widget_A)
    .append(Widget_B, dist: 10)  // 10px gap before B
    .build()

// Row spacing
AclBuilder()
    .append(Widget_Row1)
    .newRow(dist: 20)  // 20px gap before next row
    .append(Widget_Row2)
    .build()
'''),
      ],
    );
  }
}

class SizeConstraintsDemo extends StatelessWidget {
  const SizeConstraintsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resize the window left/right. Components shrink proportionally toward M: — they never go below it.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'M = minimum  |  P = preferred  |  X = maximum. '
          'Labels in each box show the configured constraints.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Three proportional panels (no expandX) ────────────────────────
        const Text(
          'Horizontal: three panels shrink proportionally (no expandX)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const _DemoBox('Alpha\nM:80 P:200 X:280', Colors.teal))
              .setMSize(80, 40).setPSize(200, 40).setXSize(280, 40)
              .append(const _DemoBox('Beta\nM:60 P:160 X:220', Colors.indigo), dist: 6)
              .setMSize(60, 40).setPSize(160, 40).setXSize(220, 40)
              .append(const _DemoBox('Gamma\nM:50 P:120 X:160', Colors.orange), dist: 6)
              .setMSize(50, 40).setPSize(120, 40).setXSize(160, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'All three shrink proportionally toward M:. Once any hits M: only the others continue shrinking.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Wide + narrow + fixed (asymmetric ranges) ─────────────────────
        const Text(
          'Horizontal: asymmetric panels — one fixed, others proportional',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const _DemoBox('Wide\nM:120 P:360 X:460', Colors.purple))
              .setMSize(120, 40).setPSize(360, 40).setXSize(460, 40)
              .append(const _DemoBox('Medium\nM:80 P:200 X:240', Colors.blueGrey), dist: 6)
              .setMSize(80, 40).setPSize(200, 40).setXSize(240, 40)
              .append(const _DemoBox('Fixed\nM:80 P:80 X:80', Colors.red), dist: 6)
              .setMSize(80, 40).setPSize(80, 40).setXSize(80, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fixed (M=P=X=80) never shrinks. Wide and Medium share remaining shrink proportionally.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── expandX: one component fills all remaining space ──────────────
        const Text(
          'Horizontal + expandX: center component grows to fill remaining width',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const _DemoBox('Fixed\nM:80 P:120 X:120', Colors.blueGrey))
              .setMSize(80, 40).setPSize(120, 40).setXSize(120, 40)
              .append(const _DemoBox('ExpandX\nM:120 P:300 X:∞', Colors.lightGreen), dist: 6)
              .setMSize(120, 40).setPSize(300, 40)
              .setAttr(AclFlags.expandX)
              .append(const _DemoBox('Fixed\nM:60 P:90 X:90', Colors.cyan), dist: 6)
              .setMSize(60, 40).setPSize(90, 40).setXSize(90, 40)
              .build(),
        ),
        const SizedBox(height: 16),

        // ── Vertical: expandY fills bounded height ────────────────────────
        const Text(
          'Vertical: expandY fills height — resize by dragging window taller/shorter',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ResizableBox(
          initialHeight: 200,
          child: AclBuilder()
              .append(const _DemoBox('Row 1 – fixed\nM:60 P:60', Colors.orange))
              .setMSize(0, 60).setPSize(400, 60)
              .setAttr(AclFlags.expandX)
              .newRow(dist: 4)
              .append(const _DemoBox('Row 2 – expandY\nM:40 P:100', Colors.lightGreen))
              .setMSize(0, 40).setPSize(400, 100)
              .setAttr(AclFlags.expand)
              .newRow(dist: 4)
              .append(const _DemoBox('Row 3 – fixed\nM:40 P:40', Colors.teal))
              .setMSize(0, 40).setPSize(400, 40)
              .setAttr(AclFlags.expandX)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Row 1 and Row 3 keep fixed height. Row 2 (expandY) absorbs all extra vertical space.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

class ReferenceConstraintsDemo extends StatefulWidget {
  const ReferenceConstraintsDemo({super.key});

  @override
  State<ReferenceConstraintsDemo> createState() =>
      _ReferenceConstraintsDemoState();
}

class _ReferenceConstraintsDemoState extends State<ReferenceConstraintsDemo> {
  @override
  Widget build(BuildContext context) {
    final anchorLabel = const SizedBox(width: 140, child: Text('Anchor Label'));
    final anchorField = const SizedBox(
      width: 280,
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Anchor Field',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
    final anchorButton = ElevatedButton(
      onPressed: () {},
      child: const Text('Anchor Action'),
    );
    final centerAnchor = const SizedBox(
      width: 320,
      child: _DemoBox('Anchor (center)', Colors.indigo),
    );
    final verticalAnchor = const SizedBox(
      width: 220,
      child: _DemoBox('Anchor Y', Colors.deepPurple),
    );
    final topBottomAnchor = const SizedBox(
      width: 220,
      child: _DemoBox('Anchor (top->bottom)', Colors.deepOrange),
    );
    final bottomTopAnchor = const SizedBox(
      width: 220,
      child: _DemoBox('Anchor (bottom->top)', Colors.blueGrey),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Old + new reference constraints: anchors in the first row define width/edges; later rows link size and alignment.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _ResizableBox(
          initialHeight: 280,
          child: AclBuilder()
              .append(anchorLabel)
              .append(anchorField, dist: 12)
              .newRow(dist: 10)
              .append(const SizedBox(child: Text('Linked Label A')))
              .sameWidthAs(anchorLabel)
              .alignLeftToLeft(anchorLabel)
              .append(
                const SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Aligned to right anchor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                dist: 12,
              )
              .sameWidthAs(anchorField)
              .sameHeightAs(anchorField)
              .alignRightToRight(anchorField)
              .newRow(dist: 10)
              .append(const SizedBox(child: Text('Linked Label B')))
              .sameWidthAs(anchorLabel)
              .alignLeftToLeft(anchorLabel)
              .append(
                const SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Aligned to anchor + 16px',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                dist: 12,
              )
              .sameWidthAs(anchorField)
              .sameHeightAs(anchorField)
              .alignRightToRight(anchorField, gap: 16)
              .newRow(dist: 14)
              .append(anchorButton)
              .setPSize(220, 40)
              .newRow(dist: 8)
              .append(
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Same Size Button'),
                ),
              )
              .sameWidthAs(anchorButton)
              .sameHeightAs(anchorButton)
              .build(),
        ),
        const SizedBox(height: 10),
        const Text(
          'Expected: labels match anchor label width; first linked field right-edge matches anchor field; second linked field is offset by +16 from that edge; last button mirrors anchor action size.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Center-to-center reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .append(centerAnchor)
              .setPSize(320, 48)
              .setMSize(50, 48)
              .setXSize(320, 48)
              .newRow(dist: 10)
              .append(const _DemoBox('Follower', Colors.cyan))
              .setPSize(140, 40)
              .alignCenterToCenter(centerAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower center X equals anchor field center X.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical reference alignment (single-row, center Y to center Y):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 80,
          child: AclBuilder()
              .append(verticalAnchor)
              .setPSize(220, 70)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: _DemoBox('Follower Y', Colors.teal),
                ),
              )
              .setPSize(220, 40)
              .alignMiddleToMiddle(verticalAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower center Y aligns with anchor Y center without jumping.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical alignTopToBottom reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 110,
          child: AclBuilder()
              .append(topBottomAnchor)
              .setPSize(220, 64)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: _DemoBox('Follower top->anchor bottom', Colors.green),
                ),
              )
              .setPSize(220, 36)
              .alignTopToBottom(topBottomAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower top edge aligns to anchor bottom edge.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical alignBottomToTop reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 110,
          child: AclBuilder()
              .append(bottomTopAnchor)
              .setPSize(220, 64)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: _DemoBox('Follower bottom->anchor top', Colors.purple),
                ),
              )
              .setPSize(220, 36)
              .alignBottomToTop(bottomTopAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower bottom edge aligns to anchor top edge.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Row constraint rules for alignX* and alignY*:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.red.shade300)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✗  INVALID — alignX* with same-row reference (throws):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor and follower are in the SAME row\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(anchor)   // ERROR: anchor is in same row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Text(
                '✗  INVALID — alignY* with different-row reference (throws):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor is in row 0, follower is in row 1\n'
                '  .append(follower)\n'
                '  .alignTopToTop(anchor)     // ERROR: anchor is in a different row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — alignX* with different-row reference:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor in row 0, follower in row 1\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(anchor)   // OK: anchor is in a different row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — alignY* with same-row reference:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // tallRef and follower are in the SAME row\n'
                '  .append(follower)\n'
                '  .alignTopToTop(tallRef)    // OK: tallRef is in the same row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — both alignX* and alignY* on the same component:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // xAnchor in row 0, yRef in same row as follower (row 1)\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(xAnchor)  // X ref in different row — OK\n'
                '  .alignTopToTop(yRef)        // Y ref in same row — OK',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Summary: alignX* requires a different-row reference; alignY* requires a same-row reference. '
          'Both can be set on the same component as long as each reference satisfies its row constraint.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class CharacterWidthSizingDemo extends StatelessWidget {
  const CharacterWidthSizingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final monoStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final charWidth = _measureWidthInChars(context, 1, style: monoStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Character-based width sizing (setPWidthInChars-style):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Using setPWidthInChars + setMWidthInChars + setXWidthInChars. Each row has a different min/preferred/max so you can see fields resize as you change the window width.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _ResizableBox(
          initialHeight: 180,
          child: AclBuilder()
              .append(const SizedBox(width: 90, child: Text('12 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(12, charWidth: charWidth, height: 40)
              .setMWidthInChars(6, charWidth: charWidth)
              .setXWidthInChars(24, charWidth: charWidth)
              .newRow(dist: 10)
              .append(const SizedBox(width: 90, child: Text('24 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(24, charWidth: charWidth, height: 40)
              .setMWidthInChars(12, charWidth: charWidth)
              .setXWidthInChars(48, charWidth: charWidth)
              .newRow(dist: 10)
              .append(const SizedBox(width: 90, child: Text('36 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(36, charWidth: charWidth, height: 40)
              .setMWidthInChars(18, charWidth: charWidth)
              .setXWidthInChars(72, charWidth: charWidth)
              .build(),
        ),
        const SizedBox(height: 12),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
    final charWidth = measureWidthInChars(context, 1, style: monospaceStyle);

AclBuilder()
    .append(TextField(style: monospaceStyle))
      .setPWidthInChars(24, charWidth: charWidth, height: 40)  // preferred
      .setMWidthInChars(12, charWidth: charWidth)              // min = 12 chars
      .setXWidthInChars(48, charWidth: charWidth)              // max = 48 chars
    .build();
// No expandX needed: surplus space is automatically distributed up to max.
// expandX only needed to claim ALL remaining surplus exclusively.
'''),
      ],
    );
  }
}

class ConveniencePlacementDemo extends StatelessWidget {
  const ConveniencePlacementDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final tallRef = const SizedBox(
      width: 160,
      child: _DemoBox('Tall Ref\n(h=80)', Colors.indigo),
    );
    final rowRef = const SizedBox(
      width: 200,
      child: _DemoBox('Row-1 Anchor', Colors.deepPurple),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cross-row alignment — components in one row reference anchor components in another:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // ── Group 1: same-row vertical alignment (Y only) ─────────────────
        const Text(
          'Same-row vertical alignment (Y only) — one alignment per component:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .append(tallRef)
              .setPSize(160, 80)
              // Top-align to Tall Ref
              .append(const SizedBox(width: 100, child: _DemoBox('Top\nalign', Colors.teal)), dist: 8)
              .setPSize(100, 36)
              .alignTopToTop(tallRef)
              // Middle-align to Tall Ref
              .append(const SizedBox(width: 120, child: _DemoBox('Middle\nalign', Colors.orange)), dist: 8)
              .setPSize(120, 36)
              .alignMiddleToMiddle(tallRef)
              // Bottom-align to Tall Ref
              .append(const SizedBox(width: 100, child: _DemoBox('Bottom\nalign', Colors.green)), dist: 8)
              .setPSize(100, 36)
              .alignBottomToBottom(tallRef)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Each small box uses one alignY* call to snap its edge to the Tall Ref\'s corresponding edge.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Group 2: cross-row horizontal alignment (X only) ─────────────
        const Text(
          'Cross-row horizontal alignment (X only) — row 2 fields snap to row 1 anchor edges:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              // Row 1: anchor
              .append(rowRef)
              .setPSize(200, 44)
              // Row 2: two fields cross-row aligned to anchor
              .newRow(dist: 8)
              .append(const SizedBox(width: 90, child: _DemoBox('←Left to\nAnchor\'s left', Colors.lightBlue)))
              .setPSize(90, 44)
              .alignLeftToLeft(rowRef)
              .append(const SizedBox(width: 90, child: _DemoBox('Right to\nAnchor\'s right→', Colors.pink)), dist: 8)
              .setPSize(90, 44)
              .alignRightToRight(rowRef)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Row 2 components each use one alignX* call. Left box\'s left edge == Anchor\'s left; '
          'Right box\'s right edge == Anchor\'s right.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Group 3: expandX ──────────────────────────────────────────────
        const Text(
          'expandX — two components share available row width:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const _DemoBox('Seventh expandX', Colors.green))
              .expandX()
              .append(const _DemoBox('Eighth expandX', Colors.red), dist: 8)
              .expandX()
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Rule: alignX* requires a different-row reference (cross-row horizontal); '
          'alignY* requires a same-row reference (same-row vertical). '
          'Both may be set on one component if each reference satisfies its row constraint.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

class MixedPlacementPlaygroundDemo extends StatelessWidget {
  const MixedPlacementPlaygroundDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formAnchor = const SizedBox(
      width: 220,
      child: _DemoBox('Form Anchor\n(ref)', Colors.deepPurple),
    );
    const regularBox = _DemoBox('Regular (+dist:12)', Colors.orange);
    final tallBox = const SizedBox(
      width: 140,
      child: _DemoBox('Tall\n(h=70)', Colors.blueGrey),
    );
    // Row 4 buttons — captured so Row 5 can mirror them via sameSize().
    final primaryAction =
        ElevatedButton(onPressed: () {}, child: const Text('Primary Action'));
    final secondaryAction =
        OutlinedButton(onPressed: () {}, child: const Text('Secondary'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multi-row layout combining cross-row alignment, regular rows, and sameSize():',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 300,
          child: AclBuilder()
              // Row 1: anchor (pref=220, min=140, no max) + regular (pref=120, min=70, no max)
              // Both resize freely — note intentionally different min/pref values.
              .append(formAnchor)
              .setPSize(220, 50)
              .setMSize(140, 40)
              .append(regularBox, dist: 12)
              .setPSize(120, 40)
              .setMSize(70, 40)
              // Row 2: two components each using cross-row X alignment (no overlap)
              //   Right→Right: right edge of box aligns to formAnchor's right
              //   Left→Regular: left edge of box aligns to regularBox's left
              .newRow(dist: 8)
              .append(const SizedBox(width: 160, child: _DemoBox('Right→Right\n(formAnchor)', Colors.indigo)))
              .setPSize(160, 40)
              .alignRightToRight(formAnchor)
              .append(const SizedBox(width: 120, child: _DemoBox('Left→Regular\n(+dist:12)', Colors.teal)), dist: 8)
              .setPSize(120, 40)
              .alignLeftToLeft(regularBox)
              // Row 3: same-row vertical Y alignment (Y only per component)
              .newRow(dist: 8)
              .append(tallBox)
              .setPSize(140, 70)
              .append(const SizedBox(width: 120, child: _DemoBox('Top↑align', Colors.green)), dist: 8)
              .setPSize(120, 36)
              .alignTopToTop(tallBox)
              .append(const SizedBox(width: 120, child: _DemoBox('Bot↓align', Colors.red)), dist: 8)
              .setPSize(120, 36)
              .alignBottomToBottom(tallBox)
              // Row 4: two buttons with intentionally different min/pref/max sizes.
              .newRow(dist: 12)
              .append(primaryAction)
              .setPSize(180, 40)
              .setMSize(100, 40)
              .setXSize(260, 40)
              .append(secondaryAction, dist: 12)
              .setPSize(120, 40)
              .setMSize(70, 40)
              .setXSize(180, 40)
              // Row 5: mirrors of Row 4 using cross-row sameSize().
              // sameSize() on the same row is disallowed by the engine.
              .newRow(dist: 8)
              .append(OutlinedButton(onPressed: () {}, child: const Text('Mirror Primary')))
              .sameSize(primaryAction)
              .append(OutlinedButton(onPressed: () {}, child: const Text('Mirror Secondary')), dist: 12)
              .sameSize(secondaryAction)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Row 2 uses two cross-row X alignments: Right→Right aligns to formAnchor; '
          'Left→Regular aligns to regularBox (no overlap). Row 3 uses same-row alignY. '
          'Row 4 has two buttons with different min/pref/max. '
          'Row 5 mirrors both via cross-row sameSize() — same-row mirroring is disallowed.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive Convenience Demo
// Shows shrink/grow behaviour when preferred > min sizes are set.
// ─────────────────────────────────────────────────────────────────────────────
class ResponsiveConvenienceDemo extends StatelessWidget {
  const ResponsiveConvenienceDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel A: expandX input flanked by fixed labels ──────────────────
        const Text(
          'Panel A — expandX input between fixed labels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Label [pref 120, min 80] | Input [pref 200, min 100, expandX] | Status [pref 100, min 60]. '
          'Resize window: Input grows/shrinks; labels hold preferred until container forces them.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 60,
          child: AclBuilder()
              .append(const _DemoBox('Label', Colors.lightBlue))
              .setPSize(120, 48)
              .setMSize(80, 48)
              .append(const _DemoBox('Input [expandX]', Colors.lightGreen),
                  dist: 8)
              .setPSize(200, 48)
              .setMSize(100, 48)
              .setAttr(AclFlags.expandX)
              .append(const _DemoBox('Status', Colors.orange), dist: 8)
              .setPSize(100, 48)
              .setMSize(60, 48)
              .build(),
        ),
        const SizedBox(height: 20),

        // ── Panel B: three proportional addRight panels, no expandX ─────────
        const Text(
          'Panel B — proportional shrink across three fixed-size panels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Alpha [pref 240, min 80] | Beta [pref 160, min 80] | Gamma [pref 120, min 60]. '
          'Resize window: all three shrink proportionally toward their minimum sizes.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 60,
          child: AclBuilder()
              .append(const _DemoBox('Alpha', Colors.purple))
              .setPSize(240, 48)
              .setMSize(80, 48)
              .append(const _DemoBox('Beta', Colors.teal), dist: 8)
              .setPSize(160, 48)
              .setMSize(80, 48)
              .append(const _DemoBox('Gamma', Colors.red), dist: 8)
              .setPSize(120, 48)
              .setMSize(60, 48)
              .build(),
        ),
        const SizedBox(height: 20),

        // ── Panel C: two-row responsive layout ──────────────────────────────
        const Text(
          'Panel C — two-row layout with responsive sizing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Main [pref 300, min 120] in row 1, Sub [pref 160, min 80] in row 2. '
          'Resize window: both shrink proportionally toward their minimums.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 120,
          child: AclBuilder()
              .append(const _DemoBox('Main', Colors.indigo))
              .setPSize(300, 64)
              .setMSize(120, 48)
              .newRow()
              .append(const _DemoBox('Sub (below-left)', Colors.cyan))
              .setPSize(160, 40)
              .setMSize(80, 40)
              .build(),
        ),
      ],
    );
  }
}

double _measureWidthInChars(
  BuildContext context,
  int chars, {
  TextStyle? style,
}) {
  final painter = TextPainter(
    text: TextSpan(text: 'W' * chars, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

class BorderStylesDemo extends StatelessWidget {
  const BorderStylesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available border styles:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildBorderExample(
          'AclBorderStyle.none()',
          const AclBorderStyle.none(),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Single line',
          const AclBorderStyle(kind: AclBorderKind.solid,
        color: Colors.blueGrey, lineWidth: 2),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Rounded',
          const AclBorderStyle(kind: AclBorderKind.solid,
        rounded: true,
            borderRadius: 10,
            color: Colors.blue,
            lineWidth: 2,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Double line',
          const AclBorderStyle(
            kind: AclBorderKind.solidDouble,
            color: Colors.teal,
            lineWidth: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Horizontal lines',
          const AclBorderStyle(
            kind: AclBorderKind.horizontal,
            color: Colors.brown,
            lineWidth: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Double line rounded',
          const AclBorderStyle(kind: AclBorderKind.solid,
        rounded: true,
            borderRadius: 10,
            color: Colors.purple,
            lineWidth: 2,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Custom border inset (24/8/24/8)',
          const AclBorderStyle(
            rounded: true,
            borderRadius: 10,
            kind: AclBorderKind.solidDouble,
            color: Colors.indigo,
            borderInsets: EdgeInsets.fromLTRB(24, 8, 24, 8),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder()
    .setAclBorderStyle(
      const AclBorderStyle(
        rounded: true,
        kind: AclBorderKind.solidDouble,
        lineWidth: 2,
        color: Colors.blue,
        borderInsets: EdgeInsets.all(8),
      ),
    )
    .append(child)
    .build()
'''),
      ],
    );
  }

  Widget _buildBorderExample(String label, AclBorderStyle style) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Text(label, style: const TextStyle(fontFamily: 'monospace')),
        ),
        Expanded(
          child: AclBuilder()
              .setAclBorderStyle(style)
              .setAclPadding(const EdgeInsets.all(8))
              .append(const Text('Content inside'))
              .build(),
        ),
      ],
    );
  }
}

class GroupsDemo extends StatelessWidget {
  const GroupsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AclBuilder groups - bordered containers with titles:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        AclBuilder(
              title: 'User Information',
              borderStyle: const AclBorderStyle(
                kind: AclBorderKind.solidDouble,
                color: Colors.blueGrey,
              ),
            )
            .append(const SizedBox(width: 80, child: Text('Name:')))
            .append(
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            )
            .expandX()
            .newRow(dist: 8)
            .append(const SizedBox(width: 80, child: Text('Email:')))
            .append(
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            )
            .expandX()
            .build(),
        const SizedBox(height: 16),
        AclBuilder(
              title: 'Settings',
              borderStyle: const AclBorderStyle(
                kind: AclBorderKind.solidDouble,
                rounded: true,
                borderRadius: 10,
                color: Colors.teal,
              ),
              titlePosition: AclTitlePosition.topCenter,
            )
            .append(const Text('Enable notifications'))
            .append(Switch(value: true, onChanged: (_) {}), dist: 10)
            .newRow(dist: 8)
            .append(const Text('Dark mode'))
            .append(Switch(value: false, onChanged: (_) {}), dist: 10)
            .build(),
        const SizedBox(height: 16),
        AclBuilder(
              title: 'Actions',
              borderStyle: const AclBorderStyle(
                kind: AclBorderKind.solid,
                color: Colors.deepPurple,
                rounded: true,
                borderRadius: 8,
              ),
              titlePosition: AclTitlePosition.topRight,
            )
            .append(ElevatedButton(onPressed: () {}, child: const Text('Save')))
            .append(
              OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
              dist: 10,
            )
            .setRowAlignment(RowAlignment.center)
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder(
  title: 'User Information',
  borderStyle: AclBorderStyle(
    kind: AclBorderKind.solidDouble,
  ),
  titlePosition: AclTitlePosition.topLeft,
)
    .append(Label)
    .append(TextField)
    .expandX()
    .build()
'''),
        const SizedBox(height: 24),
        const Text(
          'Title border alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Controls where the title sits vertically on the border line.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── bottom (default) ────────────────────────────────────────────────
        const Text(
          'titleBorderAlign: bottom  (default — label floats above the border)',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        AclBuilder(
          title: 'Bottom Align',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.indigo,
            lineWidth: 1.5,
          ),
          titleBorderAlign: AclTitleBorderAlign.bottom,
        )
            .append(const _DemoBox('Item A', Colors.indigo))
            .append(const _DemoBox('Item B', Colors.indigoAccent), dist: 8)
            .build(),
        const SizedBox(height: 20),

        // ── middle ──────────────────────────────────────────────────────────
        const Text(
          'titleBorderAlign: middle  (label centred on the border line)',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        AclBuilder(
          title: 'Middle Align',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.teal,
            lineWidth: 1.5,
          ),
          titleBorderAlign: AclTitleBorderAlign.middle,
        )
            .append(const _DemoBox('Item A', Colors.teal))
            .append(const _DemoBox('Item B', Colors.tealAccent), dist: 8)
            .build(),
        const SizedBox(height: 20),

        // ── top ─────────────────────────────────────────────────────────────
        const Text(
          'titleBorderAlign: top  (label hangs down from the border)',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        AclBuilder(
          title: 'Top Align',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.deepOrange,
            lineWidth: 1.5,
          ),
          titleBorderAlign: AclTitleBorderAlign.top,
        )
            .append(const _DemoBox('Item A', Colors.deepOrange))
            .append(const _DemoBox('Item B', Colors.orange), dist: 8)
            .build(),
        const SizedBox(height: 20),

        // ── all three side-by-side with rounded double border ───────────────
        const Text(
          'All three with rounded double border:',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AclBuilder(
                title: 'Bottom',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  color: Colors.indigo,
                  rounded: true,
                  borderRadius: 8,
                ),
                titleBorderAlign: AclTitleBorderAlign.bottom,
              ).append(const _DemoBox('Content', Colors.indigo)).build(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AclBuilder(
                title: 'Middle',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  color: Colors.teal,
                  rounded: true,
                  borderRadius: 8,
                ),
                titleBorderAlign: AclTitleBorderAlign.middle,
              ).append(const _DemoBox('Content', Colors.teal)).build(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AclBuilder(
                title: 'Top',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  color: Colors.deepOrange,
                  rounded: true,
                  borderRadius: 8,
                ),
                titleBorderAlign: AclTitleBorderAlign.top,
              ).append(const _DemoBox('Content', Colors.deepOrange)).build(),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bordered Groups Demo
// Single-line borders with various title positions.
// ─────────────────────────────────────────────────────────────────────────────
class BorderedGroupsDemo extends StatelessWidget {
  const BorderedGroupsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Single-line bordered groups with title positions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ── topLeft title ──────────────────────────────────────────────────
        const Text('topLeft title — solid border, square corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        AclBuilder(
          title: 'Contact Details',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.blueGrey,
            lineWidth: 1.5,
          ),
          titlePosition: AclTitlePosition.topLeft,
        )
            .append(const SizedBox(width: 80, child: Text('Name:')))
            .append(
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            )
            .expandX()
            .newRow(dist: 8)
            .append(const SizedBox(width: 80, child: Text('Phone:')))
            .append(
              const TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            )
            .expandX()
            .build(),
        const SizedBox(height: 20),

        // ── topCenter title ────────────────────────────────────────────────
        const Text('topCenter title — solid border, rounded corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        AclBuilder(
          title: '⚙ Preferences',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.teal,
            lineWidth: 1.5,
            rounded: true,
            borderRadius: 10,
          ),
          titlePosition: AclTitlePosition.topCenter,
        )
            .append(const Text('Dark mode'))
            .append(Switch(value: false, onChanged: (_) {}), dist: 8)
            .newRow(dist: 6)
            .append(const Text('Notifications'))
            .append(Switch(value: true, onChanged: (_) {}), dist: 8)
            .build(),
        const SizedBox(height: 20),

        // ── topRight title ─────────────────────────────────────────────────
        const Text('topRight title — solid border, rounded corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        AclBuilder(
          title: 'Actions ✓',
          borderStyle: const AclBorderStyle(
            kind: AclBorderKind.solid,
            color: Colors.deepPurple,
            lineWidth: 1.5,
            rounded: true,
            borderRadius: 8,
          ),
          titlePosition: AclTitlePosition.topRight,
        )
            .append(ElevatedButton(onPressed: () {}, child: const Text('Save')))
            .append(
              OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
              dist: 8,
            )
            .setRowAlignment(RowAlignment.center)
            .build(),
        const SizedBox(height: 24),

        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder(
  title: 'Contact Details',
  borderStyle: AclBorderStyle(
    kind: AclBorderKind.solid,
    color: Colors.blueGrey,
    lineWidth: 1.5,
  ),
  titlePosition: AclTitlePosition.topLeft,  // or topCenter / topRight
)
  .append(label)
  .append(textField).expandX()
  .build()
'''),
      ],
    );
  }
}

class NestedContainersDemo extends StatelessWidget {
  const NestedContainersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nested ACL containers:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNestedPanel(
                        'Left Panel',
                        Colors.blue,
                        AclBuilder()
                            .append(const Text('Item 1'))
                            .newRow(dist: 4)
                            .append(const Text('Item 2'))
                            .newRow(dist: 4)
                            .append(const Text('Item 3'))
                            .build(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNestedPanel(
                        'Right Panel',
                        Colors.green,
                        AclBuilder()
                            .append(const _DemoBox('A', Colors.green))
                            .append(const _DemoBox('B', Colors.green), dist: 4)
                            .newRow(dist: 4)
                            .append(const _DemoBox('C', Colors.green))
                            .expandX()
                            .build(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildNestedPanel(
                'Bottom Panel (spanning full width)',
                Colors.orange,
                const Row(
                  children: [Text('Status: Ready'), Spacer(), Text('100%')],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Deeply nested with groups:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 160,
          child: AclBuilder()
              .setAclPadding(const EdgeInsets.all(12))
              .append(
                AclBuilder(
                      title: 'Outer Group',
                      borderStyle: const AclBorderStyle(
                        kind: AclBorderKind.solidDouble,
                        color: Colors.blueGrey,
                        borderInsets: EdgeInsets.fromLTRB(10, 18, 10, 10),
                      ),
                    )
                    .setAclPadding(const EdgeInsets.all(10))
                    .append(
                      AclBuilder(
                            title: 'Inner Group A',
                            borderStyle: const AclBorderStyle(
                              kind: AclBorderKind.solidDouble,
                              color: Colors.indigo,
                              borderInsets: EdgeInsets.fromLTRB(8, 16, 8, 8),
                            ),
                          )
                          .setAclPadding(const EdgeInsets.all(8))
                          .append(const Text('Content A1'))
                          .newRow(dist: 4)
                          .append(const Text('Content A2'))
                          .build(),
                    )
                    .expandX()
                    .append(
                      AclBuilder(
                            title: 'Inner Group B',
                            borderStyle: const AclBorderStyle(
                              kind: AclBorderKind.solidDouble,
                              color: Colors.teal,
                              borderInsets: EdgeInsets.fromLTRB(8, 16, 8, 8),
                            ),
                          )
                          .setAclPadding(const EdgeInsets.all(8))
                          .append(const Text('Content B1'))
                          .newRow(dist: 4)
                          .append(const Text('Content B2'))
                          .build(),
                      dist: 8,
                    )
                    .expandX()
                    .build(),
              )
              .expandX()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
// Outer container with nested inner containers
AclBuilder()
    .append(
        AclBuilder()
            .setAclBorderStyle(kind: AclBorderKind.solid,
        AclBorderStyle(color: Colors.grey),
            )
            .append(child1)
            .append(child2)
            .build()
    )
    .expandX()
    .append(
        AclBuilder(title: 'Group')
          .append(innerContent)
          .build(),
        dist: 8
    )
    .expandX()
    .build()
'''),
      ],
    );
  }

  Widget _buildNestedPanel(String title, Color color, Widget content) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.shade900,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(8), child: content),
        ],
      ),
    );
  }
}

class FormLayoutDemo extends StatelessWidget {
  const FormLayoutDemo({super.key});

  static const double _lw = 110.0; // label column fixed width
  static const double _fMin = 120.0; // field minimum width

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Typical form layout — all fields use expandX with minimum size. '
          'Resize the window: every field grows/shrinks, labels stay fixed.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 320,
          child: AclBuilder()
              .setAclPadding(const EdgeInsets.all(16))
              // Date row
              .append(const SizedBox(width: _lw, child: Text('Date:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(240, 36)
              .setAttr(AclFlags.expandX)
              // Name row
              .newRow(dist: 12)
              .append(const SizedBox(width: _lw, child: Text('Name:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(320, 36)
              .setAttr(AclFlags.expandX)
              // Cost Center row
              .newRow(dist: 12)
              .append(const SizedBox(width: _lw, child: Text('Cost Center:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'CC-XXX',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(240, 36)
              .setAttr(AclFlags.expandX)
              // Description row
              .newRow(dist: 12)
              .append(
                const SizedBox(
                  width: _lw,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Description:'),
                  ),
                ),
              )
              .append(
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                ),
              )
              .setMSize(_fMin, 72).setPSize(320, 72)
              .setAttr(AclFlags.expandX)
              // Buttons
              .newRow(dist: 20)
              .append(
                ElevatedButton(onPressed: () {}, child: const Text('Submit')),
              )
              .append(
                OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                dist: 10,
              )
              .setRowAlignment(RowAlignment.center)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'All fields use expandX + setMSize() so they grow with the container '
          'but never shrink past their minimum.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class ComplexLayoutDemo extends StatelessWidget {
  const ComplexLayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complex layout combining multiple features:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 400,
          child: AclBuilder()
              .setAclPadding(const EdgeInsets.all(8))
              .append(
                const Text(
                  'Application Form',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              )
              .setRowAlignment(RowAlignment.center)
              .newRow(dist: 16)
              .append(const SizedBox(width: 80, child: Text('User:')))
              .setPSize(80, 36).setMSize(50, 36)
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(120, 36).setPSize(200, 36)
              .gap(weight: 1)
              .append(const SizedBox(width: 80, child: Text('Role:')))
              .setPSize(80, 36).setMSize(50, 36)
              .append(
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text('Select'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'guest', child: Text('Guest')),
                  ],
                  onChanged: (_) {},
                ),
              )
              .setMSize(120, 36).setPSize(180, 36)
              .newRow(dist: 16)
              .append(
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    color: Colors.blue.shade50,
                  ),
                  child: const Center(
                    child: Text('List Area\n(EXPANDX + EXPANDY)'),
                  ),
                ),
              )
              .setAttr(AclFlags.expand)
              .append(
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    color: Colors.green.shade50,
                  ),
                  child: const Center(child: Text('Details Panel\n(EXPANDY)')),
                ),
                dist: 8,
              )
              .setAttr(AclFlags.expandY)
              .newRow(dist: 8)
              .append(const Text('Status: Ready'))
              .append(const Spacer())
              .setAttr(AclFlags.expandX)
              .append(const Text('v1.0.0'))
              .setRowAlignment(RowAlignment.left)
              .build(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comprehensive Form Demo
// ─────────────────────────────────────────────────────────────────────────────
class ComprehensiveFormDemo extends StatelessWidget {
  const ComprehensiveFormDemo({super.key});

  static const double _lw = 110.0; // label column fixed width
  static const double _fMin = 100.0; // field minimum width

  @override
  Widget build(BuildContext context) {
    // Reference widgets — same widget instance used as child AND alignment ref
    final projectCodeField = const TextField(
      decoration: InputDecoration(
        labelText: 'PRJ-001',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    final budgetField = const TextField(
      decoration: InputDecoration(
        labelText: '0.00',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comprehensive Form — 2-column aligned layout, horizontal gap() slots, '
          'vertical gapRow() with separators, and cross-row right-edge alignment.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Resize the window: all fields grow/shrink. '
          '"Duration" field right-aligns to "Code" field above it. '
          '"Approver" field right-aligns to "Budget" field above it.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 500,
          showBorder: false,
          child: AclBuilder(
            title: 'New Project Request',
            borderStyle: const AclBorderStyle.solid(
              color: Colors.blueGrey,
              lineWidth: 1.5,
              rounded: true,
              borderRadius: 8,
            ),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          )
        // ── Section heading ────────────────────────────────────────────────
        .append(const Text(
          'Project Details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
        ))
        .gapRow(weight: 1)

        // ── Row: Project Name | Code ───────────────────────────────────────
        .append(const SizedBox(width: _lw, child: Text('Project Name')))
        .setPSize(_lw, 36).setMSize(70, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'Full project name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(280, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 16))
        .append(const SizedBox(width: 70, child: Text('Code')))
        .setPSize(70, 36).setMSize(50, 36)
        .append(projectCodeField) // ← alignment reference
        .setPSize(120, 36).setMSize(80, 36).setXSize(150, 36)

        // ── Row: Department | Priority ─────────────────────────────────────
        .newRow(dist: 10)
        .append(const SizedBox(width: _lw, child: Text('Department')))
        .setPSize(_lw, 36).setMSize(70, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'e.g. Engineering',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(280, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 16))
        .append(const SizedBox(width: 70, child: Text('Priority')))
        .setPSize(70, 36).setMSize(50, 36)
        .append(DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          hint: const Text('Select'),
          items: const [
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'low', child: Text('Low')),
          ],
          onChanged: (_) {},
        ))
        .sameWidthAs(projectCodeField) // same width as Code field

        // ── Gap row: single separator ─────────────────────────────────────
        .gapRow(
          weight: 4,
          separator: const AclSeparator(
            style: AclSeparatorStyle.single,
            alignment: AclSeparatorAlignment.middle,
          ),
        )

        // ── Row: Start Date | End Date | Duration (right-edge → Code) ─────
        .append(const SizedBox(width: _lw, child: Text('Start Date')))
        .setPSize(_lw, 36).setMSize(70, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(140, 36).setMSize(90, 36).setXSize(180, 36)
        .append(const SizedBox(width: 16))           // fixed inter-column gap
        .append(const SizedBox(width: 70, child: Text('End Date')))
        .setPSize(70, 36).setMSize(50, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(140, 36).setMSize(90, 36).setXSize(180, 36)
        // Extra field on same row: right edge aligns with Code field above
        .append(const SizedBox(width: 44, child: Text(' Days')))
        .append(const TextField(
          decoration: InputDecoration(
            labelText: '#',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(60, 36).setMSize(50, 36).setXSize(75, 36)
        .alignRightToRight(projectCodeField) // ← cross-row alignment

        // ── Row: Description (full width) ──────────────────────────────────
        .newRow(dist: 10)
        .append(
          const SizedBox(
            width: _lw,
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Description'),
            ),
          ),
        )
        .append(const TextField(
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            alignLabelWithHint: true,
          ),
        ))
        .setMSize(_fMin, 72).setPSize(400, 72).setAttr(AclFlags.expandX)

        // ── Double-line separator: section divider ─────────────────────────
        .gapRow(
          weight: 6,
          separator: const AclSeparator(
            style: AclSeparatorStyle.doubleLine,
            alignment: AclSeparatorAlignment.middle,
          ),
        )
        .append(const Text(
          'Budget & Approval',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
        ))
        .gapRow(weight: 1)

        // ── Row: Cost Center | Budget ──────────────────────────────────────
        .append(const SizedBox(width: _lw, child: Text('Cost Center')))
        .setPSize(_lw, 36).setMSize(70, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'CC-XXX',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(220, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 16))
        .append(const SizedBox(width: 90, child: Text('Budget (EUR)')))
        .setPSize(90, 36).setMSize(60, 36)
        .append(budgetField) // ← alignment reference for Approver
        .setPSize(130, 36).setMSize(80, 36).setXSize(160, 36)

        // ── Row: PO Number | Approver (right-edge → Budget) ───────────────
        .newRow(dist: 10)
        .append(const SizedBox(width: _lw, child: Text('PO Number')))
        .setPSize(_lw, 36).setMSize(70, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'PO-XXX',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(220, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 90, child: Text('Approver')), dist: 8)
        .setPSize(90, 36).setMSize(60, 36)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(130, 36).setMSize(80, 36).setXSize(160, 36)
        .alignRightToRight(budgetField) // ← cross-row alignment

        // ── Final gap + footer buttons ──────────────────────────────────────
        .gapRow(weight: 4)
        .gap() // push buttons to center
        .append(const OutlinedButton(onPressed: null, child: Text('Cancel')))
        .append(
          ElevatedButton(onPressed: () {}, child: const Text('  Submit  ')),
          dist: 8,
        )
        .gap() // push buttons to center
        // Minimum container width prevents overflow at very narrow windows.
        .setAclMSize(550, 0)
        .build(),
        ),

        const SizedBox(height: 8),
        const Text(
          'gap() = elastic horizontal spacer  ·  gapRow() = elastic vertical spacer  ·  '
          'gapRow(separator:) = divider line  ·  alignRightToRight(ref) = cross-row alignment  ·  '
          'sameWidthAs(ref) = same width as another component.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

class DynamicResizeDemo extends StatelessWidget {
  const DynamicResizeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthText = constraints.hasBoundedWidth
            ? constraints.maxWidth.toStringAsFixed(0)
            : 'unbounded';
        final heightText = constraints.hasBoundedHeight
            ? constraints.maxHeight.toStringAsFixed(0)
            : 'unbounded';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current size: $widthText x $heightText',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Resize the window to see layouts adapt dynamically.'),
            const SizedBox(height: 16),
            _ResizableBox(
              initialHeight: 300,
              child: AclBuilder()
                  .setAclPadding(const EdgeInsets.all(8))
                  .append(
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue.shade100,
                      child: const Text(
                        'Header - Fixed Height',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .expandX()
                  .newRow(dist: 8)
                  .append(
                    AclBuilder(
                          title: 'Navigation',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(const Text('Menu Item 1'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 2'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 3'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 4'))
                        .build(),
                  )
                  .expandY()
                  .append(
                    AclBuilder(
                          title: 'Content',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(
                          Text(
                            'Width: ${widthText}px',
                            style: const TextStyle(fontSize: 18),
                          ),
                        )
                        .newRow(dist: 8)
                        .append(
                          const Text(
                            'This area expands to fill available space. '
                            'Try resizing the window!',
                          ),
                        )
                        .build(),
                    dist: 8,
                  )
                  .expandX()
                  .expandY()
                  .append(
                    AclBuilder(
                          title: 'Details',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(const Text('Detail 1'))
                        .newRow(dist: 4)
                        .append(const Text('Detail 2'))
                        .build(),
                    dist: 8,
                  )
                  .expandY()
                  .newRow(dist: 8)
                  .append(
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade200,
                      child: const Text('Footer - Fixed Height'),
                    ),
                  )
                  .expandX()
                  .build(),
            ),
            const SizedBox(height: 16),
            const Text('Three-column layout that adapts:'),
            const SizedBox(height: 8),
            _ResizableBox(
              initialHeight: 150,
              child: AclBuilder()
                  .append(
                    const _ExpandingBox(
                      'Left\n(fixed width)',
                      Colors.red,
                      width: 100,
                    ),
                  )
                  .append(
                    const _ExpandingBox('Center\n(EXPANDX)', Colors.green),
                    dist: 4,
                  )
                  .expandX()
                  .append(
                    const _ExpandingBox(
                      'Right\n(fixed width)',
                      Colors.blue,
                      width: 100,
                    ),
                    dist: 4,
                  )
                  .build(),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandingBox extends StatelessWidget {
  final String label;
  final Color color;
  final double? width;

  const _ExpandingBox(this.label, this.color, {this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color.shade900),
        ),
      ),
    );
  }
}

class FluentApiDemo extends StatelessWidget {
  const FluentApiDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Using convenience extension methods:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          child: AclBuilder()
              .append(const _DemoBox('expandX()', Colors.red))
              .expandX()
              .append(const _DemoBox('Fixed', Colors.blue))
              .build(),
        ),
        const SizedBox(height: 16),
        _ResizableBox(
          child: AclBuilder()
              .append(const _DemoBox('alignCenter()', Colors.green))
              .setRowAlignCenter()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Using AclBuilder directly:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          child: AclBuilder()
              .append(const _DemoBox('A', Colors.red))
              .append(const _DemoBox('B', Colors.green), dist: 10)
              .append(const _DemoBox('C', Colors.blue), dist: 10)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Multi-row layout:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .append(const Text('Label:'))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .newRow(dist: 16)
              .append(ElevatedButton(onPressed: () {}, child: const Text('OK')))
              .append(OutlinedButton(onPressed: () {}, child: const Text('Cancel')), dist: 10)
              .setRowAlignCenter()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
// Extension methods
AclBuilder()
    .append(widget)
    .expandX()    // same as .setAttr(AclFlags.expandX)
    .expandY()    // same as .setAttr(AclFlags.expandY)
    .expand()     // same as .setAttr(AclFlags.expand)
    .alignLeft()  // same as .setRowAlignment(RowAlignment.left)
    .setRowAlignCenter()
    .alignRight()
    .build()

// AclBuild helper
AclBuild((b) => b
    .append(Widget_A)
    .append(Widget_B)
)

// AclColumn helper
AclColumn([
    AclRowDef(children: [...], alignment: ...),
    AclRowDef(children: [...], gapBefore: 16),
])
'''),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resizable wrapper for ACL demo containers.
// Drag the right edge to resize width, bottom edge (or corner grip) to resize
// height.  A small chip in the bottom-right corner always shows the live size.
// ─────────────────────────────────────────────────────────────────────────────
class _ResizableBox extends StatefulWidget {
  final Widget child;

  /// Initial height in logical pixels.
  final double initialHeight;

  /// Whether to draw the thin grey border around the content.
  /// Set to false when the child already provides its own visible border
  /// (e.g. an AclBuilder with title/borderStyle).
  final bool showBorder;

  const _ResizableBox({
    required this.child,
    this.initialHeight = 120,
    this.showBorder = true,
  });

  @override
  State<_ResizableBox> createState() => _ResizableBoxState();
}

class _ResizableBoxState extends State<_ResizableBox> {
  double? _width; // seeded on first layout from available constraints
  late double _height;

  // Global-position-based drag tracking so the container edge follows the
  // pointer 1:1 regardless of gesture-arena contention from parent scrollables.
  double? _panStartX;
  double? _panStartW;
  double? _panStartY;
  double? _panStartH;

  static const double _grip = 10.0;
  static const double _minW = 100.0;
  static const double _minH = 100.0;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width ??=
          constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
      final w = _width!.clamp(_minW, double.infinity);
      final h = _height;

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            // ── Content (optionally with grey border) ──────────────────
            Positioned.fill(
              child: widget.showBorder
                  ? Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey)),
                      child: widget.child,
                    )
                  : widget.child,
            ),

            // ── Right-edge drag handle ───────────────────────────────────
            Positioned(
              top: 0,
              right: 0,
              bottom: _grip,
              width: _grip,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartX = d.globalPosition.dx;
                    _panStartW = _width;
                  },
                  onPanUpdate: (d) => setState(() {
                    _width = ((_panStartW ?? w) +
                            d.globalPosition.dx -
                            (_panStartX ?? d.globalPosition.dx))
                        .clamp(_minW, double.infinity);
                  }),
                ),
              ),
            ),

            // ── Bottom-edge drag handle ──────────────────────────────────
            Positioned(
              left: 0,
              right: _grip,
              bottom: 0,
              height: _grip,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartY = d.globalPosition.dy;
                    _panStartH = _height;
                  },
                  onPanUpdate: (d) => setState(() {
                    _height = ((_panStartH ?? h) +
                            d.globalPosition.dy -
                            (_panStartY ?? d.globalPosition.dy))
                        .clamp(_minH, double.infinity);
                  }),
                ),
              ),
            ),

            // ── Corner drag handle (visual grip + resize both axes) ──────
            Positioned(
              right: 0,
              bottom: 0,
              width: _grip * 2,
              height: _grip * 2,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) {
                    _panStartX = d.globalPosition.dx;
                    _panStartW = _width;
                    _panStartY = d.globalPosition.dy;
                    _panStartH = _height;
                  },
                  onPanUpdate: (d) => setState(() {
                    _width = ((_panStartW ?? w) +
                            d.globalPosition.dx -
                            (_panStartX ?? d.globalPosition.dx))
                        .clamp(_minW, double.infinity);
                    _height = ((_panStartH ?? h) +
                            d.globalPosition.dy -
                            (_panStartY ?? d.globalPosition.dy))
                        .clamp(_minH, double.infinity);
                  }),
                  child: CustomPaint(painter: _GripPainter()),
                ),
              ),
            ),

            // ── Live size chip ───────────────────────────────────────────
            Positioned(
              right: _grip * 2 + 2,
              bottom: _grip + 2,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${w.round()} × ${h.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Paints a classic 3-line resize grip in the bottom-right corner.
class _GripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 3; i++) {
      final offset = i * 4.0;
      canvas.drawLine(
        Offset(size.width - offset, size.height),
        Offset(size.width, size.height - offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DemoBox extends StatelessWidget {
  final String label;
  final Color color;

  const _DemoBox(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color.shade900)),
    );
  }
}

extension _ColorShade on Color {
  Color get shade900 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.3).clamp(0.0, 1.0)).toColor();
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(
        code.trim(),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
