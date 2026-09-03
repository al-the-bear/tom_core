part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: titled, bordered groups —
/// `AclBuilder(title:, borderStyle:)` wrapping fields in a captioned container.
class GroupsDemo extends StatelessWidget {
  const GroupsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AclBuilder groups - bordered containers with titles:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          AclBuilder(
                title: 'User Information',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  color: Colors.blueGrey,
                ),
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
              .append(const SizedBox(width: 80, child: Text('Email:')))
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
          const SizedBox(height: 16),
          AclBuilder(
                title: 'Settings',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  rounded: true,
                  borderRadius: 10,
                  color: Colors.teal,
                ),
                titlePosition: AclTitlePosition.topCenter,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const Text('Enable notifications'))
              .append(Switch(value: true, onChanged: (_) {}), dist: 10)
              .newRow(dist: 8)
              .append(const Text('Dark mode'))
              .append(Switch(value: false, onChanged: (_) {}), dist: 10)
              .build(),
          const SizedBox(height: 16),
          AclBuilder(
                title: 'Actions',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.deepPurple,
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
                dist: 10,
              )
              .setRowHorizontalAlignment(RowAlignment.center)
              .build(),
          const SizedBox(height: 24),
          const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
          const CodeBlock('''
AclBuilder(
  title: 'User Information',
  borderStyle: AclBorderStyle(
    kind: AclBorderKind.solidDouble,
  ),
  titlePosition: AclTitlePosition.topLeft,
)
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
    .append(Label)
    .append(TextField)
    .expandX()
    .build()
'''),
          const SizedBox(height: 24),
          const Text(
            'Title border alignment:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Controls where the title sits vertically on the border line.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // ── bottom (default) ────────────────────────────────────────────────
          const Text(
            'titleBorderAlign: bottom  (default — label floats above the border)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: 'Bottom Align',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.indigo,
                  lineWidth: 1.5,
                ),
                titleBorderAlign: AclTitleBorderAlign.bottom,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const DemoBox('Item A', Colors.indigo))
              .append(const DemoBox('Item B', Colors.indigoAccent), dist: 8)
              .build(),
          const SizedBox(height: 20),

          // ── middle ──────────────────────────────────────────────────────────
          const Text(
            'titleBorderAlign: middle  (label centred on the border line)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: 'Middle Align',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.teal,
                  lineWidth: 1.5,
                ),
                titleBorderAlign: AclTitleBorderAlign.middle,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const DemoBox('Item A', Colors.teal))
              .append(const DemoBox('Item B', Colors.tealAccent), dist: 8)
              .build(),
          const SizedBox(height: 20),

          // ── top ─────────────────────────────────────────────────────────────
          const Text(
            'titleBorderAlign: top  (label hangs down from the border)',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          AclBuilder(
                title: 'Top Align',
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.deepOrange,
                  lineWidth: 1.5,
                ),
                titleBorderAlign: AclTitleBorderAlign.top,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const DemoBox('Item A', Colors.deepOrange))
              .append(const DemoBox('Item B', Colors.orange), dist: 8)
              .build(),
          const SizedBox(height: 20),

          // ── all three side-by-side with rounded double border ───────────────
          const Text(
            'All three with rounded double border:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    AclBuilder(
                          title: 'Bottom',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.indigo,
                            rounded: true,
                            borderRadius: 8,
                          ),
                          titleBorderAlign: AclTitleBorderAlign.bottom,
                        )
                        .setAclDefaultRowVerticalAlignment(
                          AclRowCrossAlignment.center,
                        )
                        .append(const DemoBox('Content', Colors.indigo))
                        .build(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    AclBuilder(
                          title: 'Middle',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.teal,
                            rounded: true,
                            borderRadius: 8,
                          ),
                          titleBorderAlign: AclTitleBorderAlign.middle,
                        )
                        .setAclDefaultRowVerticalAlignment(
                          AclRowCrossAlignment.center,
                        )
                        .append(const DemoBox('Content', Colors.teal))
                        .build(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    AclBuilder(
                          title: 'Top',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.deepOrange,
                            rounded: true,
                            borderRadius: 8,
                          ),
                          titleBorderAlign: AclTitleBorderAlign.top,
                        )
                        .setAclDefaultRowVerticalAlignment(
                          AclRowCrossAlignment.center,
                        )
                        .append(const DemoBox('Content', Colors.deepOrange))
                        .build(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Widget title (instead of plain text):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Any widget can be used as a title, positioned the same way.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          AclBuilder(
                titleWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'User Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solid,
                  color: Colors.blue,
                  rounded: true,
                  borderRadius: 8,
                ),
                titleBorderAlign: AclTitleBorderAlign.bottom,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const DemoBox('Widget Title', Colors.blue))
              .append(const DemoBox('Content', Colors.lightBlue), dist: 8)
              .build(),
          const SizedBox(height: 16),
          AclBuilder(
                titleWidget: Chip(
                  avatar: Icon(Icons.settings, size: 14),
                  label: Text('Settings', style: TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                borderStyle: const AclBorderStyle(
                  kind: AclBorderKind.solidDouble,
                  color: Colors.green,
                  rounded: true,
                  borderRadius: 8,
                ),
                titleBorderAlign: AclTitleBorderAlign.middle,
                titlePosition: AclTitlePosition.topCenter,
              )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const DemoBox('Chip as Title', Colors.green))
              .build(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bordered Groups Demo
// Single-line borders with various title positions.
// ─────────────────────────────────────────────────────────────────────────────
