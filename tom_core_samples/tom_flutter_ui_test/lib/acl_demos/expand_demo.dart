part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: horizontal and vertical
/// expansion (`AclFlags.expandX` / `expandY` / `expand`), including equal
/// distribution of free space among multiple expanding components.
class ExpandDemo extends StatelessWidget {
  const ExpandDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPANDX - horizontal expansion:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ResizableBox(
            child: AclBuilder()
                .append(const DemoBox('Fixed', Colors.red))
                .append(const DemoBox('EXPANDX', Colors.green))
                .setAttr(AclFlags.expandX)
                .append(const DemoBox('Fixed', Colors.blue))
                .build(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Multiple EXPANDX (equal distribution):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ResizableBox(
            child: AclBuilder()
                .append(const DemoBox('Expand 1', Colors.red))
                .setAttr(AclFlags.expandX)
                .append(const DemoBox('Expand 2', Colors.green))
                .setAttr(AclFlags.expandX)
                .append(const DemoBox('Expand 3', Colors.blue))
                .setAttr(AclFlags.expandX)
                .build(),
          ),
          const SizedBox(height: 24),
          const Text(
            'EXPANDY - vertical expansion (in sized container):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ResizableBox(
            initialHeight: 200,
            child: AclBuilder()
                .append(const DemoBox('Fixed Row', Colors.red))
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
                .append(const DemoBox('Fixed Row', Colors.blue))
                .build(),
          ),
          const SizedBox(height: 24),
          const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
          const CodeBlock('''
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
      ),
    );
  }
}
