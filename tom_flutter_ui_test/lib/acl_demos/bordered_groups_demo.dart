part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: bordered groups with
/// configurable title placement via [AclTitlePosition].
class BorderedGroupsDemo extends StatelessWidget {
  const BorderedGroupsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Single-line bordered groups with title positions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── topLeft title ──────────────────────────────────────────────────
          const Text(
            'topLeft title — solid border, square corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: 'Contact Details',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.blueGrey,
                  lineWidth: 1.5,
                ),
                titlePosition: AclTitlePosition.topLeft,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const SizedBox(width: 80, child: Text('Name:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .expandX()
              .newRow(dist: 8)
              .append(const SizedBox(width: 80, child: Text('Phone:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .expandX()
              .build(),
          const SizedBox(height: 20),

          // ── topCenter title ────────────────────────────────────────────────
          const Text(
            'topCenter title — solid border, rounded corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: '⚙ Preferences',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.teal,
                  lineWidth: 1.5,
                  rounded: true,
                  borderRadius: 10,
                ),
                titlePosition: AclTitlePosition.topCenter,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const Text('Dark mode'))
              .append(Switch(value: false, onChanged: (_) {}), dist: 8)
              .newRow(dist: 6)
              .append(const Text('Notifications'))
              .append(Switch(value: true, onChanged: (_) {}), dist: 8)
              .build(),
          const SizedBox(height: 20),

          // ── topRight title ─────────────────────────────────────────────────
          const Text(
            'topRight title — solid border, rounded corners:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: 'Actions ✓',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.deepPurple,
                  lineWidth: 1.5,
                  rounded: true,
                  borderRadius: 8,
                ),
                titlePosition: AclTitlePosition.topRight,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(
                ElevatedButton(onPressed: () {}, child: const Text('Save')),
              )
              .append(
                OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                dist: 8,
              )
              .setRowHorizontalAlignment(RowAlignment.center)
              .build(),
          const SizedBox(height: 24),

          const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
          const CodeBlock('''
AclBuilder(
  title: 'Contact Details',
  borderStyle: AclBorderStyle(
    kind: AclBorderKind.solid,
    color: Colors.blueGrey,
    lineWidth: 1.5,
  ),
  titlePosition: AclTitlePosition.topLeft,  // or topCenter / topRight
)
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
  .append(label)
  .append(textField).expandX()
  .build()
'''),
        ],
      ),
    );
  }
}
