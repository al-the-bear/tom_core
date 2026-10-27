part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: the base [AclBuilder] fluent
/// API — laying out a single row of components with `append()` / `build()`.
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
