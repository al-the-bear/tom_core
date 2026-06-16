part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: inline variants —
/// `startVariant()` / `addVariant()` swapping a subset of one row's components
/// at width breakpoints.
class InlineVariantsDemo extends StatelessWidget {
  const InlineVariantsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Inline variants: different components shown in the same row at different widths.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Default: 3 coloured boxes  •  < 400px: single wide box',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 140,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.teal,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .setAclScrollableY()
              .append(const SizedBox(width: 70, child: Text('Items:')))
              .setPSize(70, 0)
              // Default variant: three items
              .startVariant()
              .append(const DemoBox('A', Colors.red), dist: 8)
              .expandX().setMSize(40, 0)
              .append(const DemoBox('B', Colors.green), dist: 8)
              .expandX().setMSize(40, 0)
              .append(const DemoBox('C', Colors.blue), dist: 8)
              .expandX().setMSize(40, 0)
              .endVariant()
              // Narrow variant: one combined item
              .startVariant(width: 400)
              .append(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(50),
                    border: Border.all(color: Colors.purple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('A + B + C (combined)', style: TextStyle(color: Colors.purple)),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              .build(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Adaptive form row: wide → first + last name, narrow → single full-name field.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Default: 2 fields  •  < 500px: 1 field',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 160,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.indigo,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .setAclScrollableY()
              // Row 1: Name — inline variants
              .append(const SizedBox(width: 80, child: Text('Name:')))
              .setPSize(80, 0)
              .startVariant()
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'First name',
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Last name',
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              .startVariant(width: 500)
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Full name',
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              // Row 2: Email — always the same
              .newRow(dist: 8)
              .append(const SizedBox(width: 80, child: Text('Email:')))
              .setPSize(80, 0)
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Email address',
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .build(),
        ),
        const SizedBox(height: 16),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
    .append(Text('Name:'))
    // Wide: two fields
    .startVariant()
    .append(firstNameField).expandX()
    .append(lastNameField).expandX()
    .endVariant()
    // Narrow (< 500px): single field
    .startVariant(width: 500)
    .append(fullNameField).expandX()
    .endVariant()
    // Email row is always shown
    .newRow(dist: 8)
    .append(Text('Email:'))
    .append(emailField).expandX()
    .build()
'''),
        const SizedBox(height: 24),
        const Text(
          'Form-factor variant: different content for phone / tablet / desktop.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          '< 600px: phone  •  < 1024px: tablet  •  ≥ 1024px: desktop',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 100,
          child: AclBuilder(
            borderStyle: const AclBorderStyle(
              kind: AclBorderKind.solid,
              color: Colors.deepOrange,
              rounded: true,
              borderRadius: 8,
            ),
          )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .setAclScrollableY()
              .append(const SizedBox(width: 70, child: Text('Device:')))
              .setPSize(70, 0)
              .startVariant(formFactor: AclFormFactor.phone)
              .append(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(40),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android, size: 16, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Phone layout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              .startVariant(formFactor: AclFormFactor.tablet)
              .append(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(40),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tablet_mac, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Tablet layout', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              .startVariant()
              .append(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(40),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.desktop_mac, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Desktop layout', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
                dist: 8,
              )
              .expandX()
              .endVariant()
              .build(),
        ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resizable wrapper for ACL demo containers.
// Drag the right edge to resize width, bottom edge (or corner grip) to resize
// height.  A small chip in the bottom-right corner always shows the live size.
// ─────────────────────────────────────────────────────────────────────────────
