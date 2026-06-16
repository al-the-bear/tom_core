part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: multi-row layout via
/// [AclBuilder.newRow] to stack rows of differing component counts.
class MultiRowDemo extends StatelessWidget {
  const MultiRowDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multiple rows using newRow():',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AclBuilder()
            .append(const DemoBox('Row 1 - A', Colors.red))
            .append(const DemoBox('Row 1 - B', Colors.green))
            .newRow()
            .append(const DemoBox('Row 2 - A', Colors.blue))
            .append(const DemoBox('Row 2 - B', Colors.orange))
            .append(const DemoBox('Row 2 - C', Colors.purple))
            .newRow()
            .append(const DemoBox('Row 3', Colors.teal))
            .build(),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
    .append(Widget_1A)
    .append(Widget_1B)
    .newRow()
    .append(Widget_2A)
    .append(Widget_2B)
    .append(Widget_2C)
    .newRow()
    .append(Widget_3)
    .build()
'''),
      ],
    );
  }
}

