part of 'acl_demos.dart';

class NestedContainersDemo extends StatelessWidget {
  const NestedContainersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Nested ACL containers:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNestedPanel(
                        'Left Panel',
                        Colors.blue,
                        AclBuilder()
                            .append(const Text('Item 1'))
                            .newRow(dist: 4)
                            .append(const Text('Item 2'))
                            .newRow(dist: 4)
                            .append(const Text('Item 3'))
                            .build(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNestedPanel(
                        'Right Panel',
                        Colors.green,
                        AclBuilder()
                            .append(const DemoBox('A', Colors.green))
                            .append(const DemoBox('B', Colors.green), dist: 4)
                            .newRow(dist: 4)
                            .append(const DemoBox('C', Colors.green))
                            .expandX()
                            .build(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildNestedPanel(
                'Bottom Panel (spanning full width)',
                Colors.orange,
                const Row(
                  children: [Text('Status: Ready'), Spacer(), Text('100%')],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Deeply nested with groups:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 160,
          child: AclBuilder()
              .setAclScrollableY()
              .setAclPadding(const EdgeInsets.all(12))
              .append(
                AclBuilder(
                      title: 'Outer Group',
                      borderStyle: const AclBorderStyle(
                        kind: AclBorderKind.solidDouble,
                        color: Colors.blueGrey,
                        borderInsets: EdgeInsets.fromLTRB(10, 18, 10, 10),
                      ),
                    )
                    // Identity container: ID propagates to descendant paths
                    .setAclId('outerGroup')
                    .setAclIdScope(true)
                    .setAclPadding(const EdgeInsets.all(10))
                    .append(
                      AclBuilder(
                            title: 'Inner Group A',
                            borderStyle: const AclBorderStyle(
                              kind: AclBorderKind.solidDouble,
                              color: Colors.indigo,
                              borderInsets: EdgeInsets.fromLTRB(8, 16, 8, 8),
                            ),
                          )
                          // Layout container (default): ID for own resources only
                          .setAclId('innerA')
                          .setAclPadding(const EdgeInsets.all(8))
                          .append(const Text('Content A1'))
                          .setId('a1')
                          .newRow(dist: 4)
                          .append(const Text('Content A2'))
                          .setId('a2')
                          .build(),
                    )
                    .expandX()
                    .append(
                      AclBuilder(
                            title: 'Inner Group B',
                            borderStyle: const AclBorderStyle(
                              kind: AclBorderKind.solidDouble,
                              color: Colors.teal,
                              borderInsets: EdgeInsets.fromLTRB(8, 16, 8, 8),
                            ),
                          )
                          // Layout container (default): ID for own resources only
                          .setAclId('innerB')
                          .setAclPadding(const EdgeInsets.all(8))
                          .append(const Text('Content B1'))
                          .setId('b1')
                          .newRow(dist: 4)
                          .append(const Text('Content B2'))
                          .setId('b2')
                          .build(),
                      dist: 8,
                    )
                    .expandX()
                    .build(),
              )
              .expandX()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
// Outer identity container (idScope: true) — ID propagates to descendants
AclBuilder()
    .setAclId('outerGroup')
    .setAclIdScope(true)     // descendants see c-outerGroup in their paths
    .append(
        AclBuilder()
            .setAclId('innerA') // layout container (default) — own resources only
            .setAclBorderStyle(...)
            .append(child1).setId('a1')
            .append(child2).setId('a2')
            .build()
    )
    .expandX()
    .append(
        AclBuilder(title: 'Group')
          .setAclId('innerB') // layout container (default) — own resources only
          .append(innerContent)
          .build(),
        dist: 8
    )
    .expandX()
    .build()
'''),
        ],
      ),
    );
  }

  Widget _buildNestedPanel(String title, Color color, Widget content) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.shade900,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(8), child: content),
        ],
      ),
    );
  }
}

