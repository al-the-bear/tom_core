part of 'acl_demos.dart';

class RowBreakpointsDemo extends StatelessWidget {
  const RowBreakpointsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Row breakpoints split a single row into multiple at narrow widths:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Resize below 400px to see the 4-item row split after item 2',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 200,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.orange,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setAclScrollableY()
              .append(const DemoBox('1', Colors.red), dist: 8)
              .append(const DemoBox('2', Colors.green), dist: 8)
              .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
              .append(const DemoBox('3', Colors.blue), dist: 8)
              .append(const DemoBox('4', Colors.purple), dist: 8)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Multiple breakpoints — progressive splitting:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Default: 4 items   •  < 500px: split 2+2   •  < 300px: split 1+1+2',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 250,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.indigo,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setAclScrollableY()
              .append(const DemoBox('A', Colors.red), dist: 8)
              .addRowBreakpoint(atWidth: 300, splitRowDist: 8)
              .append(const DemoBox('B', Colors.green), dist: 8)
              .addRowBreakpoint(atWidth: 500, splitRowDist: 8)
              .append(const DemoBox('C', Colors.blue), dist: 8)
              .append(const DemoBox('D', Colors.purple), dist: 8)
              .build(),
        ),
        const SizedBox(height: 16),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
    .append(Item1, dist: 8)
    .append(Item2, dist: 8)
    .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
    .append(Item3, dist: 8)
    .append(Item4, dist: 8)
    .build()
'''),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoint Expansion Demo
// ─────────────────────────────────────────────────────────────────────────────
