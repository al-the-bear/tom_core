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
          title: 'Convenience Placement',
          description: 'addBelow/addLeft/addAbove/addRight composition',
          screen: ConveniencePlacementDemo(),
        ),
        _DemoTile(
          title: 'Mixed Placement Playground',
          description: 'Mix convenience placement with rows and expandX',
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
          description: 'setWidthInChars for character-based field widths',
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

  const _DemoTile({
    required this.title,
    required this.description,
    required this.screen,
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
            builder: (context) => DemoScaffold(title: title, child: screen),
          ),
        ),
      ),
    );
  }
}

class DemoScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const DemoScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: SingleChildScrollView(
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          height: 200,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
          'Resize window: components keep minimum size, target preferred, and cap at maximum when possible.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(
                const _DemoBox('Min 80 / Pref 160 / Max 220', Colors.teal),
              )
              .setMSize(80, 40)
              .setPSize(160, 40)
              .setXSize(220, 40)
              .setAttr(AclFlags.expandX)
              .append(
                const _DemoBox('Min 60 / Pref 120 / Max 180', Colors.indigo),
                dist: 8,
              )
              .setMSize(60, 40)
              .setPSize(120, 40)
              .setXSize(180, 40)
              .setAttr(AclFlags.expandX)
              .newRow(dist: 10)
              .append(const _DemoBox('Fixed sample', Colors.orange))
              .setMSize(90, 36)
              .setPSize(90, 36)
              .setXSize(90, 36)
              .build(),
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
    final stackedAnchor = const SizedBox(
      width: 220,
      child: _DemoBox('Anchor (top->bottom + left)', Colors.brown),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Old + new reference constraints: anchors in the first row define width/edges; later rows link size and alignment.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(centerAnchor)
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
          'Combined vertical + horizontal reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(stackedAnchor)
              .setPSize(220, 56)
              .newRow()
              .append(
                const SizedBox(
                  width: 220,
                  child: _DemoBox(
                    'Follower (left + below, 16px)',
                    Colors.lightBlue,
                  ),
                ),
              )
              .setPSize(220, 36)
              .alignLeftToLeft(stackedAnchor)
              .alignTopToBottom(stackedAnchor, gap: -16)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower is directly below anchor with 16px vertical distance and same left edge.',
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
          'Character-based width sizing (setWidthInChars-style):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Using setWidthInChars(chars, charWidth: ..., height: ...). The sample derives charWidth from the current monospace style.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(const SizedBox(width: 140, child: Text('12 chars:')))
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 12,
              )
              .setWidthInChars(12, charWidth: charWidth, height: 40)
              .newRow(dist: 10)
              .append(const SizedBox(width: 140, child: Text('24 chars:')))
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 12,
              )
              .setWidthInChars(24, charWidth: charWidth, height: 40)
              .newRow(dist: 10)
              .append(const SizedBox(width: 140, child: Text('36 chars:')))
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 12,
              )
              .setWidthInChars(36, charWidth: charWidth, height: 40)
              .build(),
        ),
        const SizedBox(height: 12),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
    final charWidth = measureWidthInChars(context, 1, style: monospaceStyle);

AclBuilder()
    .append(TextField(style: monospaceStyle))
      .setWidthInChars(24, charWidth: charWidth, height: 40)
    .build();
'''),
      ],
    );
  }
}

class ConveniencePlacementDemo extends StatelessWidget {
  const ConveniencePlacementDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final firstWidget = const SizedBox(
      width: 170,
      child: _DemoBox('First', Colors.indigo),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Convenience placement methods chained from the previously appended widget:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(firstWidget)
              .setPSize(170, 50)
              .append(const SizedBox(width: 170, child: _DemoBox('Second', Colors.teal)))
              .setPSize(170, 40)
              .alignTopToBottom(firstWidget, gap: -10)
              .alignLeftToLeft(firstWidget)
              .append(const SizedBox(width: 130, child: _DemoBox('Third', Colors.orange)))
              .setPSize(130, 40)
              .alignRightToLeft(firstWidget, gap: 12)
              .alignTopToTop(firstWidget)
              .append(const SizedBox(width: 130, child: _DemoBox('Fourth', Colors.purple)))
              .setPSize(130, 36)
              .alignBottomToTop(firstWidget, gap: 8)
              .alignLeftToLeft(firstWidget)
              .append(const SizedBox(width: 150, child: _DemoBox('Fifth', Colors.blueGrey)))
              .setPSize(150, 36)
              .alignLeftToRight(firstWidget, gap: -10)
              .alignTopToTop(firstWidget)
              .append(
                const SizedBox(
                  width: 170,
                  child: _DemoBox('Sixth', Colors.lightBlue),
                ),
                dist: 12,
              )
              .setPSize(170, 40)
              .newRow(dist: 14)
              .append(const _DemoBox('Seventh expandX', Colors.green))
              .expandX()
              .append(const _DemoBox('Eighth expandX', Colors.red), dist: 8)
              .expandX()
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: First/Second stack vertically; Third/Fourth/Fifth branch around the previous component; Seventh/Eighth share row width via expandX.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
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
      child: _DemoBox('Form Anchor', Colors.deepPurple),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mixed mode playground (regular rows + convenience placement + sameSize):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(formAnchor)
              .setPSize(220, 56)
              .append(
                const SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Below + left aligned',
                      isDense: true,
                    ),
                  ),
                ),
              )
              .setPSize(220, 44)
              .alignTopToBottom(formAnchor, gap: -12)
              .alignLeftToLeft(formAnchor)
              .append(const SizedBox(width: 200, child: _DemoBox('Hint Panel', Colors.teal)))
              .setPSize(200, 56)
              .alignLeftToRight(formAnchor, gap: -12)
              .alignTopToTop(formAnchor, gap: -4)
              .append(const SizedBox(width: 200, child: _DemoBox('Status', Colors.orange)))
              .setPSize(200, 30)
              .alignBottomToTop(formAnchor, gap: 6)
              .alignLeftToLeft(formAnchor)
              .newRow(dist: 16)
              .append(
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Primary Action'),
                ),
              )
              .setPSize(220, 40)
              .append(
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Mirror Size'),
                ),
                dist: 12,
              )
              .sameSize(formAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: combination of relative-placement constraints and standard row sequencing; final button mirrors anchor dimensions via sameSize().',
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
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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

        // ── Panel C: addBelow convenience placement + size response ──────────
        const Text(
          'Panel C — addBelow convenience placement with responsive sizing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Main [pref 300, min 120] with Sub [pref 160, min 80] placed below-left. '
          'Resize window: Main and Sub shrink proportionally toward their minimums.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .setAclPadding(const EdgeInsets.all(8))
              .append(
                AclBuilder(
                      title: 'Outer Group',
                      borderStyle: const AclBorderStyle(
                        kind: AclBorderKind.solidDouble,
                        color: Colors.blueGrey,
                      ),
                    )
                    .append(
                      AclBuilder(
                            title: 'Inner Group A',
                            borderStyle: const AclBorderStyle(
                              kind: AclBorderKind.solidDouble,
                              color: Colors.indigo,
                            ),
                          )
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
                            ),
                          )
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Typical form layout (like Java example):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AclBuilder()
              .append(const SizedBox(width: 100, child: Text('Date:')))
              .append(
                const SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              )
              .newRow(dist: 12)
              .append(const SizedBox(width: 100, child: Text('Name:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setAttr(AclFlags.expandX)
              .newRow(dist: 12)
              .append(const SizedBox(width: 100, child: Text('Cost Center:')))
              .append(
                const SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              )
              .newRow(dist: 12)
              .append(const SizedBox(width: 100, child: Text('Description:')))
              .append(
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setAttr(AclFlags.expandX)
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
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const _CodeBlock('''
AclBuilder()
    .append(Label_Date)
    .append(TextField_Date)
    .newRow(dist: 12)
    .append(Label_Name)
    .append(TextField_Name)
    .setAttr(AclFlags.expandX)
    .newRow(dist: 12)
    .append(Label_CostCenter)
    .append(TextField_CostCenter)
    .newRow(dist: 20)
    .append(Submit_Button)
    .append(Cancel_Button, dist: 10)
    .setRowAlignment(RowAlignment.center)
    .build()
'''),
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
        Container(
          height: 400,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(
                const Text(
                  'Application Form',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              )
              .setRowAlignment(RowAlignment.center)
              .newRow(dist: 16)
              .append(const SizedBox(width: 80, child: Text('User:')))
              .append(
                const SizedBox(
                  width: 150,
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              )
              .append(const SizedBox(width: 80, child: Text('Role:')), dist: 20)
              .append(
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'guest', child: Text('Guest')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              )
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
            Container(
              height: 300,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: AclBuilder()
              .append(const _DemoBox('expandX()', Colors.red))
              .expandX()
              .append(const _DemoBox('Fixed', Colors.blue))
              .build(),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
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
