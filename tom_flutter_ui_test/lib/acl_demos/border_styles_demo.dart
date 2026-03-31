part of 'acl_demos.dart';

class BorderStylesDemo extends StatelessWidget {
  const BorderStylesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Available border styles:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildBorderExample(
          'AclBorderStyle.none()',
          const AclBorderStyle.none(),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Single line',
          const AclBorderStyle(kind: AclBorderKind.solid,
        color: Colors.blueGrey, lineWidth: 2),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Rounded',
          const AclBorderStyle(kind: AclBorderKind.solid,
        rounded: true,
            borderRadius: 10,
            color: Colors.blue,
            lineWidth: 2,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Double line',
          const AclBorderStyle(
            kind: AclBorderKind.solidDouble,
            color: Colors.teal,
            lineWidth: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Horizontal lines',
          const AclBorderStyle(
            kind: AclBorderKind.horizontal,
            color: Colors.brown,
            lineWidth: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Double line rounded',
          const AclBorderStyle(kind: AclBorderKind.solid,
        rounded: true,
            borderRadius: 10,
            color: Colors.purple,
            lineWidth: 2,
          ),
        ),
        const SizedBox(height: 12),
        _buildBorderExample(
          'Custom border inset (24/8/24/8)',
          const AclBorderStyle(
            rounded: true,
            borderRadius: 10,
            kind: AclBorderKind.solidDouble,
            color: Colors.indigo,
            borderInsets: EdgeInsets.fromLTRB(24, 8, 24, 8),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
    .setAclBorderStyle(
      const AclBorderStyle(
        rounded: true,
        kind: AclBorderKind.solidDouble,
        lineWidth: 2,
        color: Colors.blue,
        borderInsets: EdgeInsets.all(8),
      ),
    )
    .append(child)
    .build()
'''),
        ],
      ),
    );
  }

  Widget _buildBorderExample(String label, AclBorderStyle style) {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Text(label, style: const TextStyle(fontFamily: 'monospace')),
        ),
        Expanded(
          child: AclBuilder()
              .setAclBorderStyle(style)
              .setAclPadding(const EdgeInsets.all(8))
              .append(const Text('Content inside'))
              .build(),
        ),
      ],
    );
  }
}

