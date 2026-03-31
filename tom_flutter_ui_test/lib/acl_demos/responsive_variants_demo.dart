part of 'acl_demos.dart';

class ResponsiveVariantsDemo extends StatelessWidget {
  const ResponsiveVariantsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resize the box to see the layout switch between variants:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Default: 3-column  •  < 500px: 2-column  •  < 300px: 1-column',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 200,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.teal,
              rounded: true,
              borderRadius: 8,
            ),
          )
              // Default layout: 3 columns
              .append(const DemoBox('A', Colors.red))
              .append(const DemoBox('B', Colors.green), dist: 8)
              .append(const DemoBox('C', Colors.blue), dist: 8)
              .expandX()
              // Tablet variant: 2 columns + 1
              .addVariant('tablet', atWidth: 500, builder: (b) => b
                  .append(const DemoBox('A', Colors.red))
                  .append(const DemoBox('B', Colors.green), dist: 8)
                  .expandX()
                  .newRow(dist: 8)
                  .append(const DemoBox('C', Colors.blue))
                  .expandX(),
              )
              // Mobile variant: single column
              .addVariant('mobile', atWidth: 300, builder: (b) => b
                  .append(const DemoBox('A', Colors.red))
                  .expandX()
                  .newRow(dist: 8)
                  .append(const DemoBox('B', Colors.green))
                  .expandX()
                  .newRow(dist: 8)
                  .append(const DemoBox('C', Colors.blue))
                  .expandX(),
              )
              .build(),
        ),
        const SizedBox(height: 16),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
    // Default: 3-column
    .append(A).append(B).append(C).expandX()
    // Tablet: 2+1
    .addVariant('tablet', atWidth: 500, builder: (b) => b
        .append(A).append(B).expandX()
        .newRow(dist: 8)
        .append(C).expandX(),
    )
    // Mobile: single column
    .addVariant('mobile', atWidth: 300, builder: (b) => b
        .append(A).expandX()
        .newRow(dist: 8)
        .append(B).expandX()
        .newRow(dist: 8)
        .append(C).expandX(),
    )
    .build()
'''),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row Breakpoints Demo
// ─────────────────────────────────────────────────────────────────────────────
