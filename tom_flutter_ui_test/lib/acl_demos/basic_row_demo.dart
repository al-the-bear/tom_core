part of 'acl_demos.dart';

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
            .append(const DemoBox('A', Colors.red))
            .append(const DemoBox('B', Colors.green))
            .append(const DemoBox('C', Colors.blue))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
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

