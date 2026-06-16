part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: per-row horizontal alignment
/// via `setRowHorizontalAlignment(RowAlignment.left/center/right)`.
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
        ResizableBox(
          initialHeight: 140,
          child: AclBuilder()
              .append(const DemoBox('Left', Colors.red))
              .append(const DemoBox('Aligned', Colors.green))
              .setRowHorizontalAlignment(RowAlignment.left)
              .newRow(dist: 8)
              .append(const DemoBox('Center', Colors.blue))
              .append(const DemoBox('Aligned', Colors.orange))
              .setRowHorizontalAlignment(RowAlignment.center)
              .newRow(dist: 8)
              .append(const DemoBox('Right', Colors.purple))
              .append(const DemoBox('Aligned', Colors.teal))
              .setRowHorizontalAlignment(RowAlignment.right)
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
    .append(Widget_A).append(Widget_B)
    .setRowHorizontalAlignment(RowAlignment.left)
    .newRow()
    .append(Widget_C).append(Widget_D)
    .setRowHorizontalAlignment(RowAlignment.center)
    .newRow()
    .append(Widget_E).append(Widget_F)
    .setRowHorizontalAlignment(RowAlignment.right)
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
