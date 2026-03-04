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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ACL Components'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Acl'),
              Tab(text: 'Legacy'),
              Tab(text: 'Roadmap'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AclTab(), _LegacyTab(), _RoadmapTab()],
        ),
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
          scrollable: false,
        ),
        _DemoTile(
          title: 'Spacing & Gaps',
          description: 'Component and row spacing',
          screen: SpacingDemo(),
        ),
        _DemoTile(
          title: 'Border Styles',
          description: 'Aspect-based border styles + inset controls',
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
          description: 'Using AclBuilder, AclBuild and AclColumn',
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

class _LegacyTab extends StatelessWidget {
  const _LegacyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _DemoTile(
          title: 'Legacy Workspace Dashboard',
          description:
              'Classic split view with navigator, details and status footer',
          screen: LegacyWorkspaceDashboardDemo(),
          scrollable: false,
        ),
        _DemoTile(
          title: 'Legacy Inspector Form',
          description:
              'Classic grouped form sample with ACL groups and aligned fields',
          screen: LegacyInspectorFormDemo(),
        ),
        _DemoTile(
          title: 'Legacy Execution Panel',
          description:
              'Classic execution monitor style panel with queue and logs',
          screen: LegacyExecutionPanelDemo(),
          scrollable: false,
        ),
      ],
    );
  }
}

class _DemoTile extends StatelessWidget {
  final String title;
  final String description;
  final Widget screen;
  final bool scrollable;

  const _DemoTile({
    required this.title,
    required this.description,
    required this.screen,
    this.scrollable = true,
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
              scrollable: scrollable,
              child: screen,
            ),
          ),
        ),
      ),
    );
  }
}

class DemoScaffold extends StatelessWidget {
  final String title;
  final bool scrollable;
  final Widget child;

  const DemoScaffold({
    super.key,
    required this.title,
    this.scrollable = true,
    required this.child,
  });

  void _showCode(BuildContext context) {
    final code = _demoCodeByTitle(title);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$title - Code'),
          content: SizedBox(
            width: 840,
            child: SingleChildScrollView(
              child: SelectableText(
                code,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: () => _showCode(context),
            icon: const Icon(Icons.code),
            label: const Text('Show Code'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: scrollable
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            )
          : Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class BasicRowDemo extends StatelessWidget {
  const BasicRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclBuilder()
        .append(_box('A', Colors.red.shade100))
        .append(_box('B', Colors.green.shade100), dist: 8)
        .append(_box('C', Colors.blue.shade100), dist: 8)
        .build();
  }
}

class MultiRowDemo extends StatelessWidget {
  const MultiRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclBuilder()
        .append(_box('Row1-A', Colors.orange.shade100))
        .append(_box('Row1-B', Colors.orange.shade200), dist: 8)
        .newRow(dist: 8)
        .append(_box('Row2-A', Colors.purple.shade100))
        .append(_box('Row2-B', Colors.purple.shade200), dist: 8)
        .append(_box('Row2-C', Colors.purple.shade300), dist: 8)
        .newRow(dist: 8)
        .append(_box('Row3', Colors.teal.shade100))
        .build();
  }
}

class AlignmentDemo extends StatelessWidget {
  const AlignmentDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
      child: AclBuilder()
          .append(_box('Left', Colors.red.shade100))
          .append(_box('Aligned', Colors.red.shade200), dist: 8)
          .setRowAlignment(RowAlignment.left)
          .newRow(dist: 8)
          .append(_box('Center', Colors.blue.shade100))
          .append(_box('Aligned', Colors.blue.shade200), dist: 8)
          .setRowAlignment(RowAlignment.center)
          .newRow(dist: 8)
          .append(_box('Right', Colors.green.shade100))
          .append(_box('Aligned', Colors.green.shade200), dist: 8)
          .setRowAlignment(RowAlignment.right)
          .build(),
    );
  }
}

class ExpandDemo extends StatelessWidget {
  const ExpandDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: AclBuilder()
                .append(_box('Fixed', Colors.red.shade100))
                .append(_box('EXPANDX', Colors.green.shade100), dist: 8)
                .setAttr(AclFlags.expandX)
                .append(_box('Fixed', Colors.blue.shade100), dist: 8)
                .build(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: AclBuilder()
                .append(_box('Header', Colors.amber.shade100))
                .newRow(dist: 8)
                .append(
                  Container(
                    width: double.infinity,
                    color: Colors.lightBlue.shade50,
                    child: const Center(child: Text('EXPANDY Row')),
                  ),
                )
                .setAttr(AclFlags.expandY)
                .newRow(dist: 8)
                .append(_box('Footer', Colors.amber.shade100))
                .build(),
          ),
        ),
      ],
    );
  }
}

String _demoCodeByTitle(String title) {
  switch (title) {
    case 'Basic Row Layout':
      return '''AclBuilder()
  .append(_box('A', Colors.red.shade100))
  .append(_box('B', Colors.green.shade100), dist: 8)
  .append(_box('C', Colors.blue.shade100), dist: 8)
  .build();''';
    case 'Multiple Rows':
      return '''AclBuilder()
  .append(_box('Row1-A', Colors.orange.shade100))
  .append(_box('Row1-B', Colors.orange.shade200), dist: 8)
  .newRow(dist: 8)
  .append(_box('Row2-A', Colors.purple.shade100))
  .append(_box('Row2-B', Colors.purple.shade200), dist: 8)
  .append(_box('Row2-C', Colors.purple.shade300), dist: 8)
  .newRow(dist: 8)
  .append(_box('Row3', Colors.teal.shade100))
  .build();''';
    case 'Row Alignment':
      return '''AclBuilder()
  .append(_box('Left', Colors.red.shade100))
  .append(_box('Aligned', Colors.red.shade200), dist: 8)
  .setRowAlignment(RowAlignment.left)
  .newRow(dist: 8)
  .append(_box('Center', Colors.blue.shade100))
  .append(_box('Aligned', Colors.blue.shade200), dist: 8)
  .setRowAlignment(RowAlignment.center)
  .newRow(dist: 8)
  .append(_box('Right', Colors.green.shade100))
  .append(_box('Aligned', Colors.green.shade200), dist: 8)
  .setRowAlignment(RowAlignment.right)
  .build();''';
    case 'Expand Flags':
      return '''Column(
  children: [
    Expanded(
      child: AclBuilder()
          .append(_box('Fixed', Colors.red.shade100))
          .append(_box('EXPANDX', Colors.green.shade100), dist: 8)
          .setAttr(AclFlags.expandX)
          .append(_box('Fixed', Colors.blue.shade100), dist: 8)
          .build(),
    ),
    const SizedBox(height: 12),
    Expanded(
      child: AclBuilder()
          .append(_box('Header', Colors.amber.shade100))
          .newRow(dist: 8)
          .append(Container(child: const Center(child: Text('EXPANDY Row'))))
          .setAttr(AclFlags.expandY)
          .newRow(dist: 8)
          .append(_box('Footer', Colors.amber.shade100))
          .build(),
    ),
  ],
);''';
    case 'Spacing & Gaps':
      return '''AclBuilder()
  .append(_box('A', Colors.red.shade100))
  .append(_box('B (+20)', Colors.green.shade100), dist: 20)
  .append(_box('C (+40)', Colors.blue.shade100), dist: 40)
  .newRow(dist: 18)
  .append(_box('Next Row (+18)', Colors.purple.shade100))
  .build();''';
    case 'Border Styles':
      return 'AclContainer(borderStyle: style, rows: [...])  // style variants demo';
    case 'Groups (Titled Borders)':
      return 'AclGroup(title: \'User Group\', child: AclBuilder()...build())';
    case 'Nested Containers':
      return 'AclContainer(rows: [AclRow(components: [AclComponent(child: AclContainer(...))])]);';
    case 'Form Layout':
      return '''AclBuilder()
  .append(const SizedBox(width: 120, child: Text('First Name:')))
  .append(const TextField(decoration: InputDecoration(isDense: true)))
  .setAttr(AclFlags.expandX)
  .newRow(dist: 8)
  ...
  .build();''';
    case 'Complex Layout':
      return 'AclBuilder().setPadding(...).setBorderStyle(...).append(...).setAttr(AclFlags.expand)...build();';
    case 'Dynamic Resize Demo':
      return 'LayoutBuilder(builder: (context, constraints) => AclBuilder()...build())';
    case 'Fluent Builder API':
      return 'AclBuild((b) { ... });\nAclColumn([AclRowDef(...), AclRowDef(...)]);';
    case 'Legacy Workspace Dashboard':
      return '''Container(
  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
  child: AclBuilder()
      .append(_box('Workspace Tree', Colors.indigo.shade100))
      .append(_box('Quest Details', Colors.teal.shade100), dist: 8)
      .setAttr(AclFlags.expand)
      .newRow(dist: 8)
      .append(_box('Status Footer', Colors.blueGrey.shade100))
      .setAttr(AclFlags.expandX)
      .build(),
);''';
    case 'Legacy Inspector Form':
      return '''AclGroup(
  title: 'Todo Inspector',
  child: AclBuilder()
      .append(const SizedBox(width: 120, child: Text('Todo ID:')))
      .append(const TextField(decoration: InputDecoration(isDense: true)))
      .setAttr(AclFlags.expandX)
      .newRow(dist: 8)
      .append(const SizedBox(width: 120, child: Text('Execution Role:')))
      .append(const TextField(decoration: InputDecoration(isDense: true)))
      .setAttr(AclFlags.expandX)
      .build(),
);''';
    case 'Legacy Execution Panel':
      return '''AclBuilder()
  .append(_box('Queue', Colors.orange.shade100))
  .append(_box('Running', Colors.green.shade100), dist: 8)
  .append(_box('Failed', Colors.red.shade100), dist: 8)
  .newRow(dist: 8)
  .append(Container(child: const Center(child: Text('Execution Logs'))))
  .setAttr(AclFlags.expand)
  .build();''';
    default:
      return 'Code sample is not available for this section.';
  }
}

class LegacyWorkspaceDashboardDemo extends StatelessWidget {
  const LegacyWorkspaceDashboardDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: AclBuilder()
          .append(_legacyPanel('Workspace Tree', Colors.indigo.shade100))
          .append(_legacyPanel('Quest Details', Colors.teal.shade100), dist: 8)
          .setAttr(AclFlags.expand)
          .newRow(dist: 8)
          .append(_legacyPanel('Status Footer', Colors.blueGrey.shade100))
          .setAttr(AclFlags.expandX)
          .build(),
    );
  }
}

class LegacyInspectorFormDemo extends StatelessWidget {
  const LegacyInspectorFormDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclGroup(
      title: 'Todo Inspector',
      borderStyle: const AclBorderStyle(
        rounded: true,
        borderRadius: 10,
        lineKind: AclBorderLineKind.doubleLine,
        primaryColor: Colors.indigo,
      ),
      child: AclBuilder()
          .append(const SizedBox(width: 120, child: Text('Todo ID:')))
          .append(const TextField(decoration: InputDecoration(isDense: true)))
          .setAttr(AclFlags.expandX)
          .newRow(dist: 8)
          .append(const SizedBox(width: 120, child: Text('Execution Role:')))
          .append(const TextField(decoration: InputDecoration(isDense: true)))
          .setAttr(AclFlags.expandX)
          .newRow(dist: 8)
          .append(const SizedBox(width: 120, child: Text('QA Role:')))
          .append(const TextField(decoration: InputDecoration(isDense: true)))
          .setAttr(AclFlags.expandX)
          .newRow(dist: 8)
          .append(const SizedBox(width: 120, child: Text('Status:')))
          .append(
            DropdownButtonFormField<String>(
              initialValue: 'in-progress',
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                  value: 'not-started',
                  child: Text('not-started'),
                ),
                DropdownMenuItem(
                  value: 'in-progress',
                  child: Text('in-progress'),
                ),
                DropdownMenuItem(value: 'blocked', child: Text('blocked')),
                DropdownMenuItem(value: 'completed', child: Text('completed')),
              ],
              onChanged: (_) {},
            ),
          )
          .setAttr(AclFlags.expandX)
          .build(),
    );
  }
}

class LegacyExecutionPanelDemo extends StatelessWidget {
  const LegacyExecutionPanelDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: AclBuilder()
          .append(_legacyPanel('Queued: 8', Colors.orange.shade100))
          .append(_legacyPanel('Running: 3', Colors.green.shade100), dist: 8)
          .append(_legacyPanel('Blocked: 2', Colors.red.shade100), dist: 8)
          .newRow(dist: 8)
          .append(
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Execution logs:\n'
                '- agent.orchestrator started bundle work_tracker-core\n'
                '- agent.impl completed 2/5 todos\n'
                '- agent.qa waiting on dependency graph refresh',
              ),
            ),
          )
          .setAttr(AclFlags.expand)
          .build(),
    );
  }
}

Widget _legacyPanel(String text, Color color) {
  return Container(
    width: double.infinity,
    height: 120,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black12),
    ),
    child: Center(
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class SpacingDemo extends StatelessWidget {
  const SpacingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclBuilder()
        .append(_box('A', Colors.red.shade100))
        .append(_box('B (+20)', Colors.green.shade100), dist: 20)
        .append(_box('C (+40)', Colors.blue.shade100), dist: 40)
        .newRow(dist: 18)
        .append(_box('Next Row (+18)', Colors.purple.shade100))
        .build();
  }
}

class BorderStylesDemo extends StatelessWidget {
  const BorderStylesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final styles = [
      (
        'Default inset (8px)',
        const AclBorderStyle(primaryColor: Colors.indigo),
      ),
      (
        'Rounded + Double line',
        const AclBorderStyle(
          rounded: true,
          borderRadius: 14,
          lineKind: AclBorderLineKind.doubleLine,
          primaryColor: Colors.teal,
          secondaryColor: Colors.tealAccent,
        ),
      ),
      (
        'With shadow + 3D effect',
        const AclBorderStyle(
          withShadow: true,
          with3dEffect: true,
          primaryColor: Colors.brown,
        ),
      ),
      (
        'Custom inset (24, 8, 24, 8)',
        const AclBorderStyle(
          rounded: true,
          borderRadius: 10,
          lineKind: AclBorderLineKind.single,
          primaryColor: Colors.deepPurple,
          borderInsets: EdgeInsets.fromLTRB(24, 8, 24, 8),
        ),
      ),
    ];

    return Column(
      children: [
        for (final entry in styles)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AclContainer(
              borderStyle: entry.$2,
              rows: [
                AclRow(components: [AclComponent(child: Text(entry.$1))]),
              ],
            ),
          ),
      ],
    );
  }
}

class GroupsDemo extends StatelessWidget {
  const GroupsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclGroup(
      title: 'User Group',
      borderStyle: const AclBorderStyle(
        rounded: true,
        borderRadius: 10,
        lineKind: AclBorderLineKind.doubleLine,
        with3dEffect: true,
        primaryColor: Colors.pink,
      ),
      child: AclBuilder()
          .append(const Text('Name:'))
          .append(const TextField(decoration: InputDecoration(isDense: true)))
          .setAttr(AclFlags.expandX)
          .newRow(dist: 8)
          .append(const Text('Email:'))
          .append(const TextField(decoration: InputDecoration(isDense: true)))
          .setAttr(AclFlags.expandX)
          .build(),
    );
  }
}

class NestedContainersDemo extends StatelessWidget {
  const NestedContainersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclContainer(
      borderStyle: const AclBorderStyle(
        rounded: true,
        primaryColor: Colors.indigo,
      ),
      rows: [
        AclRow(
          components: [
            AclComponent(
              child: AclContainer(
                borderStyle: const AclBorderStyle(
                  lineKind: AclBorderLineKind.doubleLine,
                  primaryColor: Colors.orange,
                ),
                rows: [
                  AclRow(
                    components: [
                      AclComponent(
                        child: _box('Nested 1', Colors.orange.shade100),
                      ),
                    ],
                  ),
                ],
              ),
              flags: AclFlags.expandX,
            ),
          ],
        ),
      ],
    );
  }
}

class FormLayoutDemo extends StatelessWidget {
  const FormLayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AclBuilder()
        .append(const SizedBox(width: 120, child: Text('First Name:')))
        .append(const TextField(decoration: InputDecoration(isDense: true)))
        .setAttr(AclFlags.expandX)
        .newRow(dist: 8)
        .append(const SizedBox(width: 120, child: Text('Last Name:')))
        .append(const TextField(decoration: InputDecoration(isDense: true)))
        .setAttr(AclFlags.expandX)
        .newRow(dist: 8)
        .append(const SizedBox(width: 120, child: Text('Role:')))
        .append(
          DropdownButtonFormField<String>(
            initialValue: 'user',
            isDense: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'guest', child: Text('Guest')),
            ],
            onChanged: (_) {},
          ),
        )
        .setAttr(AclFlags.expandX)
        .build();
  }
}

class ComplexLayoutDemo extends StatelessWidget {
  const ComplexLayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: AclBuilder()
          .setPadding(const EdgeInsets.all(8))
          .setBorderStyle(
            const AclBorderStyle(
              rounded: true,
              borderRadius: 10,
              lineKind: AclBorderLineKind.doubleLine,
              primaryColor: Colors.teal,
            ),
          )
          .append(_box('Toolbar', Colors.blueGrey.shade100))
          .append(const Spacer(), dist: 8)
          .setAttr(AclFlags.expandX)
          .append(ElevatedButton(onPressed: () {}, child: const Text('Run')))
          .newRow(dist: 8)
          .append(
            Container(
              color: Colors.lightBlue.shade50,
              child: const Center(child: Text('Main Area (EXPAND)')),
            ),
          )
          .setAttr(AclFlags.expand)
          .append(
            Container(
              width: 170,
              color: Colors.green.shade50,
              child: const Center(child: Text('Details')),
            ),
            dist: 8,
          )
          .setAttr(AclFlags.expandY)
          .newRow(dist: 8)
          .append(const Text('Status: Ready'))
          .append(const Spacer())
          .setAttr(AclFlags.expandX)
          .append(const Text('v2.0.0'))
          .build(),
    );
  }
}

class DynamicResizeDemo extends StatelessWidget {
  const DynamicResizeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth.toStringAsFixed(0)
            : 'unbounded';
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight.toStringAsFixed(0)
            : 'unbounded';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current size: $width × $height'),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: AclBuilder()
                  .append(_box('Top', Colors.red.shade100))
                  .newRow(dist: 8)
                  .append(_box('Middle EXPAND', Colors.orange.shade100))
                  .setAttr(AclFlags.expand)
                  .newRow(dist: 8)
                  .append(_box('Bottom', Colors.blue.shade100))
                  .build(),
            ),
          ],
        );
      },
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
        AclBuild((b) {
          b.append(_box('AclBuild()', Colors.amber.shade100));
          b.append(_box('fluent', Colors.amber.shade200), dist: 8);
        }),
        const SizedBox(height: 12),
        AclColumn([
          AclRowDef(
            children: [
              _box('AclColumn row 1', Colors.cyan.shade100),
              _box('item', Colors.cyan.shade200),
            ],
            childSpacing: 8,
          ),
          AclRowDef(
            children: [_box('row 2', Colors.cyan.shade100)],
            gapBefore: 8,
            alignment: RowAlignment.center,
          ),
        ]),
      ],
    );
  }
}

Widget _box(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black12),
    ),
    child: Text(text),
  );
}
