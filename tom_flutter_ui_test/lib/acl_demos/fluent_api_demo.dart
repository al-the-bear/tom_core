part of 'acl_demos.dart';

class FluentApiDemo extends StatelessWidget {
  const FluentApiDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Using convenience extension methods:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          child: AclBuilder()
            .setAclScrollableY()
              .append(const DemoBox('expandX()', Colors.red))
              .expandX()
              .append(const DemoBox('Fixed', Colors.blue))
              .build(),
        ),
        const SizedBox(height: 16),
        ResizableBox(
          child: AclBuilder()
            .setAclScrollableY()
              .append(const DemoBox('alignCenter()', Colors.green))
              .setRowAlignCenter()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Using AclBuilder directly:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          child: AclBuilder()
            .setAclScrollableY()
              .append(const DemoBox('A', Colors.red))
              .append(const DemoBox('B', Colors.green), dist: 10)
              .append(const DemoBox('C', Colors.blue), dist: 10)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Multi-row layout:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .setAclScrollableY()
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
        const CodeBlock('''
// Extension methods
AclBuilder()
    .append(widget)
    .expandX()    // same as .setAttr(AclFlags.expandX)
    .expandY()    // same as .setAttr(AclFlags.expandY)
    .expand()     // same as .setAttr(AclFlags.expand)
    .alignLeft()  // same as .setRowHorizontalAlignment(RowAlignment.left)
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Visibility Control Demo
// ─────────────────────────────────────────────────────────────────────────────
