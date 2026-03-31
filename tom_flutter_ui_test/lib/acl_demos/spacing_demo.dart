part of 'acl_demos.dart';

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
            .append(const DemoBox('A', Colors.red))
            .append(const DemoBox('B (10px gap)', Colors.green), dist: 10)
            .append(const DemoBox('C (20px gap)', Colors.blue), dist: 20)
            .append(const DemoBox('D (30px gap)', Colors.orange), dist: 30)
            .build(),
        const SizedBox(height: 24),
        const Text(
          'Row spacing with newRow(dist:):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const DemoBox('Row 1', Colors.red))
            .newRow(dist: 10)
            .append(const DemoBox('Row 2 (10px gap)', Colors.green))
            .newRow(dist: 20)
            .append(const DemoBox('Row 3 (20px gap)', Colors.blue))
            .newRow(dist: 30)
            .append(const DemoBox('Row 4 (30px gap)', Colors.orange))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
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

