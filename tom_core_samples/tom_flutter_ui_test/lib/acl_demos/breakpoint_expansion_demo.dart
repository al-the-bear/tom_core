part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: multi-stage row breakpoints —
/// `expandX` components that contract, then break into more rows at successive
/// `addRowBreakpoint(atWidth:)` thresholds.
class BreakpointExpansionDemo extends StatelessWidget {
  const BreakpointExpansionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final a = Container(
      constraints: const BoxConstraints(minWidth: 60),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: Colors.red.shade100,
      child: const Text('A'),
    );
    final b = Container(
      constraints: const BoxConstraints(minWidth: 60),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: Colors.green.shade100,
      child: const Text('B'),
    );
    final c = Container(
      constraints: const BoxConstraints(minWidth: 60),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: Colors.blue.shade100,
      child: const Text('C'),
    );
    final d = Container(
      constraints: const BoxConstraints(minWidth: 60),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: Colors.purple.shade100,
      child: const Text('D'),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4 expanding components that contract, then break into more rows:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wide: 1 row  •  < 768px: 2 rows (2+2)  •  < 400px: 4 rows (1+1+1+1)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          ResizableBox(
            initialHeight: 200,
            child:
                AclBuilder(
                      borderStyle: const AclBorderStyle(
                        kind: AclBorderKind.solid,
                        color: Colors.deepPurple,
                        rounded: true,
                        borderRadius: 8,
                      ),
                      padding: const EdgeInsets.all(8),
                    )
                    .setAclScrollableY()
                    .setAclPaddingRight(8)
                    .setAclPaddingLeft(0)
                    .append(a, dist: 8)
                    .setPSize(200, 40)
                    .setMSize(60, 40)
                    .expandX()
                    .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
                    .append(b, dist: 8)
                    .setPSize(200, 40)
                    .setMSize(60, 40)
                    .expandX()
                    .addRowBreakpoint(atWidth: 768, splitRowDist: 8)
                    .append(c, dist: 8)
                    .setPSize(200, 40)
                    .setMSize(60, 40)
                    .expandX()
                    .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
                    .append(d, dist: 8)
                    .setPSize(200, 40)
                    .setMSize(60, 40)
                    .expandX()
                    .build(),
          ),
          const SizedBox(height: 16),
          const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
          const CodeBlock('''
AclBuilder(padding: EdgeInsets.all(8))
    .setAclPaddingRight(8)
    .append(A, dist: 8)
    .setPSize(200, 40)
    .setMSize(60, 40)
    .expandX()
    .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
    .append(B, dist: 8)
    .setPSize(200, 40)
    .setMSize(60, 40)
    .expandX()
    .addRowBreakpoint(atWidth: 768, splitRowDist: 8)
    .append(C, dist: 8)
    .setPSize(200, 40)
    .setMSize(60, 40)
    .expandX()
    .addRowBreakpoint(atWidth: 400, splitRowDist: 8)
    .append(D, dist: 8)
    .setPSize(200, 40)
    .setMSize(60, 40)
    .expandX()
    .build()
'''),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline Component Variants Demo
// ─────────────────────────────────────────────────────────────────────────────
